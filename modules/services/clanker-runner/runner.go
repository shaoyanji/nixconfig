package main

import (
	"context"
	"encoding/base64"
	"fmt"
	"strconv"
	"strings"
	"time"
)

const remoteWrapper = `#!/usr/bin/env bash
set -u
dir="$1"
cd "$dir" || exit 1
bash "$dir/cmd.sh" > "$dir/stdout" 2>"$dir/stderr"
cat "$dir/stdout" "$dir/stderr" > "$dir/log" 2>/dev/null || true
printf "%s\n" "$?" > "$dir/exit.tmp"
mv "$dir/exit.tmp" "$dir/exit"
`

func remoteStartCommand(id, command string) string {
	encoded := base64.StdEncoding.EncodeToString([]byte(command))
	wrapperEncoded := base64.StdEncoding.EncodeToString([]byte(remoteWrapper))
	return `set -eu
dir=/data/jobs/` + id + `
mkdir -p "$dir" "$dir/artifacts"
printf '%s' '` + encoded + `' | base64 -d > "$dir/cmd.sh"
printf '%s' '` + wrapperEncoded + `' | base64 -d > "$dir/wrap.sh"
chmod +x "$dir/cmd.sh" "$dir/wrap.sh"
setsid nohup "$dir/wrap.sh" "$dir" </dev/null >/dev/null 2>&1 &
echo started ` + id
}

func remoteExitCommand(id string) string {
	return `cat /data/jobs/` + id + `/exit 2>/dev/null || echo running`
}

func remoteStdoutCommand(id string) string {
	return `tail -c 131072 /data/jobs/` + id + `/stdout 2>/dev/null || true`
}

func remoteStderrCommand(id string) string {
	return `tail -c 131072 /data/jobs/` + id + `/stderr 2>/dev/null || true`
}

func remoteArtifactArchiveCommand(id string) string {
	return `dir=/data/jobs/` + id + `/artifacts
if [ ! -d "$dir" ]; then exit 0; fi
size=$(du -sb "$dir" 2>/dev/null | cut -f1 || echo 0)
if [ "$size" -eq 0 ]; then exit 0; fi
if [ "$size" -gt 2097152 ]; then echo artifact-archive-too-large; exit 0; fi
tar -czf - -C /data/jobs/` + id + ` artifacts 2>/dev/null | base64 -w0 2>/dev/null || tar -czf - -C /data/jobs/` + id + ` artifacts 2>/dev/null | base64 | tr -d '\n'
`
}

func firstOutputLine(raw string) string {
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			return line
		}
	}
	return ""
}

func decodeArtifactArchive(raw string) ([]byte, error) {
	text := strings.TrimSpace(raw)
	if text == "" || strings.Contains(text, "too-large") {
		return nil, nil
	}
	return base64.StdEncoding.DecodeString(text)
}

func (s *server) captureArtifacts(ctx context.Context, machine Machine, id, stdout, stderr string) {
	artifacts := []artifactInput{}
	if stdout != "" {
		artifacts = append(artifacts, artifactInput{Name: "stdout.txt", Kind: "stdout", Mime: "text/plain; charset=utf-8", Content: []byte(stdout)})
	}
	if stderr != "" {
		artifacts = append(artifacts, artifactInput{Name: "stderr.txt", Kind: "stderr", Mime: "text/plain; charset=utf-8", Content: []byte(stderr)})
	}
	archiveResult, err := s.client.Exec(ctx, machine.ID, remoteArtifactArchiveCommand(id))
	if err == nil && archiveResult.ExitCode == 0 {
		if archive, decodeErr := decodeArtifactArchive(archiveResult.Stdout); decodeErr == nil && len(archive) > 0 {
			artifacts = append(artifacts, artifactInput{Name: "artifacts.tar.gz", Kind: "archive", Mime: "application/gzip", Content: archive})
		}
	}
	for _, artifact := range artifacts {
		_ = s.store.CreateArtifact(ctx, id, artifact)
	}
}

func (s *server) startRemoteJob(ctx context.Context, machine Machine, id, command string) error {
	result, err := s.client.Exec(ctx, machine.ID, remoteStartCommand(id, command))
	if err != nil {
		return err
	}
	if result.ExitCode != 0 {
		return fmt.Errorf("start remote job: exit %d: %s", result.ExitCode, strings.TrimSpace(result.Stderr))
	}
	return nil
}

func (s *server) waitMachineRunning(ctx context.Context, machine Machine) (Machine, error) {
	if machine.State == "running" {
		return machine, nil
	}
	if err := s.client.MachineAction(ctx, machine.ID, "wake"); err != nil {
		return machine, err
	}
	deadline := time.Now().Add(90 * time.Second)
	for {
		current, err := s.client.GetMachine(ctx, machine.ID)
		if err == nil && current.State == "running" {
			return current, nil
		}
		if time.Now().After(deadline) {
			return machine, fmt.Errorf("machine %s did not reach running state", machine.Name)
		}
		select {
		case <-ctx.Done():
			return machine, ctx.Err()
		case <-time.After(3 * time.Second):
		}
	}
}

func (s *server) pollRemoteJob(ctx context.Context, machine Machine, id string) (execResponse, error) {
	interval := s.pollInterval
	if interval <= 0 {
		interval = 5 * time.Second
	}
	for {
		result, err := s.client.Exec(ctx, machine.ID, remoteExitCommand(id))
		if err != nil {
			return execResponse{}, err
		}
		state := firstOutputLine(result.Stdout)
		if result.ExitCode != 0 {
			return execResponse{}, fmt.Errorf("poll remote job: exit %d: %s", result.ExitCode, strings.TrimSpace(result.Stderr))
		}
		if state != "" && state != "running" {
			code, convErr := strconv.Atoi(state)
			if convErr != nil {
				return execResponse{}, fmt.Errorf("remote job exit marker %q is not numeric", state)
			}
			stdoutResult, err := s.client.Exec(ctx, machine.ID, remoteStdoutCommand(id))
			if err != nil {
				return execResponse{}, err
			}
			stderrResult, err := s.client.Exec(ctx, machine.ID, remoteStderrCommand(id))
			if err != nil {
				return execResponse{}, err
			}
			return execResponse{Stdout: stdoutResult.Stdout, Stderr: stderrResult.Stdout, ExitCode: code}, nil
		}
		select {
		case <-ctx.Done():
			return execResponse{}, ctx.Err()
		case <-time.After(interval):
		}
	}
}
