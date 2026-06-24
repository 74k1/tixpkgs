> [!IMPORTANT]
> This module might not cover everything you need. If you run into missing options or rough edges, please [open an issue](https://github.com/74k1/tixpkgs/issues) or send a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.yopass`

Yopass is a secure sharing service for secrets, passwords and files.

## Info

- Project Website: `https://yopass.se/`
- Project Source: `https://github.com/jhaals/yopass`

## Quick start

This is all you need for a single-domain setup with automatic HTTPS:

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.yopass
    # or
    inputs.tixpkgs.nixosModules."services/yopass"
  ];

  services.yopass = {
    enable = true;
    hostname = "secrets.example.com";
    nginx = {
      forceSSL = true;
      enableACME = true;
    };
  };
}
```

That's it. Yopass figures out the URL for share links on its own,
using whatever domain the visitor is connecting from, so you
don't need to tell it twice.

By default the module spins up a local memcached instance at `127.0.0.1:11211`.
If you'd rather use Redis (with a unix socket), set `services.yopass.database.backend = "redis"`.

## Multiple domains on one instance

You can point several domains at the same yopass without any extra config.
Just add more nginx `virtualHosts` entries. Secrets are stored by UUID so they
work across all domains, and as long as you leave `publicUrl` unset (which is
the default), each domain generates links pointing to itself.

## When to set `publicUrl`

Most people never need this. The only times you'd reach for it:

- You run a **read-only mirror** on a different domain and want all share links
  to point there.
- Your **reverse proxy or CDN** doesn't forward the original `Host` header
  properly, so yopass can't guess the right URL.
- You want share links to always use one specific domain even if someone
  reaches yopass through another.

If none of that sounds like you, just leave it alone.

## Advanced

Flags that aren't exposed as module options (S3 file storage, OIDC, license keys,
branding, audit logging, etc.) go through `services.yopass.extraFlags`. Anything
secret-based should live in `services.yopass.environmentFile`, never in the Nix
store:

```nix
services.yopass = {
  enable = true;
  extraFlags = [
    "--file-store=s3"
    "--file-store-s3-bucket=my-bucket"
    "--file-store-s3-region=eu-west-1"
    "--oidc-issuer=https://accounts.google.com"
    "--oidc-client-id=..."
    "--oidc-redirect-url=https://secrets.example.com/auth/callback"
  ];
  environmentFile = "/run/secrets/yopass.env";
};
```

Yopass reads environment variables natively for every flag. Just uppercase the
flag name and swap dashes for underscores: `--oidc-client-secret` becomes
`OIDC_CLIENT_SECRET`. No prefix needed.
