# Hemmelig

Encrypted secret sharing. Share sensitive information securely with client-side encryption and self-destructing messages.

## Quick start

```nix
services.hemmelig = {
  enable = true;
  domain = "secrets.example.com";
  nginx = {
    forceSSL = true;
    enableACME = true;
  };
};
```

## Secrets

The module stores secrets in `services.hemmelig.stateDir`:

- `BETTER_AUTH_SECRET` — auto-generated on first start and persisted to `stateDir/auth-secret`. Override via `services.hemmelig.authSecretFile` to provide a stable key.
- OAuth credentials and other optional settings — use `services.hemmelig.environmentFile` pointing to an env file.

## Requirements

- Hemmelig uses SQLite via `better-sqlite3`. No external database needed.
- The `BETTER_AUTH_URL` is derived automatically from the domain and nginx SSL settings. Override it with `services.hemmelig.baseUrl` if needed.
