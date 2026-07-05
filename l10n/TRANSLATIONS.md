# Localization & Translation Guide

CropGuard AI ships English (`app_en.arb`) as the source of truth and supports
three Ghanaian languages: **Twi/Akan (`tw`)**, **Ewe (`ee`)** and **Dagbani
(`dag`)**.

## Current status

`app_tw.arb`, `app_ee.arb` and `app_dag.arb` are **scaffolds**. They contain
only `@@locale`, so every string currently falls back to English at runtime.
The language picker (Settings → Language) already works and will show real
translations as soon as keys are added to these files.

## ⚠️ Do not machine-translate

This app gives **crop-disease and treatment advice to farmers**. A mistranslated
dosage, chemical name, or instruction can cause crop loss or harm. Translations
**must** be done (or reviewed) by a qualified speaker, ideally one with
agricultural/extension background. Do not auto-generate these with an LLM or
machine translator.

## How to add translations

1. Open `l10n/app_en.arb` — each key has a value and (optionally) an `@key`
   metadata block with a `description` and `placeholders`.
2. In the target file (e.g. `app_tw.arb`), add the same key with the translated
   value. You only need keys you have translated — missing keys fall back to
   English automatically.
3. Preserve ICU placeholders exactly, e.g.
   `"scanCount": "{count} mfonini"` keeps `{count}`.
4. Regenerate the Dart bindings:
   ```bash
   flutter gen-l10n
   ```
5. Run the app, switch language in Settings, and verify on-device.

## Priority order for translation

1. Onboarding + scan flow (Scanner, Analysing, Result, Low-confidence)
2. Home dashboard + navigation labels
3. Treatment tracker + disease library (highest agronomic-accuracy bar)
4. Settings, Profile, Community, Legal

## Audio (TTS)

`GhanaNlpService` already synthesizes Twi/Ewe/Dagbani speech. Once on-screen
strings are translated, wire the result/treatment screens' "listen" actions to
read the localized string rather than the English one.
