> [!IMPORTANT]
> This module might not cover everything you need. If you run into missing options or rough edges, please [open an issue](https://github.com/74k1/tixpkgs/issues) or send a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.shitter`

Shitter is an alternative Twitter front-end. It is a fork of Nitter.

## Info

- Project Website: `https://shitter.thepixora.com`
- Project Source: `https://codeberg.org/shitter/shitter`
- Project Docs: `https://codeberg.org/shitter/shitter/wiki`

## Usage

```nix
{
  inputs,
  ...
}:
{
  imports = [
    inputs.tixpkgs.nixosModules'.services.shitter
    # or
    inputs.tixpkgs.nixosModules."services/shitter"
  ];

  services.shitter = {
    enable = true;
    address = "127.0.0.1";
    port = 8080;

    sessionsFile = "/run/secrets/shitter-sessions.jsonl";

    settings = {
      Server = {
        hostname = "shitter.example.com";
        https = true;
      };
      Preferences.replaceTwitter = "shitter.example.com";
    };
  };
}
```

Set `settings.Server.hostname`. If you do not, generated links point to the upstream instance.

The module does not configure a reverse proxy. Put your own proxy in front of `address:port`.

## Session tokens

Shitter does not start without a sessions file. See [Creating session tokens](https://codeberg.org/shitter/shitter/wiki/Creating-session-tokens), then point `services.shitter.sessionsFile` at the result. The default path is `/var/lib/shitter/sessions.jsonl`.

The file is passed to the service as a systemd credential, so it can be readable by root only.

## Settings

`services.shitter.settings` maps to the sections of [`nitter.example.conf`](https://codeberg.org/shitter/shitter/src/branch/master/nitter.example.conf): `Server`, `Cache`, `Config` and `Preferences`.

The module sets these keys, and ignores values you give for them in `settings`:

- `Server.address` and `Server.port`, from `services.shitter.address` and `services.shitter.port`
- `Config.hmacKey`, generated on first start and stored in `/var/lib/shitter/hmac`
- `Cache.redisHost`, when `redisCreateLocally` is enabled

Do not put secrets in `settings`. Those values are written to the Nix store.

## Notes

- A local Redis server (`redis-shitter.service`) is configured by default. Shitter connects to it through the Unix socket `/run/redis-shitter/redis.sock`, so the server listens on no TCP port.
- To use your own Redis server, set `redisCreateLocally = false` and set `settings.Cache.redisHost` and `settings.Cache.redisPort`. If `redisHost` is an absolute path, the package connects to that Unix socket and ignores `redisPort`. Upstream Shitter supports TCP only.
- The package links PCRE version 1 (`tixpkgs.pcre`). PCRE version 1 is end of life and nixpkgs removed it. Nim's regular expression modules support no other version.
