{
  self,
  inputs,
  lib,
  ...
}:

let
  pkgs-base = "${inputs.self.outPath}/pkgs";

  # Get all .nix files in ./by-name directories
  nixFiles = lib.filesystem.listFilesRecursive pkgs-base;

  # Filter to only keep files that match the pattern */${name}.nix
  filteredFiles = builtins.filter (file: lib.strings.hasSuffix ".nix" file) nixFiles;

  # Create an attribute set where the key is the base name (without .nix)
  # and the value is the imported Nix file
  mkImportedPackages =
    pkgs':
    lib.listToAttrs (
      map (
        file:
        let
          # Extract the name by getting the last two path components
          parts = lib.splitString "/" file;
          offset = if lib.elemAt parts (lib.length parts - 1) == "default.nix" then 2 else 1;
          nameDir = lib.elemAt parts (lib.length parts - offset - 1);
          fileName = lib.elemAt parts (lib.length parts - offset);
          # Call `unsafeDiscardStringContext` to fix weird dependency issue
          # (because of `lib.filesystem.listFilesRecursive`)
          fileNameSafe = builtins.unsafeDiscardStringContext "${fileName}";
          filePath = builtins.unsafeDiscardStringContext "${pkgs-base}/${nameDir}/${fileName}";
        in
        {
          name = lib.strings.removeSuffix ".nix" fileNameSafe;
          value = pkgs'.callPackage filePath { };
        }
      ) filteredFiles
    );
in
{
  perSystem =
    { system, ... }:
    let
      pkgs' = import inputs.nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
        config.allowUnfree = true;
      };
    in
    {
      packages =
        (mkImportedPackages pkgs')
        // (with pkgs'; {
          inherit waterfox waterfox-unwrapped;
        });
    };
  flake.overlays.default =
    final: prev:
    mkImportedPackages final
    // {
      waterfox-unwrapped =
        let
          upstream =
            inputs.nixpkgs-waterfox.legacyPackages.${final.stdenv.hostPlatform.system}.waterfox-unwrapped;
        in
        upstream.override {
          fetchFromGitHub =
            args:
            final.fetchgit {
              name = "source";
              url = "https://github.com/${args.owner}/${args.repo}.git";
              inherit (args)
                tag
                hash
                leaveDotGit
                fetchSubmodules
                preFetch
                postFetch
                ;
              netrcPhase = ''
                if [ -n "''${GITHUB_TOKEN:-}" ]; then
                  printf 'machine github.com\nlogin x-access-token\npassword %s\n' "$GITHUB_TOKEN" > netrc
                else
                  : > netrc
                fi
              '';
              netrcImpureEnvVars = [ "GITHUB_TOKEN" ];
            };
        };
      waterfox = final.wrapFirefox final.waterfox-unwrapped { };
    };
}
