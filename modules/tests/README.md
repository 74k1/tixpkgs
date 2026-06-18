# Module tests

Tests are discovered recursively from:

- `modules/tests/nixos/<category>/<module-path>/<test>.nix`
- `modules/tests/home-manager/<module-path>/<test>.nix`

For NixOS, `<category>` is either `services` (for `services.*` module tests)
or `pkgs` (for package-level integration tests that don't correspond to a
module). The `<module-path>` mirrors the exported module key, for example
`modules/tests/nixos/services/grimmory/basic.nix` tests
`nixosModules."services/grimmory"`.

Generated check names use the path:

```sh
nix build .#checks.x86_64-linux.module-nixos-services-grimmory-basic
nix build .#checks.x86_64-linux.module-home-manager-programs-waterfox-basic
```

NixOS test files may return a normal `pkgs.testers.runNixOSTest` attribute set, or a custom derivation.
Home Manager test files may return a Home Manager module, a list of modules, `{ modules = [ ... ]; }`, or a custom derivation.
