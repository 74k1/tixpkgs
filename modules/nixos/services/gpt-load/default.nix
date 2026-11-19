{ tixpkgs }:
{ config, lib, ... }:
let
  cfg = config.services.gpt-load;
in
{
  options.services.gpt-load = {
    enable = lib.mkEnableOption "the GPT-Load API proxy";
    package = lib.mkPackageOption tixpkgs "gpt-load" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "HTTP port on the loopback interface.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/gpt-load.env";
      description = ''
        Optional systemd environment file for upstream settings such as AUTH_KEY.
        Use a runtime path outside the Nix store. By default GPT-Load generates
        auth.key and encryption.key in /var/lib/gpt-load. Back up encryption.key
        with the database; without it, stored credentials cannot be decrypted.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.gpt-load = { };
    users.users.gpt-load = {
      isSystemUser = true;
      group = "gpt-load";
    };
    systemd.services.gpt-load = {
      description = "GPT-Load API proxy";
      wantedBy = [ "multi-user.target" ];
      environment = {
        HOST = "127.0.0.1";
        PORT = toString cfg.port;
        DATA_DIR = "/var/lib/gpt-load";
      };
      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        User = "gpt-load";
        Group = "gpt-load";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        PrivateTmp = true;
        StateDirectory = "gpt-load";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/gpt-load";
        UMask = "0077";
        CapabilityBoundingSet = "";
        PrivateDevices = true;
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      }
      // lib.optionalAttrs (cfg.environmentFile != null) { EnvironmentFile = cfg.environmentFile; };
    };
  };
}
