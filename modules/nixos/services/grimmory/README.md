> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
> 
> Contributions are always welcome!

# `nixosModules'.services.grimmory`

Grimmory is a self-hosted, multi-user digital library.

## Info

- Project Website: `https://grimmory.org/`
- Project Source: `https://github.com/grimmory-tools/grimmory`
- Project Docs: `https://grimmory.org/docs/getting-started`

## Usage

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.grimmory
    # or
    inputs.tixpkgs.nixosModules."services/grimmory"
  ];

  services.grimmory = {
    enable = true;
    hostname = "books.example.com";
    nginx = {
      forceSSL = true;
      enableACME = true;
    };

    # Libraries on a separate mount: the service runs with
    # `ProtectSystem = "strict"`, so list any library folder outside the
    # default data/bookdrop directories here to make it writable.
    libraryDirs = [ "/mnt/pool/books" ];
  };
}
```

## Notes

- `nginx` is a full nixpkgs nginx vhost submodule (the same type as an entry in
  `services.nginx.virtualHosts`), not an attribute set with `enable` or
  `virtualHost` keys. Name the vhost with `hostname`; enable the reverse proxy by
  setting `nginx` to a non-null value. The proxy forwards `/` and `/ws`
  (websockets) and applies `settings.maxBodySize` as `client_max_body_size`.
- The service binds to `127.0.0.1` (`host`) by default, so point the reverse
  proxy at the loopback address, or set `host = "0.0.0.0"` to expose the port
  directly.
- Environment variables `APP_PATH_CONFIG`, `APP_BOOKDROP_FOLDER`, `SERVER_PORT`,
  `SERVER_ADDRESS`, `DATABASE_*` are managed by the module. Put secrets
  (`DATABASE_PASSWORD`, etc.) in `environmentFile` or `secretFiles`.
- By default the module creates a local MariaDB database (over TCP) and stores a
  generated database password under `/var/lib/grimmory/database-password`.
