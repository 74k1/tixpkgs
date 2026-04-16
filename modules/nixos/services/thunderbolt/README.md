> [!IMPORTANT]
> This module packages the upstream Thunderbolt web deployment: a static frontend plus the Bun backend.
> It does not package the upstream Tauri desktop app.

# `nixosModules'.services.thunderbolt`

**Thunderbolt** is Thunderbird's privacy-respecting AI assistant.

## Info

- Project Website: `https://thunderbolt.io/`
- Project Source: `https://github.com/thunderbird/thunderbolt`
- Upstream OIDC Docs: `https://github.com/thunderbird/thunderbolt/blob/v0.2.0/backend/docs/oidc-local-dev.md`
- Upstream Backend Docs: `https://github.com/thunderbird/thunderbolt/blob/v0.2.0/backend/README.md`

## Minimal Usage

```nix
{
  config,
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.thunderbolt
    # or
    inputs.tixpkgs.nixosModules."services/thunderbolt"
  ];

  services.thunderbolt = {
    enable = true;

    # This should be the frontend origin users open in the browser.
    # With the built-in nginx integration, do not point this at the backend port.
    publicUrl = "http://thunderbolt.example.com";

    environmentFile = config.sops.secrets.thunderbolt.path;
  };
}
```

Example `environmentFile` contents for the default `authMode = "oidc"`:

```env
BETTER_AUTH_SECRET=replace-with-a-random-secret
OIDC_CLIENT_ID=thunderbolt
OIDC_CLIENT_SECRET=replace-with-your-oidc-client-secret
OIDC_ISSUER=https://sso.example.com/realms/thunderbolt
```

If you want TLS on the built-in nginx vhost, add for example:

```nix
{
  services.thunderbolt.nginx = {
    forceSSL = true;
    enableACME = true;
    openFirewall = true;
  };
}
```

## Defaults

- The backend listens on `127.0.0.1:8000` by default.
- `services.thunderbolt.nginx = {}` by default, so nginx is configured unless you set `services.thunderbolt.nginx = null;`.
- With the default nginx integration, nginx serves the frontend and proxies `/v1/` to the backend.
- With the default nginx settings, the vhost uses nginx's normal HTTP default, so it serves plain HTTP on port `80` unless you enable SSL options such as `forceSSL`, `addSSL`, `onlySSL`, or custom `listen` entries.
- Without nginx, Thunderbolt does not listen on `80` or `443` by itself. Only the backend service runs on `services.thunderbolt.listenAddress` and `services.thunderbolt.port`, and you must serve `config.services.thunderbolt.webRoot` plus proxy `/v1/` yourself.
- `services.thunderbolt.environment` is generated into the Nix store. Put secrets such as `BETTER_AUTH_SECRET`, OIDC client secrets, and provider API keys in `services.thunderbolt.environmentFile` instead.

## Database

- The default database is embedded `PGlite`, stored under `/var/lib/thunderbolt/db`.
- You do **not** need to provide an external PostgreSQL server for the default setup.
- This is **not** SQLite. It is an embedded PostgreSQL-compatible database.
- To use an external PostgreSQL server instead:

```nix
{
  services.thunderbolt.database = {
    driver = "postgres";
    url = "postgresql://thunderbolt:secret@127.0.0.1:5432/thunderbolt";
  };
}
```

The verified path in this module is the default `pglite` setup.

## Notes

- `authMode` defaults to `oidc`, which matches the upstream self-hosted flow.
- If you switch to `authMode = "consumer"`, the service can start with only `BETTER_AUTH_SECRET`, but sign-in still needs upstream mail or OAuth configuration to be useful.
