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

- Use a `pkgs.waterfox` package compatible with Firefox wrapping, such as the nixpkgs Waterfox package from the upstream PR that provides both `waterfox` and `waterfox-unwrapped`. (like https://github.com/NixOS/nixpkgs/pull/475318)

## Basic Usage

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
