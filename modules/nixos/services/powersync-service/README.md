> [!IMPORTANT]
> PowerSync Service is source-available (FSL-1.1-ALv2), **not** FOSS.
> The license grants usage rights; review it if that matters to you.

# `nixosModules'.services.powersync-service`

**PowerSync Service** syncs Postgres changes out to PowerSync clients. It is the backend required by the
[Thunderbolt](../thunderbolt/README.md) web frontend's PowerSync sync client.

## Info

- Project Website: `https://www.powersync.com`
- Project Source: `https://github.com/powersync-ja/powersync-service`

## Minimal Usage

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.powersync-service
    # or
    inputs.tixpkgs.nixosModules."services/powersync-service"
  ];

  services.powersync-service = {
    enable = true;

    jwtSecret = "replace-with-a-32+char-random-secret";
    jwtKid = "replace-with-your-kid";

    postgresql = {
      enable = true;
      adminPassword = "replace-with-a-random-password";
      replicationPassword = "replace-with-a-random-password";
    };

    syncRules = '''
      bucket_definitions:
        user_data:
          data:
            - SELECT * FROM todos WHERE owner_id = auth.user_id()
    '';
  };
}
```

## How it works

- The module manages a local PostgreSQL server (logical replication + a dedicated storage database),
  creates a replication role, and generates the PowerSync config (JWKS from `jwtSecret`/`jwtKid`,
  sync rules, storage and replication connection strings).
- The app backend signs JWTs with the same `jwtSecret` (`POWERSYNC_JWT_SECRET` upstream); PowerSync
  verifies them against the derived HS256 JWKS key.
- With `postgresql.enable = false`, point the module at an external PostgreSQL server via
  `services.powersync-service.postgresql.host` / `port` instead — the schema and roles are not
  managed in that case.

## Defaults

- The API listens on port `8080`; the firewall stays closed unless `openFirewall = true`.
- `storagePassword` defaults to `adminPassword` unless overridden.

## Notes

- `jwtSecret` must be at least 32 characters.
- The managed PostgreSQL server listens on `127.0.0.1` and accepts password auth over TCP only.
- The embedded init script is only applied on database creation (`initialScript`); re-creating the
  database is required to re-run it.
