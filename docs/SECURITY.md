# Security & Secret/API Architecture

## 1. Core Security Architecture (Flutter → Backend → Third-Party API)

For genuinely sensitive credentials (e.g. Gemini AI API Keys, Ghana NLP Azure Subscription Keys, Cloudinary API Secrets), CropGuard AI enforces a **zero-client-trust architecture**:

```
┌─────────────────┐       Supabase Auth JWT        ┌───────────────────────────┐       Server Secret       ┌───────────────────┐
│  Flutter Mobile │ ─────────────────────────────> │  Supabase Edge Function   │ ────────────────────────> │  Third-Party API  │
│   Client App    │        (Bearer Token)          │      (Backend Proxy)      │    (Supabase Secrets)     │ (Gemini/GhanaNLP) │
└─────────────────┘                                └───────────────────────────┘                           └───────────────────┘
```

### Exit Gate
> **No sensitive API credential needs to be trusted merely because it is hidden in client binaries or `--dart-define`.**

---

## 2. Review of Third-Party Credentials & Security Boundaries

### A. Gemini Cloud AI
- **Risk Profile**: High (master API key controls LLM quota, billing, and generative capabilities).
- **Hardened Architecture**: The mobile client issues authenticated requests (`CloudFunctionsService.analyzeCropWithGemini`) to Supabase Edge Functions (`supabase/functions/analyze-crop`). The backend holds `GEMINI_API_KEY` in Supabase Secrets / server environment variables and enforces Supabase Auth session JWT verification.
- **Local Dev / Testing**: In offline or local mock environments, direct API keys provided via `.env` or `--dart-define` are supported strictly as dev fallbacks.

### B. Ghana NLP (ASR & TTS)
- **Risk Profile**: High (paid Azure APIM subscription key).
- **Hardened Architecture**: The mobile client routes voice transcription and synthesis through `CloudFunctionsService.synthesizeGhanaNlp` and `transcribeGhanaNlp` (`supabase/functions/khaya-tts`, `supabase/functions/khaya-asr`, `supabase/functions/khaya-translate`). The master `GHANA_NLP_SUBSCRIPTION_KEY` is kept server-side in Supabase Edge Functions.

### C. Cloudinary (Media Hosting)
- **Risk Profile**: Moderate (unsigned preset).
- **Hardened Architecture**: Primary community and diagnostic scan uploads are routed through **Supabase Storage** (`SupabaseStorageService`), which is strictly authenticated, user-scoped, size-capped (< 5MB), and enforced via PostgreSQL Storage RLS policies. Cloudinary unsigned presets are retained only as secondary failover and strictly scoped in Cloudinary dashboard settings.

### D. Supabase Configuration (`app_secrets.dart` / `.env`)
- **Risk Profile**: Public Client Identifiers (NOT Secrets).
- **Hardened Architecture**: `SUPABASE_URL` and `SUPABASE_ANON_KEY` are client configuration constants by design. Protection is achieved through:
1. **Supabase Row Level Security (RLS)** enforcing user-scoped read/write permissions on all PostgreSQL tables.
2. **Storage Policies** restricting bucket uploads and downloads to authenticated user directories.
3. **Database Constraints & Triggers** preventing unauthorized data tampering.

### E. Compile-Time `--dart-define`
- **Classification**: Build Configuration & Environment Flags (NOT an Encrypted Secret Store).
- **Usage Policy**: `--dart-define` compiles plain strings into binary text segments (extractable via decompilation tools). It is used for build flavors, bundle IDs, and non-sensitive constants. Master production secrets must reside in backend services.

---

## 3. Platform Hardening & Enforcement Summary
- **Supabase Edge Functions**: All incoming requests require valid Supabase Auth Bearer JWT tokens.
- **PostgreSQL RLS / Storage Policies**: Default-deny, strictly user-scoped, request size limits (< 5MB / < 10MB) and MIME-type restrictions.
- **Secret Manager Provisioning**: Backend secrets are configured via:
  ```bash
  supabase secrets set GEMINI_API_KEY=...
  supabase secrets set GHANA_NLP_SUBSCRIPTION_KEY=...
  ```
- **Integrity Checks**: Device jailbreak/root and screen security helpers (`core/utils/`) are integrated for runtime tamper defense.

