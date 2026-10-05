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
    assertions = [
      {
        assertion = cfg.package != null;
        message = ''
          Set the waterfox package explicitly:

            programs.waterfox.package = pkgs.waterfox;
        '';
      }
    ];

    mozilla.firefoxNativeMessagingHosts =
      cfg.nativeMessagingHosts ++ lib.optional (cfg.finalPackage != null) cfg.finalPackage;
  };

  meta.maintainers = with lib.maintainers; [ _74k1 ];
}
