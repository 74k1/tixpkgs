> [!IMPORTANT]
> This module might not cover everything you need. If you run into missing options or rough edges, please [open an issue](https://github.com/74k1/tixpkgs/issues) or send a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.trek`

TREK is a self-hosted, real-time collaborative travel planner with maps, budgets, packing lists, a journal, and AI (MCP) built in.

## Info

- Project Website: `https://trekplan.app/`
- Project Source: `https://github.com/mauriceboe/TREK`

## Quick start

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.trek
    # or
    inputs.tixpkgs.nixosModules."services/trek"
  ];

  services.trek = {
    enable = true;
    domain = "trek.example.com";
  };
}
```

This starts TREK on port 3000, reachable at `http://trek.example.com:3000`.

## With SSL

```nix
services.trek = {
  enable = true;
  domain = "trek.example.com";
  nginx = {
    forceSSL = true;
    enableACME = true;
  };
};
```

Setting `nginx` to a non-null value wires up nginx as a reverse proxy on port 80/443.

## Encryption key

TREK encrypts stored secrets (API keys, TOTP seeds, OIDC credentials) at rest.
By default an auto-generated key is persisted to `dataDir`. For a stable key across data migrations, supply one explicitly:

```nix
services.trek = {
  enable = true;
  domain = "trek.example.com";
  encryptionKeyFile = "/run/secrets/trek-encryption-key";
};
```

Generate it once:

```bash
openssl rand -hex 32 | install -m 600 /dev/stdin /run/secrets/trek-encryption-key
```

## Extra environment (OIDC, SMTP, admin bootstrap)

Optional settings go through `environmentFile`:

```nix
services.trek = {
  enable = true;
  domain = "trek.example.com";
  environmentFile = "/run/secrets/trek.env";
};
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

Do not put secrets directly in `services.trek.settings` — those values land in the Nix store.

## Data layout

| Path | Purpose |
|---|---|
| `dataDir/data/` | SQLite database, JWT secret, encryption key, logs, backups |
| `dataDir/uploads/` | User-uploaded photos, files, covers, avatars |

`dataDir` defaults to `/var/lib/trek`.
