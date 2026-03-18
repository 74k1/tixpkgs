# `home-manager.programs.waterfox`

Home Manager module for configuring Waterfox via Home Manager's Firefox module machinery.

It is exported from this flake as `homeManagerModules'.programs.waterfox`.

## Requirements

- Add this flake as an input.
- Make `home-manager` follow the same `nixpkgs` as your system if you use flakes.
- Use a `pkgs.waterfox` package compatible with Firefox wrapping, such as the nixpkgs Waterfox package from the upstream PR that provides both `waterfox` and `waterfox-unwrapped`.

## Import

in your flake.nix

```nix
{
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tixpkgs = {
      url = "github:74k1/tixpkgs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    ...
}
```

## Basic usage

```nix
{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.tixpkgs.homeManagerModules'.programs.waterfox
  ];

  programs.waterfox = {
    enable = true;

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        "browser.startup.homepage" = "https://example.com";
      };
    };
  };
}
```

## Example with custom package and policies

```nix
{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.tixpkgs.homeManagerModules'.programs.waterfox
  ];

  programs.waterfox = {
    enable = true;
    package = inputs.hythera-waterfox.outputs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.waterfox;

    policies.ExtensionSettings = {
      "uBlock0@raymondhill.net" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      };
    };

    profiles.taki = {
      id = 0;
      isDefault = true;
      search.default = "DuckDuckGo";
      search.force = true;
    };
  };
}
```

## Notes

- Waterfox config lives in `~/.waterfox`.
- The option surface follows Home Manager's Firefox-derived browser modules, so profile, search, bookmarks, handlers, extensions, and policy settings work the same way.
