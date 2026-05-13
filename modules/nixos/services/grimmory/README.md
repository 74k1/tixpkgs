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
    nginx = {
      forceSSL = true;
      enableACME = true;
    };
    hostname = "books.example.com";
  };
}
```

By default the module creates a local MariaDB database and stores a generated database password under `/var/lib/grimmory/database-password`.
