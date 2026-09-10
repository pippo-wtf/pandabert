# Getting started with Pulse

## Build and run

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

## Development checks

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache" \
swift test --disable-sandbox --scratch-path .build -j 4
```

Tests cover out-of-order turn completion, question correlation, tool failure versus run failure, uncertain/offline states, pin persistence, per-turn reviews, repository identity, incomplete and rotated logs, GitHub review/check distinctions, remote snapshot validation and command timeouts. See [validation results](../VALIDATION.md) for actual runtime results and remaining checks.


[Back to the overview](../README.md)
