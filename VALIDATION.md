# Validation history

## Pulse 0.1.0 — 2026-09-10

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


## Panda rename — 0.2.0

- Renamed the native panel, window, menu labels, app bundle/display name, package/modules, collector, diagnostic filename and current documentation to Panda. Refreshed all four README screenshots using fictional tasks in the renamed native interface.
- The packaged app is `dist/Panda.app`, with `panda-agent` and a `pulse-agent` executable alias. Remote observation prefers the new collector name and falls back to legacy installations; the snapshot protocol remains 1.
- Kept the existing app bundle identifier, window-position key and `Application Support/Pulse` data location for compatibility. `PANDA_HOME` is the preferred override, with `PULSE_HOME` retained as a fallback.
- All **31 tests passed**, including new compatibility coverage for the data path and both environment overrides. Release build and local signature verification passed; both collector names report 0.2.0.
- The real Panda app launched successfully. Hashes of existing preferences, pinned-task cache and machine identity were unchanged after launch. The old local `Pulse.app` shortcut resolves to `Panda.app`; the previous build was retained in ignored local build output. Login-at-login behavior across a full reboot was not exercised.
- This is a naming/compatibility update; the issues identified by the prior code review remain unresolved.


## Brand subline — 0.2.1

- Added “Keeps you on track” directly beneath Panda in the compact header and as the README subline. Tightened header spacing and kept the attention count on one line.
- Release build and local signature verification passed. Native sample-data inspection confirmed the full subline, project selector and one-line count fit at the default 364-point panel width. Refreshed the header-bearing README screenshots.
- Presentation-only change. The 31-test suite was last run for 0.2.0; it was not rerun for this text/layout adjustment.


## Claude second-account links and fork identity — 0.2.2

- Root cause: a Parall-launched Claude instance stored desktop conversation metadata outside the standard Claude folder. Activity logs were visible to Panda, but their desktop ID mappings were not. The index now discovers standard Claude metadata plus up to 64 Parall profile folders, with a shared 3,000-record bound and existing identity validation. Prior CLI ID arrays are recognized. Cross-profile ambiguous mappings remain unavailable.
- Claude UUID-named transcripts now use the filename as their native identity. Records explicitly belonging to another session are ignored, preventing copied fork history from supplying the parent's title, bridge, activity or deduplication key.
- All **35 tests passed**, including new Parall discovery, deleted-map revalidation, cross-profile ambiguity, prior-ID and separate parent/fork regression tests. Release packaging and local signature verification passed.
- Live collector verification resolved the previously disabled conversation to its exact desktop ID. It also returned separate parent and fork records with the correct IDs, with no inherited parent bridge on the fork.
- Live native acceptance: selected a different existing Claude conversation, clicked the previously disabled task's Open thread button in Panda, then verified Claude changed to the target's exact desktop route and displayed its matching title. No prompt was submitted or task marked reviewed. The standard Claude bundle was running with the Parall profile on this machine.
- Automatic switching between separately signed-in app instances, remote navigation and four-account multi-machine acceptance remain unverified. Metadata establishes identity, not authorization in a different active account. The earlier unrelated code-review findings remain open.


## Code-review fixes — 0.2.3

All three findings from the 0.1.6 review are addressed:

- **Unreadable preferences:** the app and CLI share strict preference loading. Only an absent file permits first-launch defaults. Invalid JSON, incompatible data, unreadable files and dangling links stop observation. The app preserves the file, shows an error and prevents refresh/save from starting collection. The CLI exits nonzero with no snapshot; watch mode reloads preferences before every emission.
- **Truncated transcript state:** the collector explicitly separates retained metadata from the recent tail. At a skipped span it clears inherited lifecycle state, pending questions and obsolete turn IDs. A completion in the tail can establish the current turn; without sufficient evidence, the state remains uncertain instead of retaining an older finished turn. The original two failing review reproductions now pass against the collector and their full-log controls.
- **Slow external checks:** local, SSH and GitHub observation use independent single-flight workers. Local results publish after every scan, regardless of external work. External results merge into the latest local snapshot and publish individually; removed remote sources cannot reappear from in-flight results. Initial source snapshots seed the glow baseline without replaying a backlog.

Validation:

