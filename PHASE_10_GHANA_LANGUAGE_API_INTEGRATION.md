# CropGuard AI — Ghanaian Language API Integration & Production Configuration

> **Execution Order:** Phase 0 baseline → ML phases → platform/build phases →
> backend/security → **this phase** → full integration testing → documentation
> finalization.
>
> This phase is split into two sub-phases:
> - **Phase 9A** — Khaya AI API Contract Definition *(mandatory prerequisite)*
> - **Phase 10** — Ghana Language API Integration & Production Configuration

---

# PHASE 9A — KHAYA AI API CONTRACT DEFINITION
## MANDATORY BEFORE IMPLEMENTATION

You MUST NOT modify the CropGuard language-service implementation until the
current Khaya AI API contracts have been verified from the official Khaya AI
developer portal/documentation.

**AUTHORITATIVE SOURCE:**

```
https://developer.khaya.ai/
```

The application must use:

```
ASR:         Automatic Speech Recognition API - v3
TTS:         Text-To-Speech API - v2
Translation: Translation API - v2
```

**DO NOT use:**

```
ASR v1
TTS v1
Translation v1
```

---

## 9A.1 — CREATE AN API CONTRACT DOCUMENT

Create:

```
docs/api/KHAYA_API_CONTRACT.md
```

This document becomes the **single source of truth** for CropGuard\'s Khaya
integration.

For EACH API, document all of the following:

---

### ASR v3

Record:

- Official product name
- API version
- Base URL
- Exact endpoint
- HTTP method
- Authentication mechanism
- Required headers
- Optional headers
- Request Content-Type
- Request body schema
- Audio format requirements
- Supported sample rates
- Channel requirements
- Maximum payload/duration if specified
- Required language parameter
- Valid language codes
- Response Content-Type
- Response body schema
- Transcript field
- Confidence field, if actually supplied
- Error response schema
- HTTP status codes
- Rate limits
- Timeout expectations
- Provider documentation URL
- Date verified

---

### TTS v2

Record:

- Official product name
- API version
- Base URL
- Exact endpoint
- HTTP method
- Authentication mechanism
- Required headers
- Request Content-Type
- Request body schema
- Required text field
- Language parameter
- Voice parameter(s)
- Supported voices
- Supported audio formats
- Response Content-Type
- Response body/binary format
- Error response schema
- HTTP status codes
- Rate limits
- Timeout expectations
- Provider documentation URL
- Date verified

---

### Translation v2

Record:

- Official product name
- API version
- Base URL
- Exact endpoint
- HTTP method
- Authentication mechanism
- Required headers
- Request Content-Type
- Request body schema
- Text field
- Source language parameter
- Target language parameter
- Supported language codes
- Response body schema
- Translation result field
- Error response schema
- HTTP status codes
- Rate limits
- Timeout expectations
- Provider documentation URL
- Date verified

---

## 9A.2 — DO NOT GUESS ANY API FIELD

**NEVER** infer an endpoint or parameter merely from:

- an old CropGuard implementation
- a third-party Dart package
- internet examples
- a deprecated API
- the API product name
- assumptions about REST conventions

Every endpoint and request/response field **MUST** be verified against current
official Khaya documentation.

If an item cannot be verified, write:

```
UNVERIFIED
```

and **do not implement it yet.**

---

## 9A.3 — CREATE MACHINE-READABLE API DEFINITIONS

Create:

```
docs/api/khaya_api_contract.json
```

Populate ONLY values verified from the provider:

```json
{
  "provider": "Khaya AI",
  "verifiedAt": "...",
  "apis": {
    "asr": {
      "version": "v3",
      "baseUrl": "...",
      "endpoint": "...",
      "method": "...",
      "authentication": "...",
      "request": {},
      "response": {},
      "errors": {}
    },
    "tts": {
      "version": "v2",
      "baseUrl": "...",
      "endpoint": "...",
      "method": "...",
      "authentication": "...",
      "request": {},
      "response": {},
      "errors": {}
    },
    "translation": {
      "version": "v2",
      "baseUrl": "...",
      "endpoint": "...",
      "method": "...",
      "authentication": "...",
      "request": {},
      "response": {},
      "errors": {}
    }
  }
}
```

