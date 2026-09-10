# Pulse 0.1.0 validation — 2026-09-10

## Verified

- Release build succeeded with the full Xcode toolchain, Apple Silicon. The packaged app and embedded collector passed local ad-hoc signature verification.
- Latest source test run: **11 XCTest tests, 0 failures**, 16:22 local time. Complete output is in `.build/test-results.txt` (build output is not included in the distributable).
- Actual read-only local scan: **308 sessions**, comprising **107 Claude** and **201 Codex** sessions. The first snapshot grouped them into 30 repository identities; the subsequent live panel showed 31 as source activity changed. These are recent log records, not 308 running agents or proof of distinct billing accounts.
- Debug collector cold scan took **11.3 seconds** on the available local data. Subsequent app scans cache unchanged logs; no comprehensive CPU/battery benchmark has been run.
- Native app launched, loaded both local sources, and displayed the approved white/lavender attention layout. The project menu contrast was corrected after inspecting an actual screenshot.
- A real working Codex task appeared in the background. Pinning it moved it into the top Pinned section. Its live excerpt appeared in task details.
- Pin persistence verified in the saved preference file and **after stopping and reopening only Pulse**. The test pin was then removed through the UI.
- A separate real Codex task completed during verification and automatically appeared under Needs You. Its completion was not acknowledged on the user's behalf.
- Connections sheet shows local profile roots, additional profile/SSH controls, coverage limits and toggles. GitHub and launch-at-login remain off; no remote machines have been added.
- The diagnostic export was saved through the native dialog and inspected: it contains version/time and aggregate session/project/state/source counts, not task text, paths, session IDs or account labels.
- Pulse's machine ID, preferences and pinned-task cache files use mode 0600. Provider configuration and the Dieter source tree were not modified.

## Tested with fixtures, not yet proven across live provider workflows

Question/tool-return correlation; stale and mismatched turn completion; tool failure versus run failure; offline freshness; GitHub review/check distinctions; remote protocol validation and SSH-host input validation; incomplete/rotated logs; per-turn review acknowledgements; repository clone/fork identity; first-launch historical backlog behavior; bounded command timeout.

## Still required for broader rollout

- A real second-machine install and trusted SSH connection, then all four account/profile combinations concurrently. No cross-machine deployment is claimed.
- Live permission, question, reconnect and queue-state exercises for each supported Claude/Codex desktop/terminal mode. Passive logs cannot provide every state; the UI declares this limitation.
- Live GitHub authentication/enrichment checks. This preview supports linked public github.com URL shapes; no Enterprise connector is present.
- Login-at-login registration and reboot/login acceptance. The control is implemented but was not enabled during testing.
- Ordinary Claude Chat and Cowork connectors, reliable cross-app navigation to exact sessions, comprehensive project milestones/progress and natural-language dependency extraction.
- Performance measurement over long-running sessions and larger multi-machine datasets; signed/notarized distribution and an update mechanism.

The app currently runs from `dist/Pulse.app`. No provider hook, daemon, approval policy or credential was installed or changed.

## Navigation update — 0.1.1

- Added Open thread to every task card and to Details, with explicit provider-bundle dispatch and visible missing/unlinked-destination explanations.
- Final suite: **18 tests, 0 failures**, 16:44 local time. Output: `.build/test-results-0.1.1.txt`. Release app and collector rebuilt and ad-hoc signatures verified.
- Live button test successfully navigated Claude from another page to **the selected local conversation**, at the exact desktop session ID obtained from its local metadata. No prompt was sent and nothing was marked reviewed.
- A bridge-only **test conversation** link navigated to its recorded server-session route, but Claude displayed **This session couldn't be found**. Availability for that session/account is not verified. Pulse cannot establish access from a successful OS URL-open acknowledgement.
- Initial Claude code-host links were observed in the app log as feature-gated off. The final implementation uses the existing claude.ai conversation handler and normalizes bridge/server IDs; it does not change feature flags or security settings.
- Codex URL shape is verified against its installed URL parser and unit tests. Its button was exercised, but the computer-use tool explicitly refused access to `com.openai.codex`; **visual destination verification remains blocked**. No alternate UI-capture method was used.
- No automatic import/resume fallback is used for unlinked terminal conversations. Remote Codex navigation remains unavailable until host identities are mapped. Destination accounts and removed sessions remain app-owned access checks.

