# DeepSeek-V4-Flash 284B: LAN copy and the evening benchmark

Open question and exit criteria: `AGENTS.nix` note `deepseek-v4-flash-eisen`. Fetchers and the
future unit are `hosts/eisen/deepseek-v4.nix`, **not imported**, so `deepseek-v4-flash.service`
does not exist on the host and the trial runs as a transient unit — the pattern the Strata tier
probe above already uses. The pack's published 9.1–14.7 tok/s is a 16C Zen 5 with AVX-512BW and
DDR5-5600; this box is AVX2-only Haswell-EP on DDR3-1600 (~25.6 GB/s against ~89 GB/s), so the
archive figure is an upper bound and only a measurement on eisen settles it.

### 0. Result: rejected, and the two reasons

The bundled engine does not run here. `llama-server-modchip-linux-x86_64` traps
`invalid opcode` inside its own text (ip offset `0x7e6aac`) before it prints a
version: it is a `-march=native` build from the publisher's Zen 5 machine, and
this Xeon E5-2673 v3 reports `avx2 bmi2 fma` with no AVX-512. The pack's README
carries the `avx512` tag, and its own reference decode is 9.06–10.74 tok/s
(11.5–14.7 with PVS) on 16C Zen 5 with DDR5-5600 — so the 15 tok/s bar was
already above what the pack does on better silicon.

The route that does run is the publisher's source build, on the host, because the
repo ships patches rather than the engine:

```bash
cd /mnt/storage/models/deepseek-v4-flash
git clone --depth 1 https://github.com/synchopate/llama-modchip
cd llama-modchip
nix shell nixpkgs#cmake nixpkgs#gnumake nixpkgs#gcc13 nixpkgs#git nixpkgs#python3 \
  --command bash -c 'export CC=gcc CXX=g++; bash scripts/build_zen5_llama.sh'
```

The script clones `llama.cpp` at its pinned `d2f83055`, applies
`patches/zen5-nemotron-256k-optimizations.patch`, copies the RouteCrack engine from
`speculative/cpp/` and picks the ISA from `/proc/cpuinfo`: AVX-512 VNNI + BF16 if
present, otherwise AVX2 + FMA + F16C. `make` has to be on `PATH` even though the
result is linked by the default generator, or CMake answers `unable to find a
build program`. The build is ~6 minutes on 24 threads.

Measured on the built binary, `server` persona, `/completion` with
`cache_prompt:false` so every run pays its own prompt:

| Run | Prefill | Decode |
| :--- | :--- | :--- |
| 1 | 6 tok/s over 601 prompt tokens | 2.9 tok/s over 128 predicted |
| 2 | 7 tok/s over 601 | 2.9 tok/s |
| 3 | 7 tok/s over 601 | 2.9 tok/s |

Load took 4 minutes for 56.57 GiB and the model answered coherently, so the pack
works on this box; it is 2.9 tok/s against the 15 tok/s bar and against Strata's
19.4 tok/s agent session, which is why `hosts/eisen/deepseek-v4.nix` stayed
unimported and `strata` keeps `:8085`. Launch, once the build exists:

```bash
sudo systemd-run --unit=dsv4-probe --property=User=devji --property=Group=users \
  --property=LimitCORE=0 --property=WorkingDirectory=/mnt/storage/models/deepseek-v4-flash \
  /mnt/storage/models/deepseek-v4-flash/llama-modchip/llama.cpp/build/bin/llama-server \
    -m DeepSeek-V4-Flash-0731-Fractal-00001-of-00003.gguf --alias deepseek-v4-flash \
    --host 127.0.0.1 --port 8086 --threads 12 --threads-batch 24 --ctx-size 32768 \
    --flash-attn on --jinja --metrics
```

### 1. Wait on the right progress number

aria2 runs with `falloc`, so each shard is assigned its **full length on the first write**: `ls -l`
and `du` both report 57 G from minute one while ~1 GB has arrived. The RPC is the only honest
progress:

