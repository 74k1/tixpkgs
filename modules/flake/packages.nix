# Every `pkgs/<xy>/<name>/package.nix` (or `pkgs/<xy>/<name>.nix`) becomes package `<name>`.
{ lib }:
pkgs:
let
  files = builtins.filter (lib.hasSuffix ".nix") (lib.filesystem.listFilesRecursive ../../pkgs);

  nameOf =
    file:
    if baseNameOf file == "package.nix" then
      baseNameOf (dirOf file)
    else
      lib.removeSuffix ".nix" (baseNameOf file);
in
lib.listToAttrs (map (file: lib.nameValuePair (nameOf file) (pkgs.callPackage file { })) files)
