<img align="left" src="/.github/assets/tixpkgs_colored.png" width="400px"/>

<div align="right">
    <h3><samp><a href="https://github.com/74k1/tix">tix</a>pkgs</samp> ❄️</h3>
    packages and modules for myself.
</div>

<br>
<br>
<br>

# About

This repository is _my personal_ nixpkgs. Packages and NixOS / Home-Manager modules that aren't upstream.

Nothing fancy, just the stuff I want / use (mostly).

Kept up-to-date by a bot (and occasionally me).

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
| `services.fourget` | [README](modules/nixos/services/fourget/README.md) |
| `services.grimmory` | [README](modules/nixos/services/grimmory/README.md) |
| `services.mc-gate` | [README](modules/nixos/services/mc-gate/README.md) |
| `services.multi-scrobbler` | [README](modules/nixos/services/multi-scrobbler/README.md) |
| `services.rsshub` | [README](modules/nixos/services/rsshub/README.md) |
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
| `arcbrush` | `1.2.0` |
| `brimcap` | `1.18.0` |
| `fogpanther` | `0.7.4` |
| `fourget` | `unstable-2026-05-24` |
| `godap` | `2.10.4` |
| `grimmory` | `3.0.3` |
| `ida-ios-helper` | `1.0.20` |
| `idahelper` | `1.0.18` |
| `logria` | `0.4.2` |
| `m5burner` | `3-beta` |
| `mtkclient` | `5794aba` |
| `multi-scrobbler` | `0.12.2` |
| `outerbase-studio-desktop` | `0.1.29` |
| `rybbit` | `1.6.1` |
| `waterfox` | `6.6.9` |
| `zui` | `1.18.0` |
<!-- END PACKAGES -->

---

> Some packages & modules might not be what you expect, and some might be extremely outdated.
> If something is unmaintained, it simply means I don't use it anymore.
> A PR is very welcome! :)
>
> Also see [Issues](https://github.com/74k1/tixpkgs/issues) and [Pull Requests](https://github.com/74k1/tixpkgs/pulls).
