# Changelog

## 0.2.0 (2026-11-06)

- `signIn` sends a `nonce` and refuses an id_token whose `iss`, `aud`, `sub` or `nonce` do not match (`id-token-invalid`). Refreshed id_tokens are checked for `iss`, `aud` and `sub`.
- A sign-out during a refresh can no longer restore the session.
- `state` is checked before the callback `error`.
- Concurrent `signIn` calls join the same flow.
- Browser and storage failures surface as typed `ClerkAuthException` (`browser`, `storage`).
- `dispose` closes the HTTP client the package created.
