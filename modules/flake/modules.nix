{
  inputs,
  lib,
  ...
}: {
  flake = let
    modules-base = "${inputs.self.outPath}/modules/nixos";

    # Get all .nix files in ./by-name directories
    nixFiles = lib.filesystem.listFilesRecursive modules-base;

    # Filter to only keep files that match the pattern */${name}.nix
    filteredFiles =
      builtins.filter
      (file: lib.strings.hasSuffix ".nix" file)
      nixFiles;

    # Create an attribute set where the key is the base name (without .nix)
    # and the value is the imported Nix file
    importedModules = lib.foldl' lib.recursiveUpdate {} (
      map
      (file: let
        # Call `unsafeDiscardStringContext` to fix weird dependency issue
        # (because of `lib.filesystem.listFilesRecursive`)
        # "a/b/c.nix" || "a/b/c/default.nix"
        safeFile = builtins.unsafeDiscardStringContext file;
        safeFilePath = /. + safeFile;
        # ["a" "b" "c.nix"] || ["a" "b" "c" "default.nix"]
        parts = (lib.splitString "/" (lib.removePrefix modules-base safeFile));
        # 1 || 2
        offset = if lib.elemAt parts (lib.length parts - 1) == "default.nix" then 2 else 1;
        # ["a" "b"] || ["a" "b"]
        modulePath = lib.sublist 1 (lib.length parts - offset - 1) parts;
        # "c.nix" || "c"
        fileName = lib.elemAt parts (lib.length parts - offset);
        # "c" || "c"
        sanitizedName = lib.strings.removeSuffix ".nix" fileName;
        importedModule = import safeFilePath;
      in lib.setAttrByPath (modulePath ++ [sanitizedName]) ({ pkgs, ... }: {
        imports = [(
          # NOTE: check if module is requesting us to provide it the instanciated
          #       `tixpkgs`-provided set of packages
          if builtins.functionArgs importedModule == { tixpkgs = false; }
          # { tixpkgs }: { pkgs, config, ...}: { ... }
          then importedModule { tixpkgs = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}; }
          # { pkgs, config, ...}: { ... }
          else importedModule
        )];
      }))
      filteredFiles
    );
  in {
    nixosModules' = importedModules;
  };
}
