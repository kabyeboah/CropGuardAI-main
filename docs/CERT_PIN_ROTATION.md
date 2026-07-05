# Certificate pinning rotation (CropGuard AI)

Network pinning for production hosts must use **real** SHA-256 SPKI hashes from your TLS certificates. Placeholder pins break connectivity or provide no security benefit.

## When to rotate

- Before your leaf or intermediate certificate is renewed (typically annually, or when your CA changes issuance chain).
- After a security incident involving TLS keys.
- When migrating API endpoints or CDNs.

## Obtain a pin digest

From a desktop with OpenSSL, after connecting to your API host:

```bash
echo | openssl s_client -servername api.example.com -connect api.example.com:443 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

Repeat for **at least one backup pin** (e.g. issuer intermediate or a second leaf) so you can roll certificates without bricking the app.

## Android `network_security_config`

Add pins under a `<domain-config>` for each pinned host:

```xml
<pin-set expiration="2027-12-31">
    <pin digest="SHA-256">BASE64_FROM_OPENSSL</pin>
    <pin digest="SHA-256">BACKUP_BASE64</pin>
</pin-set>
```

Ship an app update **before** `expiration` with refreshed pins, or remove the old pin after the new certificate is live everywhere.

## OkHttp CertificatePinner (optional)

If you add OkHttp pinning in code, keep the same digests in sync with `network_security_config.xml` and document both in release notes.
