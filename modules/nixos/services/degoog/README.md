> [!IMPORTANT]
> This module might not cover everything you need. If you run into missing options or rough edges, please [open an issue](https://github.com/74k1/tixpkgs/issues) or send a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.degoog`

Degoog is a search engine aggregator with a comprehensive plugin/extension system.

## Info

- Project Website: `https://degoog.org/`
- Project Source: `https://github.com/degoog-org/degoog`
- Project Docs: `https://degoog-org.github.io/docs/`

## Quick start

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.degoog
    # or
    inputs.tixpkgs.nixosModules."services/degoog"
  ];

  services.degoog = {
    enable = true;
    hostname = "search.example.com";
    environment = {
      DEGOOG_WIZARD = "true";
      DEGOOG_DEFAULT_SEARCH_LANGUAGE = "en-US";
    };
    environmentFile = "/run/secrets/degoog.env"; # DEGOOG_SETTINGS_PASSWORDS=...
  };
}
```

Once system is rebuilt, open 127.0.0.1:4444 or reverse proxy it to search.example.com. :)

## All options

No one should ever run degoog like this...... but it's probably possible to.

```nix
services.degoog = {
  enable = true;
  host = "0.0.0.0"; # listen on all interfaces | 127.0.0.1 by default
  port = 3333; # 4444 by default
  openFirewall = true; # open the port in the firewall
  hostname = "search.example.com"; # hostname for nginx
  nginx = { }; # nginx submodule
  environment = { # upstream environment variables
    DEGOOG_WIZARD = "false";
    DEGOOG_DEFAULT_SEARCH_LANGUAGE = "en-US";
    DEGOOG_PUBLIC_INSTANCE = "true";
    LOG_LEVEL = "info";
  };
  environmentFile = "/run/secrets/degoog.env"; # environment style
  database = { # uses SQLite by default. postgres as alternative:
    type = "postgres";
    createLocally = true;
  };
  cache.createLocally = true; # adds Valkey to degoog, disabled by default
  mcp = { # MCP server
    enabled = true; # disabled by default
    port = 4443; # default
    environment = {
      DEGOOG_MCP_MAX_RESULTS = "10";
      DEGOOG_MCP_ENGINES = "google,brave";
    };
    environmentFile = "/run/secrets/degoog-mcp.env"; # DEGOOG_MCP_AUTH_TOKEN=...
  };
};
```
