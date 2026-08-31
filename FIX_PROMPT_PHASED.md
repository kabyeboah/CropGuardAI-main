# CropGuard AI — Phased Fix Prompt (hand this whole file to your agent)

You are working in the CropGuard AI Flutter repo. [CURRENT] `CROPGUARD_MASTER_AUDIT.md` [CURRENT]
in the repo root is the current source of truth for known issues — read it [CURRENT]
first. [CURRENT] **Do not trust its "FIXED [SELF-REPORTED]" tags at face value; three [CURRENT]
previously were wrong.** Everything you do in this session must be [HISTORICAL]
`[RE-VERIFIED]`. [CURRENT]

## Phase 0 — Ground rules (apply to every phase below)

1. [CURRENT] **Tag every claim.** After each change, state whether it is: [CURRENT]
   - `BINARY-VERIFIED` — you ran a command (`flutter analyze`, `flutter test`,
a script) and are pasting its actual output. [CURRENT]
   - `CODE-TRACED` — you read the code path end-to-end and are describing
what it does, with file:line references. [CURRENT]
   - `UNVERIFIED` — you believe it's true but haven't checked. Never mark a
fix "done" on this tag alone. [CURRENT]
2. [CURRENT] **Never mark an item FIXED without either `BINARY-VERIFIED` or [CURRENT]
`CODE-TRACED` evidence pasted into your response.** "I updated the file so [CURRENT]
it should work now" is not evidence. [CURRENT]
3. [CURRENT] **Run `flutter analyze && flutter test` after every phase**, not just at [CURRENT]
the end. [CURRENT] Paste the real output. [CURRENT] If you cannot run Flutter in your [CURRENT]
environment, say so explicitly instead of guessing at the result. [CURRENT]
4. [CURRENT] **Do not touch model files, model input dimensions, or normalization [CURRENT]
logic** (`crop_disease_classifier.dart`'s 128×128 raw `[0,255]` contract) [CURRENT]
in any phase below — that's covered separately, don't "helpfully" change [CURRENT]
it while working on something else. [CURRENT]
5. [CURRENT] **One phase per commit/PR.** Don't bundle phases — if Phase 3 breaks [CURRENT]
something, we need to be able to revert it without losing Phase 1 and 2. [CURRENT]
6. [CURRENT] At the end of each phase, update `CROPGUARD_MASTER_AUDIT.md` yourself with [CURRENT]
the corrected status and your evidence tag — don't leave that for later. [CURRENT]

---

## Phase 1 — Crash-risk fixes (do this first, it's small and it's what blocks any demo)

**Goal**: fix the two items independently confirmed still-open, plus the one
confirmed half-open, in `CROPGUARD_MASTER_AUDIT.md`. [CURRENT]

1. [CURRENT] **Missing microphone permissions** (audit #46): [CURRENT]
   - Add to `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.RECORD_AUDIO"/>
     ```
   - Add to `ios/Runner/Info.plist`:
     ```xml
     <key>NSMicrophoneUsageDescription</key>
     <string>CropGuard AI uses the microphone for voice dictation in Twi.</string>
     <key>NSSpeechRecognitionUsageDescription</key>
     <string>CropGuard AI uses speech recognition for transcribing farm notes.</string>
     ```
   - Verify: grep both files to confirm the keys exist; if you have a device/
emulator, actually open the voice dictation button [CURRENT]
(`voice_dictation_button.dart`) and confirm no crash/exception. [CURRENT]

2. [CURRENT] **Silent lockup on empty camera list** (audit #48), in [CURRENT]
`lib/presentation/screens/scanner/scanner_provider.dart`, `initCamera()`: [CURRENT]
   - Current code is `if (cameras.isEmpty) return;` with no error state set.
   - Replace with a branch that sets an error message/code (use the existing
`UiMessage`/error-state pattern already used elsewhere in this provider [CURRENT]
— don't invent a new one) and calls `notifyListeners()`, so the UI shows [CURRENT]
an error + retry instead of hanging. [CURRENT]
   - Verify: `CODE-TRACED` isn't enough here since this is UI state — either
run the widget test suite or manually force `availableCameras()` to [CURRENT]
return `[]` and confirm the screen shows an error instead of a stuck [CURRENT]
loading state. [CURRENT]

3. [CURRENT] **Remaining silent catch in `MySubmissionsScreen`** (audit #49, half-done): [CURRENT]
   - The main fetch already sets `fetchError` correctly — leave that alone.
   - The nested offline-queue read (`PendingSyncQueue.getPendingItems`) is
still `catch (_) {}`. [CURRENT] Decide: either surface a secondary non-blocking [CURRENT]
error indicator, or explicitly comment *why* this one is intentionally [CURRENT]
silent (e.g. [CURRENT] "queued items are best-effort display, main list still [CURRENT]
loads") if you decide it's genuinely lower-stakes than the primary [CURRENT]
fetch. [CURRENT] Don't leave it silent with no explanation either way. [CURRENT]

**Phase 1 acceptance**: `flutter analyze` clean, `flutter test` green, and
you've pasted grep/test output proving all three, not just a description. [CURRENT]

---

## Phase 2 — Wire the accuracy floor into CI (audit #56)

**Goal**: stop `docs/MODEL_ACCURACY.md`'s 70% release floor from being
documentation-only. [CURRENT]

1. [CURRENT] Look at `.github/workflows/flutter.yml` and `tools/evaluate_model.py`. [CURRENT]
2. [CURRENT] Add a CI step (or a separate workflow, your call) that runs [CURRENT]
`evaluate_model.py` against a committed or CI-provided test set and fails [CURRENT]
the build if top-1 accuracy is below 70%, matching the floor already [CURRENT]
defined in `docs/MODEL_ACCURACY.md`. [CURRENT]
3. [CURRENT] If there's no test set available to CI yet (see Phase 4), don't fake one [CURRENT]
— instead add the CI step as a no-op-with-warning ("no test set found, [CURRENT]
skipping accuracy gate") so the wiring exists and activates the moment a [CURRENT]
real test set lands, rather than silently pretending to gate something it [CURRENT]
isn't gating. [CURRENT]

**Phase 2 acceptance**: paste the CI YAML diff and, if possible, a CI run
link or log showing the step executing (even if it warns/skips due to no [CURRENT]
test set yet). [CURRENT]

---

## Phase 3 — Real out-of-distribution detection (audit #5)

**Goal**: replace or supplement the color-heuristic OOD pre-filter with
something closer to `docs`'s originally-designed embedding-distance approach, [CURRENT]
OR — if time doesn't allow a real model this pass — make the limitation [CURRENT]
loud instead of quiet. [CURRENT]

Pick one: [CURRENT]
- **(a) Minimal real fix**: train/attach a small binary leaf/non-leaf
classifier (or Mahalanobis distance on the MobileNetV2 penultimate-layer [CURRENT]
embedding, per the original design intent referenced in [CURRENT]
`CROPGUARD_MASTER_AUDIT.md`) and wire it into `OODGate` in place of [CURRENT]
`AlwaysAcceptOODGate`. [CURRENT]
- **(b) Honest scoping**: if (a) isn't feasible this pass, leave
`AlwaysAcceptOODGate` + the color heuristic as-is, but add a clear inline [CURRENT]
comment and a user-facing note (e.g. [CURRENT] in the result screen's low-confidence [CURRENT]
path) that non-plant images can produce a confident-looking wrong [CURRENT]
diagnosis. [CURRENT] Don't silently leave the gap — document it where a user or [CURRENT]
reviewer will actually see it. [PLANNED]

**Phase 3 acceptance**: state which option you took and why, with
`CODE-TRACED` evidence of what `OODGate.isPlantBytes()` actually does now. [CURRENT]

---

## Phase 4 — Real field accuracy number (audit #4 — the actual release blocker)

**Goal**: get one real, defensible accuracy number instead of the 63.9%
train/val figure. [CURRENT]

1. [CURRENT] Assemble a held-out test set per `docs/MODEL_ACCURACY.md` §4 (15-20+ [CURRENT]
images/class minimum, real field conditions — natural lighting, varied [CURRENT]
phone cameras, natural backgrounds, zero overlap with training data). [CURRENT]
2. [CURRENT] Run `tools/evaluate_model.py` against it. [CURRENT]
3. [CURRENT] Fill in the real results table in `docs/MODEL_ACCURACY.md` §6, replacing [CURRENT]
the "*Pending Retrain*" placeholders — with the actual numbers, not [HISTORICAL]
another placeholder. [HISTORICAL]
4. [CURRENT] If the number comes back below 70%: don't quietly ship it. [CURRENT] Report it [CURRENT]
plainly and flag to the project owner (this is a decision point, not [CURRENT]
something to fix silently by changing the threshold). [HISTORICAL]

**Phase 4 acceptance**: paste the actual `evaluate_model.py` output.

---

## Phase 5 — Re-verify the ~50 self-reported fixes

**Goal**: close the trust gap. `CROPGUARD_MASTER_AUDIT.md` has ~50 items
still tagged `[SELF-REPORTED]` from prior sessions. [CURRENT] Given 2 of the last 4 [CURRENT]
spot-checked came back wrong, don't assume the rest are fine. [CURRENT]

1. [CURRENT] Go through the fix catalog in `CROPGUARD_MASTER_AUDIT.md` in order. [CURRENT]
2. [CURRENT] For each item, open the referenced file(s) and confirm the described fix [CURRENT]
is actually present in the current code — same method used to catch #46 [CURRENT]
and #48 (read the actual current source, don't trust the doc's own [CURRENT]
"Evidence" block, which may itself be stale). [CURRENT]
3. [CURRENT] Update each row's tag to `[RE-VERIFIED]` with a one-line confirmation, or [CURRENT]
flag it as another false positive if it doesn't hold up. [HISTORICAL]
4. [CURRENT] Budget: this is ~50 quick checks, not 50 deep investigations — most [CURRENT]
should take under a minute each if you go straight to the referenced [CURRENT]
file:line. [CURRENT]

**Phase 5 acceptance**: an updated fix table where every row says
`[RE-VERIFIED]` instead of `[SELF-REPORTED]`, plus a short list of any new [CURRENT]
false positives found. [CURRENT]

---

## Phase 6 — Tech debt cleanup (audit #58, low priority)

**Goal**: work down the 67 TODO/FIXME/placeholder markers across 12 files in
`lib/`. [CURRENT] None are in auth/payment/security paths, so this is cleanup, not [CURRENT]
urgent. [CURRENT]

1. [CURRENT] `grep -rniE "TODO|FIXME|placeholder" lib --include=*.dart` to get the [PLANNED]
current list. [CURRENT]
2. [CURRENT] Triage into: fix now (trivial), file as a tracked issue (needs design [CURRENT]
work), or delete (stale comment, no longer relevant). [CURRENT]
3. [CURRENT] Don't do a mass find-and-remove — read each one; some may be load-bearing [CURRENT]
notes about intentional simplifications (like the `OODGate` placeholder [HISTORICAL]
comment, which should stay until Phase 3 replaces it). [CURRENT]

**Phase 6 acceptance**: before/after count of TODO markers, with a one-line
disposition for each one removed. [DEPRECATED]

---

## What "done" looks like

All six phases complete, `CROPGUARD_MASTER_AUDIT.md` fully `[RE-VERIFIED]` [CURRENT]
with no open corrections outstanding, `flutter analyze`/`flutter test` [CURRENT]
passing with pasted real output, and a real (not placeholder) number in [HISTORICAL]
`docs/MODEL_ACCURACY.md`. [CURRENT] That combination — not any individual phase — is [CURRENT]
what would make this genuinely production-ready rather than demo-ready. [CURRENT]
