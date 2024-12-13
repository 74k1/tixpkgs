{
  description = "packages & modules for myself";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({
      withSystem,
      flake-parts-lib,
      ...
    }: {
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      imports = [
        ./modules/flake/packages.nix
        # ./modules/flake/modules.nix
      ];

      debug = true;

      perSystem = {
        lib,
        pkgs,
        system,
        inputs',
        ...
      }: {
      };

      flake = {
      };
    });
}
