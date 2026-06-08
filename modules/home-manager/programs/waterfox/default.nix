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
    mozilla.firefoxNativeMessagingHosts =
      cfg.nativeMessagingHosts ++ lib.optional (cfg.finalPackage != null) cfg.finalPackage;
  };
}