---

## 9A.4 — CREATE FLUTTER DOMAIN CONTRACTS

The provider API schema **MUST NOT** leak directly into the UI.

Create or reuse interfaces such as:

```
SpeechRecognitionService
TextToSpeechService
TranslationService
```

The domain layer must use stable CropGuard models:

```
SpeechRecognitionResult
  - transcript
  - language
  - provider metadata only where meaningful

TextToSpeechResult
  - audio bytes/reference
  - language
  - format
  - duration where available

TranslationResult
  - originalText
  - translatedText
  - sourceLanguage
  - targetLanguage
```

Do **NOT** invent confidence values or metadata that the provider does not
actually return.

---

## 9A.5 — CREATE PROVIDER DTOs SEPARATE FROM DOMAIN MODELS

Use provider-specific DTOs:

```
KhayaAsrRequest         ->  KhayaAsrResponse
KhayaTtsRequest         ->  KhayaTtsResponse
KhayaTranslationRequest ->  KhayaTranslationResponse
```

Then map:

```
Provider DTO
    |
    v
CropGuard Domain Model
```

This allows the provider contract to change without contaminating the entire
Flutter application.

---

## 9A.6 — LANGUAGE CODE CONTRACT

Create one authoritative mapping:

```
CropGuard locale -> Khaya provider language code
```

For every language, record:

| Field                 | Value |
|-----------------------|-------|
| Display name          |       |
| CropGuard locale      |       |
| Provider code         |       |
| ASR supported         |       |
| TTS supported         |       |
| Translation supported |       |

**DO NOT assume** that `en`, `tw`, `ee`, `dag` are correct provider codes
without verification. Use the **exact** provider-defined values.

> Khaya\'s public pages advertise 32-language ASR/TTS coverage including Twi,
> Ewe, Ga, Fante, and Dagbani — but the exact API parameter codes must still
> come from the official API contract documentation. Do not infer them.

---

## 9A.7 — AUTHENTICATION CONTRACT

Document exactly how authentication works. **Do NOT commit credentials.**

Specify:

- Header name
- Credential type
- Where credential is stored
- Which side of the architecture holds the credential
- Rotation procedure

**Preferred production architecture:**

```
Flutter
  |  authenticated request
  v
CropGuard backend (Firebase Function / Cloud Run)
  |  provider credential
  v
Khaya AI
```

If direct client access is retained, document and justify it explicitly, and
ensure the provider credential is appropriate for client exposure.

---

## 9A.8 — HTTP ERROR CONTRACT

Map provider responses into CropGuard domain errors. Only map statuses that
are actually documented by the provider:

| HTTP Status | Domain Error               |
|-------------|----------------------------|
| 400         | InvalidLanguageRequest     |
| 401         | AuthenticationFailure      |
| 403         | AuthenticationFailure      |
| 404         | (document if applicable)   |
| 408         | ProviderTimeout            |
| 413         | PayloadTooLarge            |
| 415         | InvalidAudio / InvalidText |
| 422         | MalformedProviderResponse  |
| 429         | RateLimitExceeded          |
| 500         | ProviderUnavailable        |
| 502         | ProviderUnavailable        |
| 503         | ProviderUnavailable        |
| 504         | ProviderTimeout            |

**Never** expose raw provider responses to users.

---

## 9A.9 — REQUEST VALIDATION

Before sending requests, validate locally:

**ASR:**
- Audio exists
- Valid format
- Valid duration
- Valid language
- Valid payload size

**TTS:**
- Text is non-empty
- Text length is within provider limits
- Language is supported

**Translation:**
- Text is non-empty
- Source language is valid
- Target language is valid
- Source != target when required by API

Reject invalid requests locally before any network call.

---

## 9A.10 — RESPONSE VALIDATION

Every provider response must be validated. Never assume `response != null`
means `response is valid`. Validate:

- HTTP status
- Content-Type
- Required fields
- Field types
- Encoding
- Payload length
- Audio validity

If validation fails: return a controlled domain error. Never crash.

---

## 9A.11 — API VERSION REGRESSION TEST

Add an automated test/static check that **fails** when production code
references:

```
ASR v1
TTS v1
Translation v1
```