- **42 tests passed**, including the original review reproductions, app-level invalid-preferences test, settings-file edge cases, deliberately blocked SSH/GitHub workers with a subsequent local status change, late result merging, removed-remote handling and deferred-source glow baselines. Output: `.build/test-results-0.2.3.txt`.
- Real CLI subprocess checks in temporary state folders: valid empty observation scope emitted zero sessions; malformed/incompatible/unreadable settings exited 1 with empty stdout and preserved settings; a running watcher stopped without another snapshot after settings became invalid. No live provider preferences were edited.
- Release packaging and local signature verification passed. The packaged 0.2.3 collector also rejected corrupt settings before creating a collector identity, with zero stdout.
- Slow-network behavior was exercised using controlled blocking adapters, not by disrupting live SSH or GitHub connections. Multi-machine/four-account acceptance remains separate from these regressions.
- Live native smoke check: Panda 0.2.3 completed collection and displayed its attention/background tasks, both local sources and the enabled Claude conversation link. The existing quiet panel design was preserved.


## Panda logo — 0.2.4

- Replaced the original circular symbol with a panda face: ears, eye patches and a small nose with a rounded drip offset to the viewer's left. The final generated master has real alpha transparency; the discarded checkerboard drafts are not shipped.
- The compact header uses a white 23-point template mark. The menu bar uses the same adaptive template at 22 points. Packaging now includes the SwiftPM artwork resource bundle and a macOS app icon in all standard sizes, rendered from the same master on a white rounded tile. The README and all four sample screenshots were refreshed.
- All 42 tests passed after the resource integration. Release compilation, icon conversion and local signature verification passed. macOS icon conversion required running outside the restricted sandbox; the same valid icon set converted successfully there.
- The native sample panel was inspected at its existing 364-point width: the new mark fits alongside the full Panda name and subline. Screenshot tasks are fictional. Observation, navigation, pin and glow logic are unchanged in this release.
- Standalone resource check: temporarily removed the SwiftPM build-resource fallback, launched the packaged app and visually confirmed the logo rendered from its bundled resources. Restored the build resource afterward.


## PandaBert and flexible height — 0.3.0

- Renamed the app bundle, process/display name, header, menu actions, settings copy, diagnostics filename and current repository documentation to PandaBert. Kept “Keeps you on track” and the approved panda logo. Refreshed all four documentation screenshots with fictional tasks.
- Removed the fixed 1,000-point window-height cap. The 364–460-point width range and 420-point minimum height remain; macOS still applies its normal screen constraints. Existing window-frame autosave remains enabled.
- Preserved the app bundle identifier, data folder, collector command, environment overrides and internal Swift module/resource names. Existing settings, pins and machine identity carry over. The local legacy Panda.app shortcut now resolves to PandaBert.app; the older app bundle was retained in ignored build output.
- All 42 tests passed. Release packaging and local signature verification passed. The real PandaBert app launched, and native sample inspection confirmed the full name and subline fit the existing compact header.
- The UI automation adapter returned AXError.notImplemented for a window-edge drag. The height-cap removal is verified in the built source; an interactive drag beyond the old limit was not verified in this environment.
- GitHub repository renamed to pippo-wtf/pandabert and confirmed public. Source repository visibility and user data scope did not change.


## Terminal session information — 0.3.1

- Attempted to inspect macOS Terminal through the computer-control tool; it denied access to that app for safety reasons. Direct terminal-tab focusing was therefore not verified or integrated, and no alternate UI-control mechanism was used.
- Added explicit Claude transcript entrypoint handling: `cli` identifies terminal origin and `claude-desktop` identifies desktop origin. Bridge IDs no longer imply desktop origin. Missing origin metadata remains unknown; inherited parent records cannot supply the fork's origin.
- Unlinked terminal tasks show a quiet, noninteractive **Terminal session** label in cards and Details. A valid local desktop mapping still enables navigation. Existing unsupported desktop/unknown and remote routing behavior remains intact.
- All **45 tests passed**, including terminal records with bridge IDs, absent desktop mappings, inherited fork provenance, and an explicit origin change. Release packaging and local signature verification passed. Output: `.build/test-results-0.3.1.txt` and `.build/package-results-0.3.1.txt`.
- A real local collector snapshot identified six explicit terminal sessions with no desktop mappings. The running packaged app displayed the information label for the recent Claude CLI session; native accessibility inspection confirmed it was text rather than a disabled button, and visual inspection confirmed the label and explanation in Details. No prompt was submitted and no session was resumed/imported. Live user content was not added to public screenshots or test fixtures.


## Header arrow cleanup — 0.3.1 follow-up

- Removed the leading project-selector arrow. The native menu indicator is hidden; a single trailing chevron is drawn outside the menu label so macOS cannot relocate it to the leading icon slot.
- Release build, packaging and local signature verification passed. Inspected the running app visually: one arrow appears to the right of All projects, none to its left. Opened and dismissed the project dropdown successfully. No new tests were added for this presentation-only change.
