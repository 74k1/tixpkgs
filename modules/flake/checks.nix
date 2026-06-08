{
  self,
  inputs,
  lib,
  ...
}:
{
  perSystem =
    { system, ... }:
    let
      # Keep module checks on the platform the existing modules/packages target.
      # Individual test files can still be fully-fledged NixOS VM tests or
      # custom derivations.
      enabled = system == "x86_64-linux";

      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
        config.allowUnfree = true;
      };

      testsRoot = "${inputs.self.outPath}/modules/tests";

      testFiles =
        kind:
        let
          dir = "${testsRoot}/${kind}";
        in
        if builtins.pathExists dir then
          builtins.filter (file: lib.strings.hasSuffix ".nix" file) (lib.filesystem.listFilesRecursive dir)
        else
          [ ];

      testInfo =
        kind: file:
        let
          safeFile = builtins.unsafeDiscardStringContext file;
          safeFilePath = /. + safeFile;
          relativePath = lib.removePrefix "${testsRoot}/${kind}/" safeFile;
          parts = lib.splitString "/" relativePath;
          testName = lib.removeSuffix ".nix" (lib.last parts);
          moduleParts = lib.init parts;
          moduleName = lib.concatStringsSep "/" moduleParts;
          checkName = "module-${kind}-${lib.concatStringsSep "-" (moduleParts ++ [ testName ])}";
          moduleSet = if kind == "nixos" then self.nixosModules else self.homeManagerModules;
        in
        {
          inherit
            checkName
            kind
            moduleName
            safeFilePath
            testName
            ;
          module = if builtins.hasAttr moduleName moduleSet then moduleSet.${moduleName} else null;
          imported = import safeFilePath;
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

      mkNixosCheck =
        info:
        let
          value = callTest info;
        in
        if lib.isDerivation value then
          value
        else
          pkgs.testers.runNixOSTest (value // { name = value.name or info.checkName; });

      mkHomeManagerCheck =
        info:
        let
          value = callTest info;
          moduleImports = lib.optional (info.module != null) info.module;
          baseModule =
            { lib, ... }:
            {
              home = {
                username = "hm-test";
                homeDirectory = "/home/hm-test";
                stateVersion = lib.mkDefault "25.05";
              };

              manual.manpages.enable = lib.mkDefault false;
              programs.home-manager.enable = lib.mkDefault false;
            };
          normalized =
            if builtins.isAttrs value && value ? modules then
              value
            else
              {
                modules = if builtins.isList value then value else [ value ];
              };
          hm = inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = {
              inherit inputs self;
              tixpkgs = self.packages.${system};
            }
            // (normalized.extraSpecialArgs or { });
            modules = moduleImports ++ [ baseModule ] ++ normalized.modules;
          };
        in
        if lib.isDerivation value then value else hm.activationPackage;

      mkChecksFor =
        kind: mkCheck:
        lib.listToAttrs (
          map (
            file:
            let
              info = testInfo kind file;
            in
            lib.nameValuePair info.checkName (mkCheck info)
          ) (testFiles kind)
        );

      nixosChecks = mkChecksFor "nixos" mkNixosCheck;
      homeManagerChecks = mkChecksFor "home-manager" mkHomeManagerCheck;
    in
    {
      checks = lib.optionalAttrs enabled (
        nixosChecks
        // homeManagerChecks
        // lib.optionalAttrs (nixosChecks ? module-nixos-services-grimmory-setup) {
          # Backwards-compatible name from the old ad-hoc Grimmory VM check.
          grimmory-nixos = nixosChecks.module-nixos-services-grimmory-setup;
        }
      );
    };
}
