<img align="left" src="/.github/assets/tixpkgs_colored.png" width="400px"/>

<div align="right">
    <h3><samp><a href="https://github.com/74k1/tix">tix</a>pkgs</samp> ❄️</h3>
    packages and modules for myself.
</div>

<br>
<br>
<br>

# About

This repository is _my personal_ nixpkgs. It follows quite a lot of the conventional nixpkgs "standards". It's just Nix Packages and NixOS / Home-Manager Modules that aren't upstream because it's just stuff I wanted to quickly try out / use.

Feel free to fork / use this Repository as a template for _your own_ nixpkgs! Do contact me, because I'd like to find & hear from you if you do!

Kept up-to-date by [my bot](https://github.com/74k1/bumpkin) (and occasionally me).

If something's broken or missing, PRs / Issues welcome. See [contributing](./CONTRIBUTING.md).


# Usage

To use this flake in your own setup, make sure to include it in your flake inputs. (also make `home-manager` follow your `nixpkgs`)

In your `flake.nix`:

```nix
{
  inputs = {
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
  };
  outputs = {
    ...
  };
}
```

## Cachix

As long as I'm under 5gb.. I use Cachix. Feel free to use it:

`cachix use tixpkgs`

or add 

```nix
nix.settings = {
  substituters = ["https://tixpkgs.cachix.org"];
  trusted-public-keys = ["tixpkgs.cachix.org-1:Q52x6PMD7ZuTC7oRihwp5lP9YaEaYtrfxYkwzEpjSRI="];
}
```

# Modules

This flake exports modules in two ways:

- via `nixosModules'` or `homeManagerModules'`, which are nested (like `legacyPackages` package sets)

<details>
  <summary>example</summary>

```nix
{
  nixosModules' = {
    services = {
      a = <NixOS module>;
      b = <NixOS module>;
    };
    programs = {
      c = <NixOS module>;
    };
  };
}
```
</details>

- via the classic `nixosModules` or `homeManagerModules`, flat

<details>
  <summary>example</summary>

```nix
{
  nixosModules = {
    "services/a" = <NixOS module>;
    "services/b" = <NixOS module>;
    "programs/c" = <NixOS module>;
  };
}
```
</details>

## NixOS Modules

<!-- BEGIN NIXOS MODULES -->
| Module | Docs |
|---|---|
| `services.brscan-skey` | [README](modules/nixos/services/brscan-skey/README.md) |
| `services.degoog` | [README](modules/nixos/services/degoog/README.md) |
| `services.fourget` | [README](modules/nixos/services/fourget/README.md) |
| `services.grimmory` | [README](modules/nixos/services/grimmory/README.md) |
| `services.hydroxide` | [README](modules/nixos/services/hydroxide/README.md) |
| `services.keeper-sh` | [README](modules/nixos/services/keeper-sh/README.md) |
| `services.mc-gate` | [README](modules/nixos/services/mc-gate/README.md) |
| `services.multi-scrobbler` | [README](modules/nixos/services/multi-scrobbler/README.md) |
| `services.rsshub` | [README](modules/nixos/services/rsshub/README.md) |
| `services.rybbit` | [README](modules/nixos/services/rybbit/README.md) |
| `services.thunderbolt` | [README](modules/nixos/services/thunderbolt/README.md) |
| `services.trek` | [README](modules/nixos/services/trek/README.md) |
| `services.yopass` | [README](modules/nixos/services/yopass/README.md) |
<!-- END NIXOS MODULES -->

## Home Manager Modules

<!-- BEGIN HOME MANAGER MODULES -->
| Module | Docs |
|---|---|
| `programs.waterfox` | [README](modules/home-manager/programs/waterfox/README.md) |
<!-- END HOME MANAGER MODULES -->

# Packages

Packages can be used using `inputs.tixpkgs.packages.${pkgs.stdenv.hostPlatform.system}.<packageName>`. (if it's buildable for your system.)

<!-- BEGIN PACKAGES -->
| Package | Version |
|---|---|
| `arcbrush` | `1.6.3` |
| `brimcap` | `1.18.0` |
| `brscan-skey` | `0.3.5-0` |
| `cadcraft` | `0.4.0` |
| `cadcraft-bin` | `0.4.0` |
| `commet` | `0.5.0` |
| `deckcraft` | `0.3.0` |
| `deckcraft-bin` | `0.4.0` |
| `degoog` | `1.1.0` |
| `degoog-mcp` | `0.4.0` |
| `designcraft` | `0.5.0` |
| `designcraft-bin` | `0.5.0` |
| `effectcraft` | `0.7.0` |
| `effectcraft-bin` | `0.7.0` |
| `ferroxide` | `0.5.0` |
| `filmcraft` | `0.5.0` |
| `filmcraft-bin` | `0.5.0` |
| `fogpanther` | `0.8.2` |
| `fourget` | `unstable-2026-10-10` |
| `g3m` | `3.2.1` |
| `godap` | `2.12.2` |
| `gpd-pocket-4-pipewire` | `0-unstable-2025-04-08` |
| `gridcraft` | `0.4.0` |
| `gridcraft-bin` | `0.4.0` |
| `grimmory` | `3.5.0` |
| `ida-ios-helper` | `1.0.23` |
| `idahelper` | `1.0.18` |
| `keeper-sh` | `2.24.6` |
| `lidarr` | `3.1.6.5078` |
| `lightcraft` | `0.5.0` |
| `lightcraft-bin` | `0.5.0` |
| `logria` | `0.6.0` |
| `m5burner` | `3-beta` |
| `moonlight-qt-fork` | `6.21.46` |
| `mtkclient` | `2.1.4` |
| `multi-scrobbler` | `0.19.2` |
| `outerbase-studio-desktop` | `0.1.29` |
| `parallels-ras-client` | `21.2.27300` |
| `pdfcraft` | `0.4.0` |
| `pdfcraft-bin` | `0.5.0` |
| `photocraft` | `0.5.0` |
| `photocraft-bin` | `0.6.0` |
| `rybbit` | `2.9.1` |
| `soundcraft` | `0.3.0` |
| `soundcraft-bin` | `0.3.0` |
| `thunderbolt` | `0.1.107` |
| `thunderbolt-cli` | `0.1.107` |
| `trek` | `4.3.3` |
| `vectorcraft` | `0.7.0` |
| `vectorcraft-bin` | `0.7.0` |
| `waterfox` | `6.7.5` |
| `waterfox-unwrapped` | `6.7.5` |
| `whowatch` | `1.8.6` |
| `wordcraft` | `0.3.0` |
| `wordcraft-bin` | `0.3.0` |
| `yopass` | `15.0.0` |
| `zui` | `1.18.0` |
<!-- END PACKAGES -->

---

> Some packages & modules might not be what you expect, and some might be extremely outdated.
> If something is unmaintained, it simply means I don't use it anymore.
> A PR is very welcome! :)
>
> Also see [Issues](https://github.com/74k1/tixpkgs/issues) and [Pull Requests](https://github.com/74k1/tixpkgs/pulls).
