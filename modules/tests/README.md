# Module tests

Tests are discovered recursively from:

- `modules/tests/nixos/<module-path>/<test>.nix`
- `modules/tests/home-manager/<module-path>/<test>.nix`

The `<module-path>` mirrors the exported module key, for example
`modules/tests/nixos/services/grimmory/setup.nix` tests
`nixosModules."services/grimmory"`.

Generated check names use the path:

```sh
nix build .#checks.x86_64-linux.module-nixos-services-grimmory-setup
nix build .#checks.x86_64-linux.module-home-manager-programs-waterfox-basic
```

NixOS test files may return a normal `pkgs.testers.runNixOSTest` attribute set, or a custom derivation.
Home Manager test files may return a Home Manager module, a list of modules, `{ modules = [ ... ]; }`, or a custom derivation.
