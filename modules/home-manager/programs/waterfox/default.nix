{ inputs, ... }:
{
  config,
  lib,
  ...
}:
let
  modulePath = [
    "programs"
    "waterfox"
  ];

  cfg = config.programs.waterfox;

  mkFirefoxModule = import "${inputs.home-manager}/modules/programs/firefox/mkFirefoxModule.nix";
in
{
  meta.maintainers = [ "74k1" ];

  imports = [
    (mkFirefoxModule {
      inherit modulePath;
      name = "Waterfox";
      wrappedPackageName = "waterfox";
      unwrappedPackageName = "waterfox-unwrapped";

      platforms.linux = {
        configPath = ".waterfox";
      };
      platforms.darwin = {
        configPath = "Library/Application Support/Waterfox";
      };
    })
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = ''
          tixpkgs does not ship a waterfox package.

          Add the Hythera flake to your inputs:

            inputs.hythera-waterfox.url = "github:Hythera/nixpkgs/pkgs/waterfox/init";

          Then set:

            programs.waterfox.package =
              inputs.hythera-waterfox.legacyPackages.''${pkgs.stdenv.hostPlatform.system}.waterfox;
        '';
      }
    ];

    mozilla.firefoxNativeMessagingHosts =
      cfg.nativeMessagingHosts ++ lib.optional (cfg.finalPackage != null) cfg.finalPackage;
  };
}