The test should also verify:

```
ASR        = v3
TTS        = v2
Translation = v2
```

where the implementation is expected to use those services.

---

## 9A.12 — API CONTRACT TESTS

Create mocked contract tests based on the verified official schemas.

For each API test:

- `SUCCESS`
- `INVALID_REQUEST`
- `UNAUTHORIZED`
- `FORBIDDEN`
- `RATE_LIMITED`
- `SERVER_ERROR`
- `TIMEOUT`
- `MALFORMED_RESPONSE`

**Do NOT** use live provider calls in ordinary unit tests.

---

## 9A.13 — OPTIONAL LIVE INTEGRATION TEST

Create a separately controlled integration test that uses real provider
credentials supplied through the CI environment.

It **MUST NOT** contain credentials in source control.

The test should verify:

```
ASR:         real audio -> transcription
TTS:         text -> playable audio
Translation: source text -> translated text
```

Mark this test as `LIVE PROVIDER TEST` and keep it separate from
deterministic unit tests.

---

## 9A.14 — API CONTRACT CHANGE DETECTION

Do not scatter version strings such as `/v3/...` or `/v2/...` throughout the
application. Centralize provider configuration:

```dart
class KhayaApiVersionConfig {
  static const String asrVersion         = 'v3';
  static const String ttsVersion         = 'v2';
  static const String translationVersion = 'v2';
}
```

The actual endpoint definitions remain in the provider client layer.

---

## 9A.15 — DOCUMENTATION SYNCHRONIZATION

Any change to endpoint, version, language code, request body, response body,
authentication, or error handling **MUST** trigger updates to:

```
docs/api/KHAYA_API_CONTRACT.md
docs/api/khaya_api_contract.json
README.md
language API documentation
privacy documentation
deployment documentation
tests
```

No documentation may claim an API is implemented until the code and tests
verify the contract.

---

## 9A.16 — FINAL API ACCEPTANCE GATE

Do **not** declare language API integration complete until:

**Contract verification:**
- [ ] ASR v3 contract verified from official source
- [ ] TTS v2 contract verified from official source
- [ ] Translation v2 contract verified from official source
- [ ] Exact endpoints verified
- [ ] HTTP methods verified
- [ ] Headers verified
- [ ] Authentication verified
- [ ] Request schemas verified
- [ ] Response schemas verified
- [ ] Language codes verified
- [ ] Limits verified
- [ ] Error statuses verified

**Implementation:**
- [ ] Flutter DTOs implemented
- [ ] Domain interfaces implemented
- [ ] Provider adapters implemented
- [ ] Response validation implemented
- [ ] Error mapping implemented
- [ ] Deprecated v1 usage removed
- [ ] Credentials protected

**Testing:**
- [ ] Unit tests pass
- [ ] Contract tests pass
- [ ] Live integration test passes where configured
- [ ] Android tested
- [ ] iOS tested
- [ ] Documentation synchronized

If any item remains unverified:

```
STATUS = NOT READY
```

---
---

# PHASE 10 — GHANAIAN LANGUAGE API INTEGRATION & PRODUCTION CONFIGURATION

## ROLE

You are the senior Flutter/Dart engineer responsible for integrating and
validating CropGuard AI\'s Ghanaian-language services for production.

You are modifying an **existing** Flutter application.

- **DO NOT** redesign unrelated architecture.
- **DO NOT** replace working implementations unnecessarily.
- **DO NOT** invent APIs, endpoints, request formats, response fields,
  credentials, or package behavior.
- **DO NOT** declare success unless the implementation has actually been
  verified.

The enabled language services are:

1. Automatic Speech Recognition API — **v3**
2. Text-To-Speech API — **v2**
3. Translation API — **v2**

The v1 versions shown in the provider console are **deprecated and MUST NOT be used.**

---

## 1 — PRIMARY OBJECTIVE

Configure CropGuard AI so that its Ghanaian-language functionality uses the
currently supported APIs:

- **ASR v3** for speech-to-text
- **TTS v2** for text-to-speech
- **Translation v2** for language translation

The integration must work correctly with the existing Flutter architecture,
authentication/security model, offline-first design, localization system,
error handling, logging, and production deployment configuration.