```bash
S=$(sudo -n cat /run/secrets/aria2-rpc-secret)
for g in eb4cf3da511d80c4 2149c57266a866c5; do
  curl -s http://127.0.0.1:6800/jsonrpc -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":\"x\",\"method\":\"aria2.tellStatus\",\"params\":[\"token:$S\",\"$g\",[\"status\",\"completedLength\",\"totalLength\"]]}" \
  | jq -r '.result | "\(.status) \(.completedLength)/\(.totalLength)"'
done
```

Done means `complete` on both **and** no `*.aria2` control file beside them
(`ls /srv/data/downloads/deepseek-v4-flash/*.aria2`). The three shards are not peers: `00001` is a
5.2 MB metadata shard (header, embeddings, tensor map) that finished in seconds, and it is the file
`llama-server` is pointed at — which is why it looks absent from a list of active jobs.

### 2. Prove the bytes before copying them

`SHA256SUMS` was seeded beside the shards on 2026-11-09, while the download was still running: the
publisher's LFS `oid`s are known before the bytes are, so the manifest travels with the `rsync` and
the check never trusts our own copy.

```bash
cd /srv/data/downloads/deepseek-v4-flash
sha256sum -c SHA256SUMS            # ~5 min: 60.7 GB off the array
```

Only meaningful once both shards report `complete` — a partial file fails the hash, which is the
point. Regenerate or audit it from the same source:

```bash
curl -s 'https://huggingface.co/api/models/Synchopate/DeepSeek-V4-Flash-0731-Fractal-64GB-CPU-GGUF/tree/main?expand=true' \
  | jq -r '.[] | select(.type=="file" and .lfs.oid) | "\(.lfs.oid)  \(.path)"'
```

Five files carry a published hash (three shards, both binaries); the patch is a git blob with none,
so its line is computed locally and a `#` comment says as much — `sha256sum -c` skips those.
`.gitattributes`, `README.md` and `transcode_dsv4.c` are not fetched and must not be listed, or the
check fails on a missing file rather than on a bad one.

Published lengths, for a byte-count check that takes seconds: `00001` 5,257,664 · `00002`
36,472,476,064 · `00003` 24,261,609,024. A short file is a resume, not a copy — requeue that GID
rather than rsyncing a truncated shard.

### 3. Copy over the LAN

~60.7 GB at gigabit is about ten minutes. The HF CDN served this host at 1.45 MB/s (2026-11-03), so
frieren's copy is the only sane source.

```bash
ssh eisen 'install -d -m 0755 -o devji -g users /mnt/storage/models/deepseek-v4-flash'
rsync -a --info=progress2 --no-inc-recursive \
  /srv/data/downloads/deepseek-v4-flash/ \
  eisen:/mnt/storage/models/deepseek-v4-flash/
ssh eisen 'chmod +x /mnt/storage/models/deepseek-v4-flash/llama-*-modchip-linux-x86_64'
```

The two binaries arrive `0644` and the unit's `ExecStart` is the binary itself, so the `chmod` is
load-bearing. Verify on the destination, where a corrupt copy would actually live:

```bash
ssh eisen 'cd /mnt/storage/models/deepseek-v4-flash && sha256sum -c SHA256SUMS'
```

`/mnt/storage` needs 61 GB free first, and the array's `compress=zstd` buys nothing on weights.

### 4. Enter the persona and clear the box

57.61 GiB of VmRSS against 62.5 GiB usable leaves nothing to share.

```bash
ssh eisen 'sudo /run/current-system/specialisation/server/bin/switch-to-configuration switch'
ssh eisen 'systemctl is-active display-manager.service; sudo systemctl stop strata'
ssh eisen 'free -g | head -2'
```

`strata` owns `:8085` and the expert arena; `llama-swap` is already dormant. The gaming guard does
not exist in this persona, so nothing will stop the model mid-run.

### 5. Start it as a transient unit

The module stays unimported, so this is `systemd-run` with the module's own flags. The publisher's
launch line also passes `-b 2048 -ub 512`, which are llama.cpp's defaults. No `MemoryMax`: the
mapping is reclaimable, and a cap turns page-cache pressure into a thrash instead of a number.

