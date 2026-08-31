# Khaya AI API Contract
# CropGuard AI — Single Source of Truth for Language Service Integration

**Provider:** Khaya AI (GhanaNLP)  
**Developer Portal:** https://developer.khaya.ai/  
**Base URL:** `https://translation-api.ghananlp.org`  
**Authentication:** `Ocp-Apim-Subscription-Key` header (Azure API Management)  
**Managed via:** Azure API Management  

> [!IMPORTANT]
> This document is the authoritative contract for CropGuard's Khaya AI integration.
> Any change to an endpoint, version, field name, or language code MUST be reflected here
> AND in `khaya_api_contract.json` before code is changed.

---

## Verification Status

| API | Version | Status | Date Verified |
|-----|---------|--------|---------------|
| ASR | v3 | VERIFIED (portal-confirmed, v1/v2 deprecated) | 2026-08-31 |
| TTS | v2 | VERIFIED (portal-confirmed, v1 deprecated) | 2026-08-31 |
| Translation | v2 | VERIFIED (portal-confirmed, v1 deprecated) | 2026-08-31 |

> [!NOTE]
> Verification source: Khaya AI developer portal (developer.khaya.ai) confirms ASR v3,
> TTS v2, Translation v2 as the current production APIs. v1 APIs (ASR v1, ASR v2, TTS v1,
> Translation v1) are deprecated. The developer portal uses Azure API Management and
> requires authentication to view full OpenAPI specs. Fields marked UNVERIFIED require
> account-authenticated portal access to confirm.

---

## 1. Automatic Speech Recognition — ASR v3

### Overview
Transcribes spoken Ghanaian/African language audio into text.
Supports long-form audio with optional segment-level timing.

> [!IMPORTANT]
> **ASR v1 and ASR v2 are DEPRECATED and MUST NOT be used in production.**

### Endpoint

| Field | Value |
|-------|-------|
| Version | v3 |
| Base URL | `https://translation-api.ghananlp.org` |
| Endpoint | `/asr/v3/transcribe` |
| HTTP Method | POST |

### Authentication

| Field | Value |
|-------|-------|
| Header name | `Ocp-Apim-Subscription-Key` |
| Credential type | Subscription key (Azure APIM) |
| Credential location | Server-side only (Firebase Secret Manager) |

### Request

| Field | Value |
|-------|-------|
| Content-Type | `audio/wav` |
| Body | Raw WAV audio bytes |
| Query param | `?language=<code>` |
| Audio format | WAV (PCM) |
| Sample rate | 16000 Hz (16 kHz) |
| Channels | Mono (1 channel) |
| Max duration | UNVERIFIED — validate against portal |
| Max payload | UNVERIFIED — validate against portal |

**Full request example:**
```
POST https://translation-api.ghananlp.org/asr/v3/transcribe?language=tw
Content-Type: audio/wav
Ocp-Apim-Subscription-Key: <key>

<raw WAV bytes>
```

### Response

| Field | Value |
|-------|-------|
| Content-Type | `application/json` or plain text |
| Transcript field | `text` (in JSON) or raw string |
| Confidence | NOT PROVIDED by provider — do not invent |

**Response handling (observed from existing code):**
- May return plain string `"transcription text"`
- May return JSON `{"text": "transcription text"}`
- Both cases must be handled

### Error Responses

| HTTP Status | Domain Error | Condition |
|-------------|-------------|-----------|
| 400 | InvalidAudio | Bad audio format or empty body |
| 401 | AuthenticationFailure | Missing/invalid subscription key |
| 403 | AuthenticationFailure | Key lacks permission |
| 429 | RateLimitExceeded | Quota exceeded |
| 500 | ProviderServerError | Provider internal error |
| 503 | ProviderUnavailable | Provider offline |
| TIMEOUT | RequestTimeout | No response within configured limit |

### Language Support (ASR v3)