## Status colors — 0.1.2

- Active work uses a solid lavender card with white text and icons. Questions, approvals, failures and results awaiting review use yellow; finished/reviewed turns use green; waiting, idle, interrupted and uncertain states use grey. Pins retain their status color.
- Lavender action buttons now use white labels throughout cards and Details. The deeper lavender has a calculated 4.81:1 contrast against white. Empty-state and transcript surfaces are neutral grey.
- Added a compact four-color legend to Connections. The header attention count and collector-health indicator also reflect their meanings.
- Release build and signature verification passed; all **18 existing tests passed**. No new tests were added for the styling change. Visual inspection of the running native app confirmed the legend and real active, finished and uncertain cards, including white labels on lavender.

## Subtle status dots — 0.1.3

- Restored neutral cards and the original lavender accent. Only the small status dots carry active/attention/finished/waiting colors; the legend also uses dots rather than colored pills.
- Lavender button and toolbar-pill labels remain white. Pins use a subtle outline without changing card backgrounds.
- Release build and local signature verification passed. Status classification is unchanged from 0.1.2; this revision adjusts presentation only.


## Claude unavailable-link fix — 0.1.4

- Removed bridge-only navigation. A valid bridge ID can refer to a conversation unavailable in the signed-in desktop app; it no longer enables the button locally or remotely.
- Claude navigation requires an explicit local CLI-to-desktop mapping. The mapping is loaded again on click, including for cached/pinned tasks, and missing or ambiguous records prevent dispatch.
- All **21 tests passed**, including bridge-only rejection and deleted, changed and ambiguous mappings. Output: `.build/test-results-0.1.4.txt`.
- Release build and local signature verification passed; the embedded collector reports version 0.1.4.
- Account authorization remains owned by Claude. Local identity metadata does not independently establish access for a different signed-in account.
- Live native panel verification: the previously failing bridge-only task now has a disabled Open thread button and an unavailable-mapping explanation. The neutral cards and subtle status dots are preserved. No message was sent or task marked reviewed.


## Latest attention glow — 0.1.5

- The newest observed attention event receives a subtle lavender edge and halo for 30 seconds. The eight-second breathing cycle eases in over three seconds and fades out over the final five seconds. Neutral cards, status dots and pin outlines are preserved.
- Repeated polling, unchanged GitHub check timestamps, reconnects and startup backlog do not replay the same notification. Pins remain eligible; only one newest arrival glows. Reviewing or resolving the active attention item clears it.
- Reduce Motion uses a steady highlight with the same entry/exit fade, without the breathing cycle. The overlay does not intercept clicks or enter the accessibility tree; its timeline is removed after expiration.
- All **28 tests passed**, including seven new notification-detection regression tests. Output: `.build/test-results-0.1.5.txt`.
- Release build and local signature verification passed. Native UI inspection used an isolated sample-data copy with the production views and arrival logic: the target card glowed, the pinned card retained its usual outline, and the glow disappeared after the time window. This is fixture-driven UI verification, not a newly recorded live-provider notification test. Reduce Motion behavior was implemented but not toggled in the user's system settings during verification.


## Softer outline, stronger halo — 0.1.6

- Halved the newest-notification outline opacity from 0.65 to 0.325. Increased both halo-layer opacity factors by 30%; the halo is rendered separately so reducing the sharp outline does not also weaken the glow.
- Timing, notification detection, pin outlines and status dots are unchanged.
- Release build and local signature verification passed. Inspected the active glow in the isolated native sample preview. This is a presentation-only change; the unchanged 28-test suite was last run for 0.1.5 and was not rerun for this adjustment.
