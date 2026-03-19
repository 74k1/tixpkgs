> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
> 
> Contributions are always welcome!

# `nixosModules'.services.rsshub`

> 🧡 Everything is RSSible

RSSHub delivers millions of contents aggregated from all kinds of sources, our vibrant open source community is ensuring the deliver of RSSHub's new routes, new features and bug fixes.

## Info

- Project Website: `https://rsshub.app/`
- Project Source: `https://github.com/diygod/rsshub`
- Project Docs: `https://docs.rsshub.app/`

## Usage

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.rsshub
    # or
    inputs.tixpkgs.nixosModules."services/rsshub"
  ];

  services.rsshub = {
    enable = true;
    settings = {
      caching.enable = true;
    };
    environmentFile = ./my_env_file; # Holds TWITTER_AUTH_TOKEN for example (use agenix)
    environment = {
      PORT = 1200; # already set to 1200 per default
    };
  };
}
```

Rebuild and then check it out at https://localhost:1200/ ! :shipit:
