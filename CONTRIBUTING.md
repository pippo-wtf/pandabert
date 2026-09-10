# Contributing to Pulse

Pulse is a private preview. Small, focused changes are easiest to review.

## Report a problem

Use the bug-report template and include the Pulse version, macOS version, provider app version, desktop or terminal mode, and whether the task is local or remote. Describe what you expected and what Pulse actually showed. Include reproduction steps if possible.

A diagnostic export is available in **Connections → Export diagnostics**. It contains aggregate counts, not task text. Review attachments before sharing: screenshots and raw transcripts can contain private project names, prompts or account information. Do not attach credentials or full provider logs.

## Work on a change

1. Read the [overview](README.md), [coverage limits](docs/COVERAGE.md), and the relevant source.
2. Create a focused branch and keep the change reviewable.
3. Build and run the checks in the [setup guide](docs/GETTING_STARTED.md#development-checks).
4. For behavior changes, add a regression test that exercises the failure. For visual changes, inspect the running native app.
5. Open a pull request explaining the problem, resulting behavior, and checks performed. State what remains unverified.

## Project map

| Location | Responsibility |
| --- | --- |
| `Sources/Pulse` | Native panel, controls and app state |
| `Sources/PulseCore` | Session parsing, repository grouping, models, navigation and collectors |
| `Sources/PulseAgent` | Command-line collector for snapshots |
| `Tests/PulseCoreTests` | Parsing, state and navigation tests |
| `scripts/package.sh` | Build, local signing and packaging |

## Preserve these boundaries

- Observe provider data without editing credentials, settings or transcripts.
- Never start, stop, approve, import or resume agent sessions as a side effect of navigation.
- Keep uncertain and unavailable states explicit; do not turn missing evidence into a success claim.
- Keep local, remote and profile identities distinct.
- Use isolated `PULSE_HOME` folders and sample data for tests. Do not change an operator's running agents or personal preferences.
- Keep private activity snapshots, build output and real task data out of commits.

[Back to Pulse](README.md)
