# Coverage and limitations

PandaBert 0.4.5 is a local preview. These limits describe the implementation, not a promise of future delivery.

## Collection behavior

- Saved preferences are read strictly by both the app and collector. Invalid or unreadable settings stop observation and preserve the file; defaults apply only when settings are absent. The collector exits with an error and no snapshot, and watch mode rechecks settings before every emission.
- Local scans run on their own worker, scheduled every five seconds when that worker is free. SSH and GitHub use separate workers and publish results as they arrive. Each worker permits only one in-flight batch; slow external checks cannot block subsequent local scans. SSH batches are normally retried after 30 seconds and GitHub after 60 seconds, measured from batch completion. Scan and network time still affect each source's freshness.

## Known coverage limits

- Ordinary Claude Chat and Cowork are **not connected**. They need independently verified access paths.
- Passive logs do not reliably expose all permission prompts, pending queue events or async questions. Permission-hook parsing is reserved for a later explicitly wired adapter; no hook is installed in this build.
- Log writes may be delayed. This is observed log activity, not authoritative process liveness. A finished turn does not mean a project is complete.
- The collector scans the last 14 days, at most 250 recent log files per profile, skips subagent folders and reports partial coverage. Large files retain initial metadata plus the recent 2 MiB; an individual oversized or incomplete line may be skipped. When a span is skipped, lifecycle state from before that gap is discarded. A retained completion can establish the new state; otherwise the task may show Status uncertain until sufficient new evidence appears. There is no full-history transcript database.
- **Open thread** on supported cards and in Details jumps to the existing Codex or linked Claude conversation. Codex uses its local thread ID; Claude requires an explicit local desktop-session mapping from the standard Claude folder or a Parall profile folder, which is checked again when clicked. Bridge IDs alone do not enable navigation. The destination app must be signed in to an account that can access that conversation. Explicit Claude CLI sessions without a desktop mapping show a noninteractive **Terminal session** label. Unknown/desktop origins and remote sessions without supported routing remain explicitly unavailable; PandaBert does not create/import a replacement conversation. Session IDs can still be copied and local transcripts revealed.
- GitHub Enterprise, full PR discovery, milestones/progress aggregation, natural-language dependency extraction, lifecycle hooks and automatic account/machine discovery are not in this preview.
- A provider profile is a folder label, not a verified billing-account identity. No universal four-account cloud login has been implemented.
- GitHub is off by default. With it enabled, GitHub receives linked PR URLs and the usual CLI API requests; chat excerpts are never sent to GitHub or NotebookLM. Remote observation intentionally transfers excerpts to the panel Mac.


## Validation status

The local panel, collection, pin persistence and one mapped Claude desktop navigation have been exercised live. Remote collection and four simultaneous account/profile combinations still need a real multi-machine acceptance run. The latest source suite passed 62 tests. See [VALIDATION.md](../VALIDATION.md) for what was actually checked and [NAVIGATION.md](../NAVIGATION.md) for thread-link behavior.

[Back to the overview](../README.md)

## Guided setup

The app opens a three-step wizard when no preferences file exists. It discovers conventional local profile folders, supports custom directory selection and profile names, and collects optional existing SSH/collector connections and GitHub-check preferences. Observation starts after a successful save. Existing installations can rerun it from Connections without losing pins or review history. It does not verify account identity, install remote collectors, enroll SSH hosts or perform GitHub login. Folder availability and actual connection health are distinct.

## Acknowledging finished responses

**Mark as seen** clears that finished response in PandaBert. A successful operating-system handoff from **Open thread** also marks the clicked completion as seen. Failed opens, questions and responses that changed while navigation was pending remain unacknowledged. This does not confirm destination-account access or approve anything in GitHub. A fresh response can surface again; pins and independent GitHub attention conditions remain intact.

## Folder permissions and signing

Project grouping reads only repository/path metadata in observed logs; it does not inspect project directories or run Git in them. If repository metadata is missing or contradictory, grouping falls back to the recorded local folder path, so cross-machine grouping may be less complete. Configured logs and Claude desktop-link metadata still require normal filesystem access. Selecting a custom log folder in a protected location may require consent. Ad-hoc builds can prompt again after rebuilding; persistent Developer ID signing is supported by the packaging script but requires an installed signing identity. macOS permissions are not altered or bypassed.
