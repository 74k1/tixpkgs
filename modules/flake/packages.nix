{
  inputs,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    pkgs-base = "${inputs.self.outPath}/pkgs";

    # Get all .nix files in ./by-name directories
    nixFiles = lib.filesystem.listFilesRecursive pkgs-base;

    # Filter to only keep files that match the pattern */${name}.nix
    filteredFiles =
      builtins.filter
      (file: lib.strings.hasSuffix ".nix" file)
      nixFiles;

    # Create an attribute set where the key is the base name (without .nix)
    # and the value is the imported Nix file
    importedPackages = lib.listToAttrs (
      map
      (file: let
        # Extract the name by getting the last two path components
        parts = lib.splitString "/" file;
        nameDir = lib.elemAt parts (lib.length parts - 2);
        fileName = lib.elemAt parts (lib.length parts - 1);
        # Call `unsafeDiscardStringContext` to fix weird dependency issue
        # (because of `lib.filesystem.listFilesRecursive`)
        fileNameSafe = builtins.unsafeDiscardStringContext "${fileName}";
        filePath = builtins.unsafeDiscardStringContext "${pkgs-base}/${nameDir}/${fileName}";
      in {
        name = lib.strings.removeSuffix ".nix" fileNameSafe;
        value = pkgs.callPackage filePath {};
      })
      filteredFiles
    );
  in {
    packages = importedPackages;
  };
}
