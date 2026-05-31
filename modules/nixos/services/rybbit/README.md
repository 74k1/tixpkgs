> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.rybbit`

Rybbit is an open-source, privacy-friendly web analytics platform.

## Info

- Project Website: `https://rybbit.com/`
- Project Source: `https://github.com/rybbit-io/rybbit`
- Project Docs: `https://docs.rybbit.io/`

## Usage

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.rybbit
    # or
    inputs.tixpkgs.nixosModules."services/rybbit"
  ];

  services.rybbit = {
    enable = true;

    hostname = "analytics.example.com";

    environmentFile = /run/secrets/rybbit.env;
    environment = {
      BASE_URL = "https://analytics.example.com";
      DISABLE_SIGNUP = true;
    };

    nginx = {
      forceSSL = true;
      enableACME = true;
    };
  };
}
```

Required `environmentFile` contents:

```env
BETTER_AUTH_SECRET=...
```

## Notes

The module runs one systemd unit, `rybbit.service`, which starts both upstream components:

- backend/API on `127.0.0.1:3001`
- web UI on `127.0.0.1:${services.rybbit.clientPort}`, default `3002`

With `nginx` enabled, `/api/` is proxied to the backend and `/` to the web UI.

By default the module creates local PostgreSQL and ClickHouse instances and runs migrations on startup. Set `services.rybbit.settings.redis.createLocally = true;` if you need Redis-backed uptime monitoring.

`BETTER_AUTH_SECRET` is required. Put secrets in `environmentFile`, not `environment`, if you keep this long-term.
