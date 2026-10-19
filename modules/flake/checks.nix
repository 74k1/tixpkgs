{
  self,
  inputs,
  lib,
  pkgs,
  system,
}:
let
  testsRoot = ../tests/nixos;

  testFiles =
    if builtins.pathExists testsRoot then
      builtins.filter (lib.hasSuffix ".nix") (lib.filesystem.listFilesRecursive testsRoot)
    else
      [ ];

  testInfo =
    file:
    let
      parts = lib.path.subpath.components (lib.path.removePrefix testsRoot file);
      testName = lib.removeSuffix ".nix" (lib.last parts);
      moduleParts = lib.init parts;
      moduleName = lib.concatStringsSep "/" moduleParts;
    in
    {
      inherit
        moduleName
        testName
        ;
      checkName = "module-nixos-${lib.concatStringsSep "-" (moduleParts ++ [ testName ])}";
      module = self.nixosModules.${moduleName} or null;
      imported = import file;
    };

  commonArgNames = [
    "checkName"
    "inputs"
    "lib"
    "module"
    "moduleName"
    "pkgs"
    "self"
    "system"
    "testName"
    "tixpkgs"
  ];

  callTest =
    info:
    let
      imported = info.imported;
      functionArgs = if lib.isFunction imported then builtins.functionArgs imported else { };
      isModuleFunction = builtins.hasAttr "config" functionArgs;
      isTestFunction = lib.any (arg: builtins.hasAttr arg functionArgs) commonArgNames;
    in
    if lib.isFunction imported && isTestFunction && !isModuleFunction then
      imported {
        inherit
          inputs
          lib
          pkgs
          self
          system
          ;
        inherit (info)
          checkName
          module
          moduleName
          testName
          ;
        tixpkgs = self.packages.${system};
      }
    else
      imported;

  mkCheck =
    info:
    let
      value = callTest info;
    in
    if lib.isDerivation value then
      value
    else
      pkgs.testers.runNixOSTest (value // { name = value.name or info.checkName; });
in
lib.listToAttrs (
  map (
    file:
    let
      info = testInfo file;
    in
    lib.nameValuePair info.checkName (mkCheck info)
  ) testFiles
)
