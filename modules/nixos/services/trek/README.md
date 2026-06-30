# trek

NixOS module for [TREK](https://github.com/mauriceboe/TREK) — a self-hosted, real-time collaborative travel planner with maps, budgets, packing lists, a journal, and AI (MCP) built in.

## Quick start

```nix
{
  services.trek = {
    enable = true;
    domain = "trek.example.com";
    encryptionKeyFile = "/run/secrets/trek-encryption-key";
  };
}
```

This starts TREK on port 3000 and configures an nginx reverse proxy at `http://trek.example.com`.

## With SSL

```nix
{
  services.trek = {
    enable = true;
    domain = "trek.example.com";
    encryptionKeyFile = "/run/secrets/trek-encryption-key";
    nginx = {
      forceSSL = true;
      enableACME = true;
    };
  };
}
```

## With OIDC / optional settings

Extra environment variables (OIDC, SMTP, admin bootstrap, etc.) can be supplied
via `environmentFile`. The file is sourced by bash; lines are `KEY=value`.

```nix
{
  services.trek = {
    enable = true;
    domain = "trek.example.com";
    encryptionKeyFile = "/run/secrets/trek-encryption-key";
    environmentFile = "/run/secrets/trek.env";
    nginx.forceSSL = true;
  };
}
```

Example `/run/secrets/trek.env`:

```
OIDC_ISSUER=https://auth.example.com
OIDC_CLIENT_ID=trek
OIDC_CLIENT_SECRET=supersecret
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=changeme
DEFAULT_LANGUAGE=en
TZ=Europe/Berlin
LOG_LEVEL=info
```

## Data layout

| Path | Purpose |
|---|---|
| `dataDir/data/` | SQLite database, JWT secret, encryption key, logs, backups |
| `dataDir/uploads/` | User-uploaded photos, files, covers, avatars |

`dataDir` defaults to `/var/lib/trek`.

## Options reference

| Option | Default | Description |
|---|---|---|
| `domain` | — | Public domain (required) |
| `port` | `3000` | HTTP listen port |
| `dataDir` | `/var/lib/trek` | State directory |
| `user` / `group` | `trek` | Service user and group |
| `encryptionKeyFile` | `null` | Path to file with `ENCRYPTION_KEY` |
| `environmentFile` | `null` | Optional env file for OIDC, SMTP, etc. |
| `nginx` | `{}` | nginx vhost options; set to `null` to disable |

## Generating an encryption key

```bash
openssl rand -hex 32 | install -m 600 /dev/stdin /run/secrets/trek-encryption-key
```

If `encryptionKeyFile` is not set, TREK auto-generates a key and persists it to
`dataDir/data/.encryption_key`. You can migrate to an explicit key later by
reading that file and placing it at the path you configure.
