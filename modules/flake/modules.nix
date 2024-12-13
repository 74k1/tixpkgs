{
  lib,
  config,
  self,
  inputs,
  withSystem,
  ...
}: {
  flake = {
    nixosModules = import "${inputs.self}/modules/nixos";
    homeManagerModules = import "${inputs.self}/modules/home-manager";
  };
}