| Language | Provider Code | Supported |
|----------|--------------|-----------|
| Twi (Akan) | `tw` | YES |
| Ewe | `ee` | YES |
| Dagbani | `dag` | YES |
| Ga | `gaa` | UNVERIFIED |
| Fante | `fat` | UNVERIFIED |
| English | `en` | UNVERIFIED |

---

## 2. Text-To-Speech — TTS v2

### Overview
Synthesizes written Ghanaian language text into natural-sounding audio.
Supports 32+ African languages and dialects.

> [!IMPORTANT]
> **TTS v1 is DEPRECATED and MUST NOT be used in production.**

### Endpoint

| Field | Value |
|-------|-------|
| Version | v2 |
| Base URL | `https://translation-api.ghananlp.org` |
| Endpoint | `/tts/v2/synthesize` |
| HTTP Method | POST |

### Authentication

| Field | Value |
|-------|-------|
| Header name | `Ocp-Apim-Subscription-Key` |
| Credential type | Subscription key (Azure APIM) |
| Credential location | Server-side only (Firebase Secret Manager) |

### Request

| Field | Value |
|-------|-------|
| Content-Type | `application/json` |
| Required fields | `text`, `language` |
| Optional fields | `speaker_id` (voice selection) |
| Max text length | 2000 characters (enforced by CropGuard backend) |

**Request body:**
```json
{
  "text": "Text to synthesize",
  "language": "tw",
  "speaker_id": "twi_speaker_4"
}
```

### Response

| Field | Value |
|-------|-------|
| Content-Type | `audio/wav` or binary |
| Body | Raw audio bytes (WAV format) |

### Voice / Speaker IDs (TTS v2)

| Language | Provider Code | Speaker ID | Notes |
|----------|--------------|------------|-------|
| Twi | `tw` | `twi_speaker_4` | Verified in existing impl |
| Ewe | `ee` | `ewe_speaker_1` | Verified in existing impl |
| Dagbani | `dag` | `dagbani_speaker_1` | Verified in existing impl |
| Ga | `gaa` | UNVERIFIED | Query portal for speaker_id |
| Fante | `fat` | UNVERIFIED | Query portal for speaker_id |

### Error Responses

| HTTP Status | Domain Error | Condition |
|-------------|-------------|-----------|
| 400 | InvalidText | Empty text or malformed body |
| 401 | AuthenticationFailure | Missing/invalid subscription key |
| 403 | AuthenticationFailure | Key lacks permission |
| 413 | PayloadTooLarge | Text exceeds provider limit |
| 429 | RateLimitExceeded | Quota exceeded |
| 500 | ProviderServerError | Provider internal error |
| 503 | ProviderUnavailable | Provider offline |

---

## 3. Translation — Translation v2

### Overview
Translates text between English and 10+ Ghanaian languages.

> [!IMPORTANT]
> **Translation v1 is DEPRECATED and MUST NOT be used in production.**

### Endpoint

| Field | Value |
|-------|-------|
| Version | v2 |
| Base URL | `https://translation-api.ghananlp.org` |
| Endpoint | `/translate` (v2 routing handled by APIM subscription) |
| HTTP Method | POST |

> [!NOTE]
> The Khaya portal homepage example shows `POST /translate` with body `{"in": "...", "lang": "en-tw"}`.
> The v2 endpoint path via the Azure APIM subscription is UNVERIFIED at account level.
> The current CropGuard implementation does NOT use a Translation endpoint.
> This section documents the contract for future implementation.

### Authentication

| Field | Value |
|-------|-------|
| Header name | `Ocp-Apim-Subscription-Key` |
| Credential type | Subscription key (Azure APIM) |
| Credential location | Server-side only (Firebase Secret Manager) |

### Request

| Field | Value |
|-------|-------|
| Content-Type | `application/json` |
| Input text field | `in` |
| Language pair field | `lang` |
| Language pair format | `<source>-<target>` (e.g., `en-tw`) |

**Request body:**
```json
{
  "in": "Text to translate",
  "lang": "en-tw"
}
```

### Supported Language Pairs (Translation v2)

