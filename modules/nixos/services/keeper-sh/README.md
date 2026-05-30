> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.keeper`

Calendar synchronization platform with MCP support. Aggregates events from iCal/ICS, Google Calendar, Outlook, iCloud, and CalDAV sources and exposes them to AI agents via the Model Context Protocol.

## Info

- Project Website: `https://keeper.sh`
- Project Source: `https://github.com/ridafkih/keeper.sh`
- License: AGPL-3.0-only

## Services

The module manages five systemd units:

| Unit | Description | Default port |
|------|-------------|-------------|
| `keeper-migrate` | One-shot DB migration (runs at boot) | — |
| `keeper-api` | REST API + auth + calendar sync | 3001 |
| `keeper-web` | SSR web frontend | 3000 |
| `keeper-cron` | Cron scheduler (enqueues sync jobs) | — |
| `keeper-worker` | BullMQ job consumer | — |
| `keeper-mcp` | MCP server (optional, off by default) | 3002 |

## Usage

### Minimal (local PostgreSQL + Redis, with nginx)

```nix
{ config, ... }:
{
  services.keeper = {
    enable = true;
    domain = "keeper.example.com";
    secretKeyFile = "/run/secrets/keeper-auth-secret";
    encryptionKeyFile = "/run/secrets/keeper-encryption-key";

    nginx = {
      forceSSL = true;
      enableACME = true;
    };
  };
}
```

Both PostgreSQL and Redis are created locally by default. Run migrations, then start all services in the right order automatically.

### With Google & Microsoft calendar sync

Provider OAuth credentials go in an environment file — they are optional; Keeper works for iCal/ICS and CalDAV without them.

```nix
services.keeper = {
  enable = true;
  domain = "keeper.example.com";
  secretKeyFile = "/run/secrets/keeper-auth-secret";
  encryptionKeyFile = "/run/secrets/keeper-encryption-key";
  environmentFile = "/run/secrets/keeper.env";   # see below
};
```

`/run/secrets/keeper.env`:
```bash
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
MICROSOFT_CLIENT_ID=...
MICROSOFT_CLIENT_SECRET=...
RESEND_API_KEY=...          # optional — email notifications
```

### With the MCP server enabled

```nix
services.keeper = {
  enable = true;
  domain = "keeper.example.com";
  secretKeyFile = "/run/secrets/keeper-auth-secret";
  encryptionKeyFile = "/run/secrets/keeper-encryption-key";

  mcp.enable = true;   # exposes /mcp/ through nginx

  nginx = {
    forceSSL = true;
    enableACME = true;
  };
};
```

### External PostgreSQL + Redis

```nix
services.keeper = {
  enable = true;
  domain = "keeper.example.com";
  secretKeyFile = "/run/secrets/keeper-auth-secret";
  encryptionKeyFile = "/run/secrets/keeper-encryption-key";

  database = {
    createLocally = false;
    host = "db.example.com";
    port = 5432;
    user = "keeper";
    name = "keeper";
    passwordFile = "/run/secrets/keeper-db-password";
  };

  redis = {
    createLocally = false;
    host = "redis.example.com";
    port = 6379;
    passwordFile = "/run/secrets/keeper-redis-password";
  };
};
```

## Secret file format

All `*File` options expect a plain text file containing only the secret value (no trailing newline required; leading/trailing whitespace is stripped by the shell's `cat` invocation).

Generate suitable values:

```bash
# BETTER_AUTH_SECRET / secretKeyFile
openssl rand -base64 32

# ENCRYPTION_KEY / encryptionKeyFile
openssl rand -base64 32
```

## Nginx layout

When `services.keeper.nginx` is non-null the module registers a virtual host on `services.keeper.domain` with the following locations:

| Path | Upstream |
|------|----------|
| `/` | `keeper-web` (SSR server) |
| `/api/` | `keeper-api` |
| `/mcp/` | `keeper-mcp` (only when `mcp.enable = true`) |