```bash
ssh eisen 'sudo systemd-run --unit=dsv4-probe \
  --property=User=devji --property=Group=users --property=LimitCORE=0 \
  --property=WorkingDirectory=/mnt/storage/models/deepseek-v4-flash \
  --property=StandardOutput=append:/mnt/storage/models/deepseek-v4-flash/probe.log \
  --property=StandardError=append:/mnt/storage/models/deepseek-v4-flash/probe.log \
  /mnt/storage/models/deepseek-v4-flash/llama-server-modchip-linux-x86_64 \
    -m /mnt/storage/models/deepseek-v4-flash/DeepSeek-V4-Flash-0731-Fractal-00001-of-00003.gguf \
    --alias deepseek-v4-flash --host 127.0.0.1 --port 8086 \
    --threads 12 --threads-batch 24 --ctx-size 32768 --parallel 1 \
    --flash-attn on --jinja --metrics'

ssh eisen 'curl -s --max-time 900 http://127.0.0.1:8086/health; systemctl show dsv4-probe -p MemoryCurrent'
```

`LimitCORE=0` is the 2026-11-04 lesson from `strata.nix`: a dying 57 GiB address space streams into
the dump spool before `ProcessSizeMax` is consulted. Load is minutes of HDD reads.

### 6. Measure — this pack has no `llama-bench`

The repository ships two binaries, `llama-server` and `llama-cli`; stock `llama-bench` cannot open
these files anyway (`unknown tensor type 40`). Prefill and decode come from the server's own
`timings` on a non-streaming `/completion` (if the fork omits it, use the `/metrics` deltas below):

```bash
PROMPT=$(yes 'The quick brown fox jumps over the lazy dog.' | head -60 | tr '\n' ' ')
for i in 1 2 3; do
  curl -s http://127.0.0.1:8086/completion -H 'Content-Type: application/json' \
    -d "$(jq -n --arg p "$PROMPT" '{prompt:$p,n_predict:128,temperature:0,cache_prompt:false}')" \
  | jq -r '.timings | "pp \(.prompt_per_second|floor) tok/s over \(.prompt_n) · tg \(.predicted_per_second|round) tok/s over \(.predicted_n)"'
done
```

Report `prompt_n` beside the rate: that prompt is ~600 tokens, not the 512 the note names, and a rate
without its token count compares to nothing. `cache_prompt:false` is what makes runs 2 and 3 pay the
prompt again — drop it and the numbers look excellent and mean nothing.

The agent turn is what the box is actually for, and Strata's baseline spends 93.77 s per turn to
first token, so measure that path too. The OpenAI endpoint returns no `timings`; take `/metrics`
deltas around one real session:

```bash
ssh eisen 'curl -s http://127.0.0.1:8086/metrics | grep -E "^llamacpp:(tokens_predicted_total|tokens_predicted_seconds_total|prompt_tokens_total|prompt_seconds_total) "'
```

`Δ tokens_predicted_total / Δ tokens_predicted_seconds_total` is decode across the session, cache hits
included — the fair comparison to 19.4 tok/s. The trial has no LAN surface (`--host 127.0.0.1`, and
`/deepseek/` lives in the unimported module): drive the agent on eisen, or
`ssh -L 8086:127.0.0.1:8086 eisen` and point the client at `http://127.0.0.1:8086/v1`.

### 7. Stop, restore, record

```bash
ssh eisen 'sudo systemctl stop dsv4-probe; sudo systemctl reset-failed dsv4-probe'
ssh eisen 'sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch'
ssh eisen 'sudo systemctl start strata; systemctl --failed'
```

`strata` was stopped by hand, so the switch back to the base generation will not restart it.

Then the note, never a new root file: a decode rate that beats Strata on the same box (14.6–21.0
tok/s warm decode, 19.4 tok/s agent session, 167 tok/s ingestion) earns `./deepseek-v4.nix` an
import, a port on `eisen.lan` and a router entry; anything else is `REJECTED` carrying the measured
number, and the pack stays on disk. A kept number goes into MANUAL §7 beside the Strata rows.
