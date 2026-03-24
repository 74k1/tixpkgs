> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.mcp-outline`

**mcp-outline** is a Model Context Protocol server for interacting with Outline.

## Info

- Project Source: `https://github.com/Vortiago/mcp-outline`
- Project Docs: `https://github.com/Vortiago/mcp-outline/blob/main/docs/configuration.md`

## Usage

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.mcp-outline
    # or
    inputs.tixpkgs.nixosModules."services/mcp-outline"
  ];

  services.mcp-outline = {
    enable = true;

    settings = {
      MCP_TRANSPORT = "streamable-http";
      MCP_HOST = "127.0.0.1";
      MCP_PORT = 3000;
      OUTLINE_API_URL = "https://outline.example.com/api";
    };

    environmentFile = ./mcp-outline.env; # Requires OUTLINE_API_KEY (use agenix / sops-nix)

    # only needed if you want direct network access instead of a reverse proxy
    openFirewall = false;
  };
}
```

Example `mcp-outline.env`:

```env
OUTLINE_API_KEY=your-api-key
```

## Notes

The service must run in `sse` or `streamable-http` mode.

`stdio` is intended for client-spawned local MCP processes and will be rejected by the module.

Most upstream configuration can be passed through `services.mcp-outline.settings` using the original environment variable names. ()

Do not put secrets there; those values are written to the Nix store.
