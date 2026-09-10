# Open thread — PandaBert

Task cards and the details sheet offer **Open thread** for supported navigation. Explicitly identified, unlinked terminal sessions show a quiet **Terminal session** information label instead. Task details remain available separately. Opening a finished response marks that response as seen in PandaBert once macOS successfully hands the link to the destination app. Navigation never submits a prompt.

## Routing evidence

Verified against the installed macOS applications on 2026-09-10:

- Codex bundle `com.openai.codex`, version `26.903.71938`, installed as `ChatGPT.app`: the registered `codex` URL handler accepts `codex://threads/<thread-id>` as a local-conversation navigation route.
- Claude bundle `com.anthropic.claudefordesktop`, version `1.49585.0`: the registered `claude` handler accepts existing conversation paths under `claude://claude.ai/epitaxy/<desktop-session-id>` and server conversation paths under `claude://claude.ai/code/<server-session-id>`.
- Claude's session store normalizes `cse_` bridge IDs to the server's `session_` form. The app's newer `claude://code/...` host was observed to be feature-gated off in the installed build, so PandaBert uses the existing `claude.ai` conversation handler.

These were checked in the installed apps' Info.plist and packaged navigation/session-store code. No app files or provider settings were changed. No third-party app code is included in PandaBert.

## Identity and limits

Codex uses the recorded native UUID. Claude requires an explicit local mapping read from its session metadata, using the CLI session ID rather than guessing that it equals the desktop ID. PandaBert checks the standard Claude session folder and up to 64 Parall profile folders, including independently stored second-account metadata. It recognizes recorded current, pre-clear, unarchived and prior CLI IDs. UUID-named Claude transcripts use their filename identity, so copied parent history cannot merge a fork with its parent or supply its bridge link. The mapping is loaded again on click so a cached or pinned task cannot open a removed mapping. Ambiguous mappings are discarded. Bridge IDs alone never enable navigation: a syntactically valid bridge ID does not prove that its conversation exists in the desktop app. Remote Claude navigation is disabled as well.

Only validated identifiers enter the fixed URL templates. No prompt, command, filesystem path or arbitrary query string is forwarded. The matching app bundle is selected explicitly; missing-app errors are surfaced. Claude records with `entrypoint: cli` identify terminal sessions; `claude-desktop` identifies desktop sessions. Bridge IDs alone do not identify either origin. Unlinked terminal sessions have a noninteractive label and an explanation in Details; unknown or desktop origins keep the unavailable button. An explicit local desktop mapping takes precedence and remains clickable.

The destination app must be signed in to an account with access to the thread. PandaBert cannot verify that access through the operating system's URL-opening acknowledgement. A local metadata record establishes identity, not current account authorization; the destination app still owns that access check. Remote Codex routing is unavailable until PandaBert machine identities are mapped to Codex's own connected hosts. Unlinked Claude terminal sessions are not imported or resumed automatically.

Optional identity fields preserve decoding of existing PandaBert snapshots and pinned-task caches. The collector protocol version remains 1; old consumers ignore these additional JSON fields.

## Validation

The full suite passes: **58 tests, 0 failures**. Navigation coverage includes exact URLs, local/remote boundaries, malformed-ID rejection, bridge-only rejection, terminal non-import behavior, old snapshot compatibility, CLI-to-desktop mapping, deleted/changed mappings at click time ambiguous metadata across accounts, Parall folder discovery, prior CLI IDs and separate fork identity.

The release app and embedded collector were rebuilt and locally signature-verified. Live navigation results are recorded in `VALIDATION.md`.

## Terminal focus attempt — 0.3.1

The computer-control tool denied access to macOS Terminal, so focusing the user's existing tab could not be tested. No alternate UI-control mechanism was used. This is a verification limitation, not evidence that terminal integration is impossible. The fallback does not activate a generic terminal window, import a conversation or start another session. Explicit entrypoint metadata was verified in local Claude transcripts, including a CLI record that also had a bridge ID.

## Seen on open — 0.4.2

**Mark as seen** is an explicit bordered button in task cards and Details. It acknowledges only that completed response; the background status reads **Seen**. Opening a finished thread performs the same acknowledgement after the operating system reports a successful app handoff. Missing links, failed app opens, active turns and unanswered questions are not acknowledged. A delayed callback cannot acknowledge a newer completion or replace its existing seen marker. Pins are retained, and new completions can need attention again. Independent GitHub failures/change requests still need attention.

The acknowledgement means the link was handed to the app, not that PandaBert verified the destination screen or that a human read the response. Provider account-access errors occurring inside the destination app are not reported by macOS. PandaBert neither reviews nor approves a GitHub pull request.

## Rubber-band dismissal — 0.4.3

Acknowledged cards leave Needs you with a 0.3-second rubber-band motion: a short pull right (90 ms), then a fast stretch and snap left (210 ms) while fading. Remaining cards wait 80 ms before settling upward with a spring. The same acknowledgement path handles Mark as seen and a successful Open thread handoff. Details closes when its current completion becomes seen. The empty state stays transparent until the last card is 80% outside its original position, accounting for its stretched trailing edge, then fades in along the same motion curve. Exiting content stays above the replacement content. Reduce Motion uses a brief stationary fade. Pinned tasks remain pinned, and failed opens, questions and independent GitHub attention retain their existing behavior.

## Pins and kept cards — 0.4.4

Pin changes and pinned acknowledgements use a brief press-in animation without an exit. The card list preserves each card's identity when it moves into the pinned group. Unpinning retains its position in a Kept in sight group, even if the response was already seen; that order survives relaunches and observation outages. Only a later Mark as seen or successful Open thread acknowledgement releases the unpinned card. Failed opens and delayed callbacks for older completions do not release it. Pinned cards stay pinned after either action. Existing attention rules for questions and independent GitHub alerts remain unchanged. Reduced Motion disables the press movement.
