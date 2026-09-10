# Getting started with PandaBert

## Build and run

Requires Apple Silicon macOS 13 or later. Build on this machine with the full Xcode toolchain:

```sh
bash scripts/package.sh
open dist/PandaBert.app
```

The app is locally ad-hoc signed, not notarized for public distribution. Quit it from the PandaBert menu-bar menu. Drag the panel background to move it; resize from an edge. Settings are behind the bottom-right sliders icon.

All PandaBert preferences and its small pinned-task cache live in `~/Library/Application Support/Pulse`. `PANDA_HOME` overrides this for isolated tests; the legacy `PULSE_HOME` variable also works. The existing `Pulse` data folder and app bundle identifier are retained for upgrade compatibility. Provider folders are only read; no Claude/Codex credentials, hooks or settings are modified. The app does not start, stop or approve any agent.

## Guided setup

A fresh app installation opens a three-step wizard:

1. **Find your activity:** select local Claude Code/Codex profile roots and give them recognizable names. PandaBert checks standard roots and up to 64 conventional `.claude-*` / `.codex-*` folders. Choose another folder for custom locations; select the root containing `projects` (Claude) or `sessions` (Codex), not an individual transcript. A green dot means the log directory is readable, not that an account or live session has been verified.
2. **Your other Macs:** optionally add an already trusted SSH alias and installed collector. The prerequisites below still apply; the wizard does not install the remote collector, create credentials or verify the remote connection. Connection results appear after saving.
3. **Review your setup:** review your selection and optionally enable linked GitHub PR checks using an existing `gh` login. Choose **Save and start** to persist the configuration and begin observation.

Closing before saving leaves setup unfinished and starts no observation on a fresh installation. The wizard can be reopened with **Set up PandaBert**. On existing installations, use **Connections → Run setup wizard**; closing discards wizard changes, and saving preserves pins, per-turn review history and unrelated preferences. Settings that cannot be read are not overwritten by setup. The standalone collector CLI retains its existing default-folder behavior.

Standard Claude and Parall desktop-link folders are automatically checked. Folder labels are chosen by you; PandaBert does not verify account ownership, switch the active provider account, or connect regular Claude Chat/Cowork.

## Connect another Mac

Use an already established SSH alias with key authentication and a verified known-host entry. PandaBert does not enroll hosts, change SSH configuration, accept new host keys or ask for passwords. On the other Mac, build this package or transfer the matching Apple Silicon collector, then install the binary at `~/.local/bin/panda-agent`. For example, on that Mac from a built package:

```sh
mkdir -p ~/.local/bin
cp dist/PandaBert.app/Contents/Resources/panda-agent ~/.local/bin/panda-agent
~/.local/bin/panda-agent snapshot
```

PandaBert prefers `panda-agent` on remote Macs and falls back to an existing `pulse-agent` installation. The snapshot protocol remains compatible.

In PandaBert Connections, enter a label and the existing SSH alias. Each machine keeps its Claude/Codex logins; PandaBert receives normalized task metadata and recent excerpts over encrypted SSH. A machine with two separately stored profiles can expose both by configuring its PandaBert preferences locally. Account switching inside the same provider home is not account attribution: give separate roots distinct labels.

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
