# Pulse 0.1.4 — local preview

A small native macOS attention panel for Claude Code and Codex. The approved Attention design uses a white surface, near-black toolbar and lavender accents. The panel stays above ordinary windows, follows Spaces and can be reopened from the menu bar.

Small status dots carry the color coding: **lavender** for active work, **yellow** for tasks needing attention, **green** for finished/reviewed turns, and **grey** for waiting, idle or uncertain activity. Cards stay neutral. Lavender buttons use white text.

## What works in this version

- Reads accessible Claude Code and Codex JSONL session logs, including desktop sessions that write these formats.
- Labels observed working, question, completion and interruption events. Three minutes without new working evidence becomes **Status uncertain**.
- Groups clones by normalized repository remote; keeps forks and machine-local repositories separate.
- Pins tasks above the attention list, preserves pin order and reviewed-turn acknowledgements across relaunches. A pinned task that leaves observation coverage remains visible with uncertain status.
- Shows recent message excerpts, source machine/profile, repository grouping and explicit waiting notes. Project display aliases are editable.
- Optional GitHub CLI enrichment for up to 12 linked pull requests each cycle, using the existing `gh` login.
- Additional profile roots, and a collector snapshot protocol over existing trusted SSH connections.
- Optional macOS login-item registration and a diagnostics export containing only aggregate counts. Login-item registration itself has not yet been tested.

Old completed turns are placed in the background on first launch. Only completions after tracking began become new review items. Existing explicit unanswered questions still appear. A review acknowledgement applies to one completed turn; the next completion can surface again.

## Run

Requires Apple Silicon macOS 13 or later. Build on this machine with the full Xcode toolchain:

```sh
bash scripts/package.sh
open dist/Pulse.app
```

The app is locally ad-hoc signed, not notarized for public distribution. Quit it from the Pulse menu-bar menu. Drag the panel background to move it; resize from an edge. Settings are behind the bottom-right sliders icon.

All Pulse preferences and its small pinned-task cache live in `~/Library/Application Support/Pulse`. `PULSE_HOME` overrides this for isolated tests. Provider folders are only read; no Claude/Codex credentials, hooks or settings are modified. The app does not start, stop or approve any agent.

## Connect another Mac

Use an already established SSH alias with key authentication and a verified known-host entry. Pulse does not enroll hosts, change SSH configuration, accept new host keys or ask for passwords. On the other Mac, build this package or transfer the matching Apple Silicon collector, then install the binary at `~/.local/bin/pulse-agent`. For example, on that Mac from a built package:

```sh
mkdir -p ~/.local/bin
cp dist/Pulse.app/Contents/Resources/pulse-agent ~/.local/bin/pulse-agent
~/.local/bin/pulse-agent snapshot
```

In Pulse Connections, enter a label and the existing SSH alias. Each machine keeps its Claude/Codex logins; Pulse receives normalized task metadata and recent excerpts over encrypted SSH. A machine with two separately stored profiles can expose both by configuring its Pulse preferences locally. Account switching inside the same provider home is not account attribution: give separate roots distinct labels.

Remote reading uses fixed arguments, BatchMode, StrictHostKeyChecking and a bounded response. The snapshot carries a protocol version, timestamp and stable machine/session identity; stale or mismatched responses are rejected. Failed remote refreshes retain last-known tasks with an unavailable state. This is implemented but still requires a real second-machine acceptance run.

## Known coverage limits

- Ordinary Claude Chat and Cowork are **not connected**. They need independently verified access paths.
- Passive logs do not reliably expose all permission prompts, pending queue events or async questions. Permission-hook parsing is reserved for a later explicitly wired adapter; no hook is installed in this build.
- Log writes may be delayed. This is observed log activity, not authoritative process liveness. A finished turn does not mean a project is complete.
- The collector scans the last 14 days, at most 250 recent log files per profile, skips subagent folders and reports partial coverage. Large files retain initial metadata plus the recent 2 MiB; an individual oversized or incomplete line may be skipped. There is no full-history transcript database.
- **Open thread** on every card and in Details jumps to the existing Codex or linked Claude conversation. Codex uses its local thread ID; Claude requires an explicit local desktop-session mapping, which is checked again when clicked. Bridge IDs alone do not enable navigation. The destination app must be signed in to an account that can access that conversation. Sessions without a local desktop link and remote sessions remain explicitly unavailable; Pulse does not create/import a replacement conversation. Session IDs can still be copied and local transcripts revealed.
- GitHub Enterprise, full PR discovery, milestones/progress aggregation, natural-language dependency extraction, lifecycle hooks and automatic account/machine discovery are not in this preview.
- A provider profile is a folder label, not a verified billing-account identity. No universal four-account cloud login has been implemented.
- GitHub is off by default. With it enabled, GitHub receives linked PR URLs and the usual CLI API requests; chat excerpts are never sent to GitHub or NotebookLM. Remote observation intentionally transfers excerpts to the panel Mac.

## Checks

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache" \
swift test --disable-sandbox --scratch-path .build -j 4
```

Tests cover out-of-order turn completion, question correlation, tool failure versus run failure, uncertain/offline states, pin persistence, per-turn reviews, repository identity, incomplete and rotated logs, GitHub review/check distinctions, remote snapshot validation and command timeouts. See `VALIDATION.md` for actual runtime results and remaining checks.

## Research provenance

The research compared [Jarvis](https://github.com/Sergey-Chernyshev/jarvis), [AgentBar](https://github.com/michalstrnadel/AgentBar) and [so-agentbar](https://github.com/sotthang/so-agentbar), plus official Claude/Codex documentation. This implementation is a small independent Swift package based on observed local log records; it does not vendor those projects or inherit their deployment claims. Private research notes, session snapshots and design-workspace files are excluded from this repository.
