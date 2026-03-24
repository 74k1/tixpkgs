> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
> 
> Contributions are always welcome!

# `nixosModules'.services.mcgate`

High-performance, resource-efficient Minecraft reverse proxy and library with robust multi-protocol version support.

## Info

- Project Website: `https://gate.minekube.com`
- Project Source: `https://github.com/minekube/gate`
- Project Docs: `https://gate.minekube.com/guide/`

## Usage

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.mc-gate
    # or
    inputs.tixpkgs.nixosModules."services/mc-gate"
  ];

  services.mc-gate = {
    enable = true;
    config = {
      lite = {
        enabled = true;
        routes = [
          {
            host = "mc.your.domain"; # Your Domain
            backend = "10.0.0.2:25566"; # Your Minecraft Server IP
          }
        ];
      };
    };
  };
}
```

Rebuild and then check it out at https://localhost:1200/ ! :shipit:
