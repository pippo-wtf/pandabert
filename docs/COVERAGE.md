# Coverage and limitations

Panda 0.2.2 is a local preview. These limits describe the implementation, not a promise of future delivery.

## Known coverage limits

- Ordinary Claude Chat and Cowork are **not connected**. They need independently verified access paths.
- Passive logs do not reliably expose all permission prompts, pending queue events or async questions. Permission-hook parsing is reserved for a later explicitly wired adapter; no hook is installed in this build.
- Log writes may be delayed. This is observed log activity, not authoritative process liveness. A finished turn does not mean a project is complete.
- The collector scans the last 14 days, at most 250 recent log files per profile, skips subagent folders and reports partial coverage. Large files retain initial metadata plus the recent 2 MiB; an individual oversized or incomplete line may be skipped. There is no full-history transcript database.
- **Open thread** on every card and in Details jumps to the existing Codex or linked Claude conversation. Codex uses its local thread ID; Claude requires an explicit local desktop-session mapping from the standard Claude folder or a Parall profile folder, which is checked again when clicked. Bridge IDs alone do not enable navigation. The destination app must be signed in to an account that can access that conversation. Sessions without a local desktop link and remote sessions remain explicitly unavailable; Panda does not create/import a replacement conversation. Session IDs can still be copied and local transcripts revealed.
- GitHub Enterprise, full PR discovery, milestones/progress aggregation, natural-language dependency extraction, lifecycle hooks and automatic account/machine discovery are not in this preview.
- A provider profile is a folder label, not a verified billing-account identity. No universal four-account cloud login has been implemented.
- GitHub is off by default. With it enabled, GitHub receives linked PR URLs and the usual CLI API requests; chat excerpts are never sent to GitHub or NotebookLM. Remote observation intentionally transfers excerpts to the panel Mac.


## Validation status

The local panel, collection, pin persistence and one mapped Claude desktop navigation have been exercised live. Remote collection and four simultaneous account/profile combinations still need a real multi-machine acceptance run. The latest source suite passed 35 tests. See [VALIDATION.md](../VALIDATION.md) for what was actually checked and [NAVIGATION.md](../NAVIGATION.md) for thread-link behavior.

[Back to the overview](../README.md)
