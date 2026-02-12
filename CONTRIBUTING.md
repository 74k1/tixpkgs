# Contributing

## Code

- Packages go in `pkgs/` using two-letter prefixes: `pkgs/bo/booklore/`, `pkgs/zu/zui.nix`
- Modules go in `modules/nixos/services/<name>/default.nix`
- Verify it builds: `nix build .#package-name`
- If it's already in [nixpkgs](https://search.nixos.org/packages), it doesn't belong here
- One thing per PR. Keep relevant docs up to date

## Commits

[Conventional commits](https://www.conventionalcommits.org/en/v1.0.0/). Scope is the package or module name.

```
feat(godap): init at 2.10.4
feat(waterfox): 6.6.6 -> 6.6.7
fix(nixos/onyx): correct service dependency ordering
```

## Issues

Use the [templates](https://github.com/74k1/tixpkgs/issues/new/choose). Include logs, steps to reproduce, and whatever else saves me from having to ask.

---

\- Tim