**The application must never silently fall back to a deprecated API.**

---

## 2 — FIRST: AUDIT BEFORE MODIFYING CODE

Before changing anything, inspect the entire repository.

Search for:

- ASR, speech recognition, speech-to-text, transcription
- TTS, text-to-speech, synthesis
- translation
- Ghana NLP, Khaya
- API keys, subscription keys, bearer tokens
- HTTP endpoints, provider URLs
- old API versions: v1, v2, v3
- hard-coded language codes
- `dart-define`, `.env`
- Remote Config
- secret/config classes
- microphone permissions
- audio recording, audio playback
- localization services

Also inspect:

- `pubspec.yaml`
- Android permissions
- iOS `Info.plist` and iOS URL/configuration files
- Firebase Functions
- Firebase Remote Config usage
- Existing API services/repositories/interfaces
- Dependency injection
- Error classes
- Logging
- Analytics
- Tests
- Documentation

**DO NOT modify anything during this first audit.**

Produce a concise internal implementation map:

```
Current ASR implementation:
Current TTS implementation:
Current translation implementation:
Current API provider:
Current endpoints:
Current authentication mechanism:
Current language codes:
Current Flutter packages:
Current backend/proxy:
Current fallback behavior:
Current offline behavior:
Current error handling:
Current tests:
Current documentation:
```

Then compare the implementation against the provider\'s currently supported API
versions.

---

## 3 — MANDATORY API VERSION POLICY

The **only permitted production API versions** are:

```
ASR        -> v3
TTS        -> v2
Translation -> v2
```

**Explicitly prohibit:**

```
ASR v1
TTS v1
Translation v1
```

Search the entire repository for deprecated API references. If old references
are found:

- Remove them where obsolete
- Migrate active code where necessary
- Update tests, comments, and documentation

> If a historical document must mention the old APIs, clearly label them:
> **HISTORICAL / DEPRECATED — NOT USED BY CURRENT APPLICATION**

---

## 4 — DO NOT PUT SECRET PROVIDER CREDENTIALS DIRECTLY IN FLUTTER

Audit how provider credentials are currently handled. A mobile application is
**not** a secure place for a genuinely privileged secret.

**Preferred architecture:**

```
Flutter Application
        |
        |  authenticated request
        v
Firebase/Cloud Function or trusted backend
        |
        |  provider credential
        v
Ghanaian Language API
```

The Flutter application **MUST NOT** contain a privileged subscription/API
credential in source code.

Do **NOT** place secrets in:

- Dart constants or source files
- Assets
- `pubspec.yaml`
- Committed `.env`
- Remote Config merely to make the secret less visible
- Labels/metadata files

Remote Config **MAY** be used for non-secret configuration only:
feature flags, endpoint config, timeouts, supported-language lists, version
flags.

It **MUST NOT** be treated as a secure vault for privileged API credentials.

---

## 5 — IF THE PROJECT ALREADY USES A BACKEND PROXY

If CropGuard already has a Firebase Function or other trusted backend service,
reuse the existing architecture where appropriate. **Do NOT create a second
unnecessary networking architecture.**

Maintain the existing clean architecture:

```
presentation
domain
data
core
```

Do not put provider-specific HTTP code directly in widgets.

---

## 6 — ASR v3 IMPLEMENTATION

Configure speech recognition against:

```
Automatic Speech Recognition API - v3
```

**Do not use ASR v1.**

Audit the existing implementation for: recording, encoding, MIME type, sample
rate, channel count, duration, authentication, language selection, request
payload, response parsing, errors, timeouts, retries.

Use the provider\'s **current official v3** request and response schema.
**DO NOT** assume the v1 schema is compatible with v3. If the current code
uses a v1 request format, migrate it fully.

---

## 7 — ASR LANGUAGE SUPPORT

Create a single authoritative mapping:

```
CropGuard locale -> Provider language code
```

For every supported language, document:

| Field                 | Value |
|-----------------------|-------|
| CropGuard language    |       |
| Display name          |       |
| Internal locale       |       |
| Provider language code|       |
| ASR supported         |       |
| TTS supported         |       |
| Translation supported |       |

Verify actual provider support. If a language is unavailable for ASR:

- Return explicit `UnsupportedLanguage` error
- **DO NOT** silently send a different language

---

## 8 — MICROPHONE PERMISSIONS

**Android** must have the appropriate microphone permission in
`AndroidManifest.xml`.

**iOS** must have `NSMicrophoneUsageDescription` with an accurate user-facing
description in `Info.plist`.

Test: first request, allow, deny, permanently denied, settings recovery,
microphone unavailable.

**The application must provide a clear error when microphone access is denied.
It must not crash.**

---

## 9 — AUDIO RECORDING VALIDATION

Validate: supported format, sample rate, mono/stereo expectations, maximum
recording duration, empty audio, corrupted audio, microphone interruption,
phone call interruption, app backgrounding, rapid start/stop, cancellation.

**Never send empty/invalid audio to the remote API.**

---

## 10 — ASR TIMEOUTS AND RETRIES

Implement controlled: connection timeout, request timeout, retry policy,
cancellation, exponential backoff where appropriate.

**DO NOT retry permanent errors** such as: invalid credentials, unsupported
language, malformed request, unauthorized request.

**Retry transient failures** such as: temporary network failure, timeout,
temporary 5xx response.

Do not allow repeated retries to run indefinitely.

---

## 11 — ASR RESULT CONTRACT

The domain layer should expose:

```
SpeechRecognitionResult {
    transcript
    language
    confidence (only if genuinely provided by provider)
    duration
}
```

**Never invent a confidence value if the provider does not provide one.**

Handle: empty transcript, partial transcript, successful transcript, API error,
network error, unsupported language, authentication error, rate limit.

---

## 12 — TTS v2 IMPLEMENTATION

Configure:

```
Text-To-Speech API - v2
```

**Do not use TTS v1.**

Audit: request body, voice selection, language code, audio format, response
decoding, playback, caching, cancellation, lifecycle, errors.

Do not assume the v1 response format works with v2. Use the provider\'s current
official v2 schema.

---

## 13 — TTS LANGUAGE/VOICE MAPPING

Create one centralized mapping:

```
CropGuard locale -> TTS language code -> TTS voice
```

Do not scatter voice names throughout the application. Example structure:

```dart
class LanguageConfig {
  final String locale;
  final String providerLanguageCode;
  final String voiceId;
  final bool asrSupported;
  final bool ttsSupported;
  final bool translationSupported;
}
```

The exact codes/voice IDs **MUST** be verified against the current provider
documentation. **Do not invent or infer codes.**

---

## 14 — TTS PLAYBACK

The application must: decode the provider response correctly, play the returned
audio reliably, stop previous playback when necessary, handle interruptions,
release resources, avoid overlapping audio, handle corrupt audio responses.

Test: short text, long text, empty text, special characters, multilingual text,
rapid play/stop, screen navigation during playback, app backgrounding, network
failure.

---

## 15 — TTS CACHING

Suitable caching targets: disease names, static treatment explanations, static
UI/help content.

**Do NOT** blindly cache personalized or sensitive user content.

Caching must have: size limit, eviction policy, lifecycle, invalidation
strategy.

---

## 16 — TRANSLATION v2 IMPLEMENTATION

Configure:

```
Translation API - v2
```

**Do not use Translation v1.**

Audit the existing translation service and determine whether translation
happens on-device, directly from Flutter, through Firebase, or through another
backend. Use **exactly one** authoritative production path.

---

## 17 — TRANSLATION CONTRACT

Create a domain-level interface:

```
TranslationService
  translate(text, sourceLanguage, targetLanguage)
```

The provider-specific implementation must remain outside the UI.

Handle: empty input, same source/target language, unsupported language, network
failure, timeout, rate limiting, provider failure, malformed response.

If source and target languages are the same, **avoid an unnecessary remote
request.**

---

## 18 — NEVER TRANSLATE MEDICAL/AGRICULTURAL CONTENT BLINDLY

For important treatment information, preserve: original meaning, dosage and
units, warnings and safety instructions, crop names, disease names.

**Never alter numerical dosage values during translation.**

---

## 19 — OFFLINE-FIRST LANGUAGE BEHAVIOR

**ASR** — If remote ASR is unavailable:
> Show: "Voice input requires an internet connection."
> Do not fabricate transcription.

