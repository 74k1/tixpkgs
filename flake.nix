{
  description = "packages & modules for myself";

  nixConfig = {
    extra-substituters = [ "https://tixpkgs.cachix.org" ];
    extra-trusted-public-keys = [ "tixpkgs.cachix.org-1:Q52x6PMD7ZuTC7oRihwp5lP9YaEaYtrfxYkwzEpjSRI=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      {
        withSystem,
        flake-parts-lib,
        ...
      }:
      {
        systems = [
          "aarch64-darwin"
          "aarch64-linux"
          "i686-linux"
          "x86_64-darwin"
          "x86_64-linux"
        ];

        imports = [
          ./modules/flake/packages.nix
          ./modules/flake/modules.nix
          ./modules/flake/checks.nix
        ];

        debug = false;

        perSystem =
          {
            lib,
            pkgs,
            system,
            inputs',
            ...
          }:
          {
            formatter = pkgs.nixfmt-rs;
          };

        flake = {
        };
      }
    );
}
