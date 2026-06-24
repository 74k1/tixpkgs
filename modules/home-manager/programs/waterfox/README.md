> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
>
> Contributions are always welcome!

# `homeManagerModules'.programs.waterfox`

Home Manager module for configuring Waterfox via Home Manager's Firefox module magic.

## Info

- Project Website: `https://www.waterfox.com/`
- Project Source: `https://github.com/BrowserWorks/waterfox`

## Requirements

tixpkgs does not ship a waterfox package. You need to bring your own.
The recommended source is Hythera's nixpkgs fork:

```
inputs.hythera-waterfox.url = "github:Hythera/nixpkgs/pkgs/waterfox/init";
```

See the example below for wiring it up.

## Basic Usage

```nix
{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.tixpkgs.homeManagerModules'.programs.waterfox
    # or
    inputs.tixpkgs.homeManagerModules."programs/waterfox"
  ];

  programs.waterfox = {
    enable = true;
    package = inputs.hythera-waterfox.legacyPackages.${pkgs.stdenv.hostPlatform.system}.waterfox;

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

## Example with policies and more options

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
    package = inputs.hythera-waterfox.legacyPackages.${pkgs.stdenv.hostPlatform.system}.waterfox;

    policies.ExtensionSettings = {
      "uBlock0@raymondhill.net" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      };
    };

    profiles."taki" = {
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