**TTS** — If remote TTS is unavailable:
> Use local TTS only if already part of the approved architecture; otherwise
> report an explicit unavailable state. Do not silently switch to an unrelated
> language voice.

**Translation** — If translation is unavailable:
> Retain original content; optionally use a verified local/static translation
> cache; clearly indicate when remote translation is unavailable.
> Never display the original text as though it were translated.

---

## 20 — ERROR TAXONOMY

Use explicit domain errors rather than generic exceptions everywhere:

```
LanguageServiceUnavailable
UnsupportedLanguage
AuthenticationFailure
RateLimitExceeded
InvalidAudio
InvalidText
TranslationFailure
SpeechRecognitionFailure
SpeechSynthesisFailure
NetworkUnavailable
RequestTimeout
ProviderServerError
MalformedProviderResponse
```

Map provider-specific HTTP errors into these stable domain errors. **Do not
expose raw API error bodies to users.**

---

## 21 — SECURITY

Ensure: HTTPS only, credentials sent only where required, authorization headers
not logged, API keys never logged, request bodies with sensitive information not
logged.

Search for and remove accidental patterns such as:

```dart
print(apiKey)
debugPrint(headers)
logger.info(token)
Crashlytics.recordError(... secret ...)
```

---

## 22 — RATE LIMITING AND COST CONTROL

Prevent: user repeatedly pressing translate, user rapidly starting/stopping
speech requests, automatic retry storms, TTS request loops, duplicate requests.

Use: debounce, request cancellation, request IDs, retry limits, server-side
rate limiting if available.

**Do not allow the app to accidentally create large API bills.**

---

## 23 — RESPONSE VALIDATION

Treat external API responses as untrusted input. Validate: HTTP status,
Content-Type, JSON structure, required fields, field types, response size,
audio payload integrity.

If response structure is unexpected: return a controlled provider error. Do
not crash. Do not assume missing fields are present.

---

## 24 — LOGGING

**Log only safe diagnostic metadata:**
provider, operation, language, duration, HTTP status, request ID, latency,
error category.

**Never log:** subscription key, API key, access token, raw microphone audio,
complete sensitive user text.

---

## 25 — ANALYTICS

If analytics are enabled, measure: ASR success/failure, TTS success/failure,
translation success/failure, unsupported-language event, latency, provider
error category.

**Do NOT send:** raw speech transcript, sensitive user content, audio,
credentials.

Respect the application\'s analytics opt-out mechanism. **Verify that opt-out
actually suppresses these events.**

---

## 26 — TESTING

**ASR unit tests:**
- Success
- Empty result
- Unsupported language
- 401, 403, 429, 500
- Timeout
- Network failure
- Malformed response

**TTS unit tests:**
- Success
- Empty text
- Unsupported voice
- Network failure
- Malformed response
- Invalid audio

**Translation unit tests:**
- Success
- Same language
- Unsupported language
- Network failure
- Timeout
- 429
- Malformed response

---

## 27 — MOCK PROVIDER RESPONSES

Do not make unit tests depend on the real provider API. Create mocked responses
for: success, invalid request, authentication failure, rate limiting, server
error, malformed response, timeout.

**Never commit real credentials.**

---

## 28 — INTEGRATION TESTS

Verify the complete Flutter flow:

```
Language selected
    |
    v
Record speech
    |
    v
ASR v3
    |
    v
Transcript
    |
    v
Translation v2 (when requested)
    |
    v
Display result
    |
    v
TTS v2
    |
    v
Audio playback
```

Test for: English, Twi, Ewe, Dagbani — **only for languages actually
supported by the provider and application.**

---

## 29 — END-TO-END REAL DEVICE TESTING

Perform on Android release build **and** iOS release build.

Test: microphone permission, speech recognition, translation, TTS playback,
background/foreground, network loss, network restoration, rapid interaction,
app restart, language switching.

**Do not declare the feature production-ready based only on unit tests.**

---

## 30 — API VERSION REGRESSION PROTECTION

Add a test or static validation that fails if deprecated endpoints return to
the codebase. Search for: `ASR v1`, `TTS v1`, `Translation v1`.

**Production code must contain no active usage.**

