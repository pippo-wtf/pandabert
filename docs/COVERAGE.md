# Coverage and limitations

PandaBert 0.3.0 is a local preview. These limits describe the implementation, not a promise of future delivery.

## Collection behavior

- Saved preferences are read strictly by both the app and collector. Invalid or unreadable settings stop observation and preserve the file; defaults apply only when settings are absent. The collector exits with an error and no snapshot, and watch mode rechecks settings before every emission.
- Local scans run on their own worker, scheduled every five seconds when that worker is free. SSH and GitHub use separate workers and publish results as they arrive. Each worker permits only one in-flight batch; slow external checks cannot block subsequent local scans. SSH batches are normally retried after 30 seconds and GitHub after 60 seconds, measured from batch completion. Scan and network time still affect each source's freshness.

## Known coverage limits

- Ordinary Claude Chat and Cowork are **not connected**. They need independently verified access paths.
- Passive logs do not reliably expose all permission prompts, pending queue events or async questions. Permission-hook parsing is reserved for a later explicitly wired adapter; no hook is installed in this build.
- Log writes may be delayed. This is observed log activity, not authoritative process liveness. A finished turn does not mean a project is complete.
- The collector scans the last 14 days, at most 250 recent log files per profile, skips subagent folders and reports partial coverage. Large files retain initial metadata plus the recent 2 MiB; an individual oversized or incomplete line may be skipped. When a span is skipped, lifecycle state from before that gap is discarded. A retained completion can establish the new state; otherwise the task may show Status uncertain until sufficient new evidence appears. There is no full-history transcript database.
- **Open thread** on every card and in Details jumps to the existing Codex or linked Claude conversation. Codex uses its local thread ID; Claude requires an explicit local desktop-session mapping from the standard Claude folder or a Parall profile folder, which is checked again when clicked. Bridge IDs alone do not enable navigation. The destination app must be signed in to an account that can access that conversation. Sessions without a local desktop link and remote sessions remain explicitly unavailable; PandaBert does not create/import a replacement conversation. Session IDs can still be copied and local transcripts revealed.
- GitHub Enterprise, full PR discovery, milestones/progress aggregation, natural-language dependency extraction, lifecycle hooks and automatic account/machine discovery are not in this preview.
- A provider profile is a folder label, not a verified billing-account identity. No universal four-account cloud login has been implemented.
- GitHub is off by default. With it enabled, GitHub receives linked PR URLs and the usual CLI API requests; chat excerpts are never sent to GitHub or NotebookLM. Remote observation intentionally transfers excerpts to the panel Mac.


## Validation status

The local panel, collection, pin persistence and one mapped Claude desktop navigation have been exercised live. Remote collection and four simultaneous account/profile combinations still need a real multi-machine acceptance run. The latest source suite passed 42 tests. See [VALIDATION.md](../VALIDATION.md) for what was actually checked and [NAVIGATION.md](../NAVIGATION.md) for thread-link behavior.

[Back to the overview](../README.md)
