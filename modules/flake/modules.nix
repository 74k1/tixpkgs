{
  self,
  inputs,
  lib,
}:
base:
let
  files = builtins.filter (lib.hasSuffix ".nix") (lib.filesystem.listFilesRecursive base);

  instantiate =
    importedModule:
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      allArgs = {
        inherit
          config
          lib
          pkgs
          options
          inputs
          ;
        tixpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
      };
      neededArgs = builtins.intersectAttrs (builtins.functionArgs importedModule) allArgs;
    in
    {
      imports = [ (if neededArgs != { } then importedModule neededArgs else importedModule) ];
    };

  modules = map (
    file:
    let
      components = lib.path.subpath.components (lib.path.removePrefix base file);
      parts = if lib.last components == "default.nix" then lib.init components else components;
    in
    {
      path = lib.init parts ++ [ (lib.removeSuffix ".nix" (lib.last parts)) ];
      module = instantiate (import file);
    }
  ) files;
in
{
  # { services.a = ...; }
  nested = lib.foldl' lib.recursiveUpdate { } (map (m: lib.setAttrByPath m.path m.module) modules);
  # { "services/a" = ...; }
  flat = lib.listToAttrs (
    map (m: lib.nameValuePair (lib.concatStringsSep "/" m.path) m.module) modules
  );
}
