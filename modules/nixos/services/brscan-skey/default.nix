{ tixpkgs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.brscan-skey;

  inherit (lib)
    getExe
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    optionalAttrs
    ;
  inherit (lib.types) str;

  configFile = pkgs.writeText "brscan-skey.config" ''
    password=
    IMAGE=${cfg.imageScript}
    OCR=${cfg.ocrScript}
    EMAIL=${cfg.emailScript}
    FILE=${cfg.fileScript}
    SEMID=b
  '';
in
{
  options.services.brscan-skey = {
    enable = mkEnableOption "Brother scan-key-tool daemon";

    package = mkPackageOption tixpkgs "brscan-skey" { };

    user = mkOption {
      type = str;
      default = "brscan-skey";
      description = "User account under which brscan-skey runs.";
    };

    group = mkOption {
      type = str;
      default = "brscan-skey";
      description = "Group under which brscan-skey runs.";
    };

    imageScript = mkOption {
      type = str;
      default = "";
      defaultText = "bash  \${pkgs.brscan-skey}/lib/brscan-skey/script/scantoimage.sh";
      description = "Command to run when the IMAGE scan button is pressed.";
    };

    ocrScript = mkOption {
      type = str;
      default = "";
      defaultText = "bash  \${pkgs.brscan-skey}/lib/brscan-skey/script/scantoocr.sh";
      description = "Command to run when the OCR scan button is pressed.";
    };

    emailScript = mkOption {
      type = str;
      default = "";
      defaultText = "bash  \${pkgs.brscan-skey}/lib/brscan-skey/script/scantoemail.sh";
      description = "Command to run when the EMAIL scan button is pressed.";
    };

    fileScript = mkOption {
      type = str;
      default = "";
      defaultText = "bash  \${pkgs.brscan-skey}/lib/brscan-skey/script/scantofile.sh";
      description = "Command to run when the FILE scan button is pressed.";
    };
  };

  config = mkIf cfg.enable {
    services.brscan-skey = {
      imageScript = mkDefault "bash  ${cfg.package}/lib/brscan-skey/script/scantoimage.sh";
      ocrScript = mkDefault "bash  ${cfg.package}/lib/brscan-skey/script/scantoocr.sh";
      emailScript = mkDefault "bash  ${cfg.package}/lib/brscan-skey/script/scantoemail.sh";
      fileScript = mkDefault "bash  ${cfg.package}/lib/brscan-skey/script/scantofile.sh";
    };

    systemd.services.brscan-skey = {
      description = "Brother scan-key-tool";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${getExe cfg.package} -f";
        ExecStop = "${getExe cfg.package} --terminate";
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = "brscan-skey";
        StateDirectoryMode = "0750";
        WorkingDirectory = "/var/lib/brscan-skey";
        Environment = "HOME=/var/lib/brscan-skey";
      };
    };

    environment.etc."brscan-skey/brscan-skey.config".source = configFile;

    users.users = optionalAttrs (cfg.user == "brscan-skey") {
      brscan-skey = {
        description = "Brother scan-key-tool user";
        group = cfg.group;
        home = "/var/lib/brscan-skey";
        isSystemUser = true;
      };
    };

    users.groups = optionalAttrs (cfg.group == "brscan-skey") {
      brscan-skey = { };
    };
  };
}