---

## 31 — DEPENDENCY AUDIT

Inspect packages used for: recording, playback, permissions, HTTP, audio
decoding.

Verify they are: actively maintained, compatible with current Flutter, Android-
and iOS-compatible, compatible with the project\'s minimum OS versions.

Do not replace packages purely for style. Change dependencies only where
necessary and document the reason.

---

## 32 — CONFIGURATION

Create a central language-service configuration defining:

```
ASR provider version         = v3
TTS provider version         = v2
Translation provider version = v2

enabled languages
timeouts
retry limits
feature flags
backend endpoint
```

**Do not duplicate these values throughout the codebase.**

---

## 33 — DOCUMENTATION

Update all affected Markdown files. At minimum inspect:

```
README.md
architecture documentation
API documentation
language/translation documentation
security documentation
deployment documentation
privacy documentation
testing documentation
```

Documentation must state: `ASR = v3`, `TTS = v2`, `Translation = v2`.
It must **NOT** claim deprecated v1 APIs are in production.

Clearly document whether each feature is: **ONLINE** / **OFFLINE** / **HYBRID**

---

## 34 — PRIVACY

Update privacy documentation to accurately describe language-service data
flows. Explicitly identify: speech/audio transmission, transcript transmission,
translation requests, TTS requests, third-party providers, retention
expectations.

**Do not claim that speech/text remains entirely on-device if remote APIs are
used.**

---

## 35 — COST AND QUOTA MONITORING

Document: provider quota, API limits, expected usage, rate limits, failure
behavior, monitoring.

Where possible, implement backend metrics/monitoring to detect: sudden usage
spikes, repeated failures, rate-limit events, unexpected cost growth.

---

## 36 — FINAL ACCEPTANCE GATES

The implementation is **NOT complete** until all of the following are true:

**API versions:**
- [ ] ASR uses v3
- [ ] TTS uses v2
- [ ] Translation uses v2
- [ ] No production code uses deprecated v1 APIs
- [ ] No deprecated API endpoint remains active
- [ ] Provider request schemas verified
- [ ] Provider response schemas verified

**Security:**
- [ ] No privileged API secret is embedded in Flutter
- [ ] Backend authentication works
- [ ] HTTPS enforced
- [ ] Secrets are never logged

**Permissions:**
- [ ] Android microphone permission works
- [ ] iOS microphone permission works
- [ ] Android release test completed
- [ ] iOS release test completed

**Feature testing:**
- [ ] ASR success tested
- [ ] ASR failure tested
- [ ] TTS success tested
- [ ] TTS failure tested
- [ ] Translation success tested
- [ ] Translation failure tested

**Resilience:**
- [ ] Offline behavior explicitly handled
- [ ] Network recovery tested
- [ ] Rate limiting handled
- [ ] Retry policy tested
- [ ] Duplicate-request protection tested

**Localization:**
- [ ] Ghanaian language mappings verified
- [ ] Unsupported language behavior verified
- [ ] Localization behavior verified

**Quality:**
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Static deprecated-API scan passes
- [ ] Documentation matches implementation
- [ ] Privacy documentation matches actual data flow

---

## 37 — FINAL REPORT

When complete, produce:

```
GHANA_LANGUAGE_API_IMPLEMENTATION_REPORT.md
```

Containing:

- APIs enabled and exact API versions
- Current implementation path
- Backend architecture
- Authentication method
- Supported languages
- Android status and iOS status
- Offline behavior
- Security model
- Tests performed and results
- Known limitations
- Provider dependencies
- Cost/quota considerations
- Files changed and documentation changed
- Remaining blockers

**Every claim in the report must be supported by actual code/configuration/tests.**

---

## MOST IMPORTANT RULE

**DO NOT say "API integration complete"** just because the APIs have been
enabled in the provider console.

The feature is complete only when:

```
Provider
   +
Backend
   +
Flutter
   +
Permissions
   +
Security
   +
Error handling
   +
Offline behavior
   +
Tests
   +
Android release
   +
iOS release
   +
Documentation
```

**all agree and have been verified.**

If any component is unresolved, report:

```
BLOCKED
```

or:

```
PARTIALLY VERIFIED
```

instead of claiming success.
