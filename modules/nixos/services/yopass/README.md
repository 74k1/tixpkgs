> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.yopass`

Yopass is a secure sharing service for secrets, passwords and files.

## Info

- Project Website: `https://yopass.se/`
- Project Source: `https://github.com/jhaals/yopass`

## Usage

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
    nginx = {
      forceSSL = true;
      enableACME = true;
    };
    hostname = "secrets.example.com";
    publicUrl = "https://secrets.example.com";
  };
}
```

By default the module creates a local memcached instance at `127.0.0.1:11211`.
Switch to Redis (with unix socket) via `services.yopass.database.backend = "redis"`.

## Advanced

For flags not exposed as module options (S3 file store, OIDC, license key, branding, audit logging), use `services.yopass.extraFlags`. Secret-based flags should go in `services.yopass.environmentFile` instead of the Nix store:

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

Environment variables use the `YOPASS_` prefix with dashes→underscores (e.g. `YOPASS_OIDC_CLIENT_SECRET` maps to `--oidc-client-secret`).
