# RSSHub NixOS Module

example usage:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
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
