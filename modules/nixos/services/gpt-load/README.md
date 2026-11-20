> [!IMPORTANT]
> This module might not cover everything you need. If you run into missing options or rough edges, please [open an issue](https://github.com/74k1/tixpkgs/issues) or send a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.gpt-load`

GPT-Load is a self-hosted proxy for AI APIs. It manages provider credentials and switches between them when a request fails.

## Info

- Project Source: <https://github.com/tbphp/gpt-load>

## Quick start

```nix
{ inputs, ... }: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.gpt-load
    # or: inputs.tixpkgs.nixosModules."services/gpt-load"
  ];

  services.gpt-load.enable = true;
}
```

After rebuilding, open `http://127.0.0.1:3001` on the host. Read `/var/lib/gpt-load/auth.key` as root and use that key to sign in.

The module does not open a firewall port. For remote access, point your HTTPS reverse proxy at `127.0.0.1:3001`. If you change `services.gpt-load.port`, use the same port in the proxy configuration.

## Data and secrets

By default, GPT-Load stores its SQLite database (`gpt-load.db`) and generated keys in `/var/lib/gpt-load`. The service runs as the `gpt-load` system user. Its state directory has mode `0700`.

Back up `encryption.key` with the database. Without the matching key, GPT-Load cannot decrypt stored provider credentials.

To supply your own `AUTH_KEY` or other upstream settings, put them in a root-only environment file, one `KEY=value` per line. Keep the file outside the Nix store:

```nix
services.gpt-load.environmentFile = "/run/secrets/gpt-load.env";
```
