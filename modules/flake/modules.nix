{
  inputs,
  lib,
  ...
}: {
  flake = let
    mkImportedModules = modulesBase:
      let
        nixFiles = lib.filesystem.listFilesRecursive modulesBase;

        filteredFiles = builtins.filter (file: lib.strings.hasSuffix ".nix" file) nixFiles;

        instantiateModule = importedModule: {pkgs, ...}: let
          functionArgs = builtins.functionArgs importedModule;
          extraArgs =
            lib.optionalAttrs (builtins.hasAttr "inputs" functionArgs) {
              inherit inputs;
            }
            // lib.optionalAttrs (builtins.hasAttr "tixpkgs" functionArgs) {
              tixpkgs = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
            };
        in {
          imports = [
            (if extraArgs != { } then importedModule extraArgs else importedModule)
          ];
        };
      in
      lib.foldl' lib.recursiveUpdate {} (
        map
        (file: let
          safeFile = builtins.unsafeDiscardStringContext file;
          safeFilePath = /. + safeFile;
          parts = lib.splitString "/" (lib.removePrefix modulesBase safeFile);
          offset = if lib.elemAt parts (lib.length parts - 1) == "default.nix" then 2 else 1;
          modulePath = lib.sublist 1 (lib.length parts - offset - 1) parts;
          fileName = lib.elemAt parts (lib.length parts - offset);
          sanitizedName = lib.strings.removeSuffix ".nix" fileName;
          importedModule = import safeFilePath;
        in
          lib.setAttrByPath (modulePath ++ [sanitizedName]) (instantiateModule importedModule))
        filteredFiles
      );

    nixosModulesBase = "${inputs.self.outPath}/modules/nixos";
    homeManagerModulesBase = "${inputs.self.outPath}/modules/home-manager";
  in {
    nixosModules' = mkImportedModules nixosModulesBase;
    homeManagerModules' = mkImportedModules homeManagerModulesBase;
  };
}
