package main

import "time"

type Machine struct {
	ID                      string `json:"id"`
	Name                    string `json:"name"`
	State                   string `json:"state"`
	VCPUs                   int    `json:"vcpus,omitempty"`
	MemMiB                  int    `json:"mem_mib,omitempty"`
	PersistentDiskGiB       int    `json:"persistent_disk_gib,omitempty"`
	AutoSuspendAfterSeconds int    `json:"auto_suspend_after_seconds,omitempty"`
	RawState                string `json:"raw_state,omitempty"`
}

type machineListResponse struct {
	Machines []machineWire `json:"machines"`
}

type machineWire struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	State string `json:"state"`
	Spec  struct {
		VCPUs             int `json:"vcpus"`
		MemMiB            int `json:"memMiB"`
		PersistentDiskGiB int `json:"persistentDiskGiB"`
	} `json:"spec"`
	AutoSuspendAfterSeconds int `json:"autoSuspendAfterSeconds"`
}

type execResponse struct {
	Stdout   string `json:"stdout"`
	Stderr   string `json:"stderr"`
	ExitCode int    `json:"exitCode"`
}

type apiErrorBody struct {
	Error struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

type Job struct {
	ID         string     `json:"id"`
	Machine    string     `json:"machine"`
	Kind       string     `json:"kind"`
	Command    string     `json:"command"`
	Status     string     `json:"status"`
	ExitCode   *int       `json:"exit_code,omitempty"`
	Stdout     string     `json:"stdout,omitempty"`
	Stderr     string     `json:"stderr,omitempty"`
	Error      string     `json:"error,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	StartedAt  *time.Time `json:"started_at,omitempty"`
	FinishedAt *time.Time `json:"finished_at,omitempty"`
	Snippet    string     `json:"snippet,omitempty"`
}

type logEntry struct {
	Seq       int       `json:"seq"`
	Stream    string    `json:"stream"`
	Line      string    `json:"line"`
	CreatedAt time.Time `json:"created_at"`
}

type jobInput struct {
	Machine string `json:"machine"`
	Kind    string `json:"kind"`
	Command string `json:"command"`
	Attr    string `json:"attr"`
	Args    string `json:"args"`
}

type jobsPage struct {
	Items  []Job  `json:"items"`
	Total  int    `json:"total"`
	Limit  int    `json:"limit"`
	Offset int    `json:"offset"`
	Q      string `json:"q"`
}

type statsResponse struct {
	TotalJobs    int        `json:"total_jobs"`
	RunningJobs  int        `json:"running_jobs"`
	FailedJobs   int        `json:"failed_jobs"`
	Successful   int        `json:"successful_jobs"`
	Kinds        []countRow `json:"kinds"`
	Machines     []countRow `json:"machines"`
	LastFinished *time.Time `json:"last_finished,omitempty"`
	GeneratedAt  time.Time  `json:"generated_at"`
}

type countRow struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}
