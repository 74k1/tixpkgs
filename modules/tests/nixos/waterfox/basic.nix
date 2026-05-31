{ self, inputs, lib, pkgs, ... }:
{
  imports = [ (inputs.nixpkgs + "/nixos/tests/firefox.nix") ];
  _module.args.firefoxPackage = pkgs.waterfox;
  name = "waterfox";
}