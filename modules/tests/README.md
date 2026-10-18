# Module tests

Tests are discovered recursively from:

- `modules/tests/nixos/<category>/<module-path>/<test>.nix`

`<category>` is either `services` (for `services.*` module tests) or `pkgs`
(for package-level integration tests that don't correspond to a module). The `<module-path>` mirrors the exported module key, for example
`modules/tests/nixos/services/grimmory/basic.nix` tests
`nixosModules."services/grimmory"`.

Generated check names use the path:

```sh
nix build .#checks.x86_64-linux.module-nixos-services-grimmory-basic
```

NixOS test files may return a normal `pkgs.testers.runNixOSTest` attribute set, or a custom derivation.

The flake exports no Home Manager modules and has no `home-manager` input, so
`modules/tests/home-manager` is not discovered. To add Home Manager tests, add
the input and a `homeManagerModules` output to `flake.nix`, and a Home Manager
runner to `modules/flake/checks.nix`.
