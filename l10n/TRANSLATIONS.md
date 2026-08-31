# Localization & Translation Guide

CropGuard AI ships English (`app_en.arb`) as the source of truth and supports [CURRENT]
three Ghanaian languages: **Twi/Akan (`tw`)**, **Ewe (`ee`)** and **Dagbani [CURRENT]
(`dag`)**. [CURRENT]

## Current status

`app_tw.arb`, `app_ee.arb` and `app_dag.arb` are **scaffolds**. [HISTORICAL] They contain [CURRENT]
only `@@locale`, so every string currently falls back to English at runtime. [CURRENT]
The language picker (Settings → Language) already works and will show real [PLANNED]
translations as soon as keys are added to these files. [CURRENT]

## ⚠️ Do not machine-translate

This app gives **crop-disease and treatment advice to farmers**. [CURRENT] A mistranslated [CURRENT]
dosage, chemical name, or instruction can cause crop loss or harm. [CURRENT] Translations [CURRENT]
**must** be done (or reviewed) by a qualified speaker, ideally one with
agricultural/extension background. [CURRENT] Do not auto-generate these with an LLM or [CURRENT]
machine translator. [CURRENT]

## How to add translations

1. [CURRENT] Open `l10n/app_en.arb` — each key has a value and (optionally) an `@key` [CURRENT]
metadata block with a `description` and `placeholders`. [HISTORICAL]
2. [CURRENT] In the target file (e.g. [CURRENT] `app_tw.arb`), add the same key with the translated [CURRENT]
value. [CURRENT] You only need keys you have translated — missing keys fall back to [CURRENT]
English automatically. [CURRENT]
3. [CURRENT] Preserve ICU placeholders exactly, e.g. [HISTORICAL]
`"scanCount": "{count} mfonini"` keeps `{count}`. [CURRENT]
4. [CURRENT] Regenerate the Dart bindings: [CURRENT]
   ```bash
   flutter gen-l10n
   ```
5. [CURRENT] Run the app, switch language in Settings, and verify on-device. [CURRENT]

## Priority order for translation

1. [CURRENT] Onboarding + scan flow (Scanner, Analysing, Result, Low-confidence) [CURRENT]
2. [CURRENT] Home dashboard + navigation labels [CURRENT]
3. [CURRENT] Treatment tracker + disease library (highest agronomic-accuracy bar) [CURRENT]
4. [CURRENT] Settings, Profile, Community, Legal [CURRENT]

## Audio (TTS)

`GhanaNlpService` already synthesizes Twi/Ewe/Dagbani speech. [CURRENT] Once on-screen [CURRENT]
strings are translated, wire the result/treatment screens' "listen" actions to [CURRENT]
read the localized string rather than the English one. [CURRENT]