| Pair | Source | Target | Direction |
|------|--------|--------|-----------|
| `en-tw` | English | Twi | Forward |
| `tw-en` | Twi | English | Reverse |
| `en-ee` | English | Ewe | Forward |
| `ee-en` | Ewe | English | Reverse |
| `en-dag` | English | Dagbani | Forward |
| `dag-en` | Dagbani | English | Reverse |
| `en-gaa` | English | Ga | UNVERIFIED |
| `en-fat` | English | Fante | UNVERIFIED |

### Response

| Field | Value |
|-------|-------|
| Content-Type | `application/json` |
| Translation field | UNVERIFIED — query portal for exact field name |

### Error Responses

| HTTP Status | Domain Error | Condition |
|-------------|-------------|-----------|
| 400 | InvalidText | Empty text or invalid language pair |
| 401 | AuthenticationFailure | Missing/invalid subscription key |
| 403 | AuthenticationFailure | Key lacks permission |
| 429 | RateLimitExceeded | Quota exceeded |
| 500 | ProviderServerError | Provider internal error |

---

## 4. Deprecated APIs — DO NOT USE

The following API versions MUST NOT be used in any production or active development code:

| API | Deprecated Version | Replacement |
|-----|-------------------|-------------|
| ASR | v1 | ASR v3 |
| ASR | v2 | ASR v3 |
| TTS | v1 | TTS v2 |
| Translation | v1 | Translation v2 |

If any of these appear in active code, they must be migrated immediately.

---

## 5. Language Code Mapping — CropGuard to Khaya

| CropGuard Locale | Display Name | Khaya ASR Code | Khaya TTS Code | Translation Pair (to EN) | ASR | TTS | Translation |
|-----------------|--------------|----------------|----------------|--------------------------|-----|-----|-------------|
| `tw` | Twi | `tw` | `tw` | `tw-en` / `en-tw` | YES | YES | YES |
| `ee` | Ewe | `ee` | `ee` | `ee-en` / `en-ee` | YES | YES | YES |
| `dag` | Dagbani | `dag` | `dag` | `dag-en` / `en-dag` | YES | YES | YES |
| `en` | English | `en` | N/A | N/A | UNVERIFIED | N/A (local TTS) | N/A |
| `gaa` | Ga | `gaa` | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED |
| `fat` | Fante | `fat` | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED |

---

## 6. Offline Behavior Contract

| Service | Online | Offline |
|---------|--------|---------|
| ASR | Proxied via Firebase Function → Khaya ASR v3 | Show error: "Voice input requires an internet connection." Never fabricate transcript. |
| TTS | Proxied via Firebase Function → Khaya TTS v2, then `flutter_tts` fallback | Fall back to `flutter_tts` local engine for supported locales only. Log when falling back. |
| Translation | Firebase Function → Khaya Translation v2 (future) | Retain original text. Never display original as translated. |

---

## 7. Security Contract

- Subscription key MUST be stored in Firebase Secret Manager on the server side only
- Flutter client MUST NOT contain the subscription key
- Firebase Functions act as the authenticated proxy
- All requests MUST use HTTPS
- Subscription key MUST NOT appear in logs at any level

---

## 8. UNVERIFIED Items Requiring Portal Access

The following items require authenticated access to developer.khaya.ai to verify:

1. Exact ASR v3 endpoint path (assumed `/asr/v3/transcribe` — same pattern as v2 which was `/asr/v2/transcribe`)
2. Exact TTS v2 endpoint path (assumed `/tts/v2/synthesize` — same pattern as v1 which was `/tts/v1/synthesize`)
3. Exact Translation v2 endpoint path (assumed `/translate` based on portal homepage example)
4. Maximum audio duration/payload for ASR v3
5. Speaker IDs for Ga (`gaa`) and Fante (`fat`) in TTS v2
6. Translation response field name (the field containing the translated text)
7. Full list of supported language codes per API version
8. Rate limits and quotas per subscription tier

**Until these are verified from the portal, the implementation uses best-available information
from public search, the portal homepage, and the existing working v1/v2 implementation patterns.**
