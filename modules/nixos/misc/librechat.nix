{ config, lib, pkgs, ... }:

let
  cfg = config.services.librechat;
in
{
  options.services.librechat = {
    enable = lib.mkEnableOption "librechat";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.librechat;
      description = "LibreChat package to use";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host to bind to";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3080;
      description = "Port on which LibreChat will listen";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the environment file containing secrets (like API keys)";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      example = lib.literalExpression ''
        {
          ENDPOINTS = "openAI,google,bingAI,gptPlugins";
          REFRESH_TOKEN_EXPIRY = "2592000000"; # 30 days
          REQUEST_TIMEOUT = "120000";
          TITLE_CONVO = "true";
          COOKIE_NAME = "librechat";
          DEBUG_PLUGINS = "true";
        }
      '';
      description = ''
        Settings for LibreChat passed as environment variables.
        Keys should be uppercase with underscores as per LibreChat's configuration.
        
        See all available options at:
        https://www.librechat.ai/docs/configuration/dotenv
      '';
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Create MongoDB database instance locally";
      };

      url = lib.mkOption {
        type = lib.types.str;
        default = "mongodb://localhost:27017/LibreChat";
        description = "MongoDB connection URL";
      };
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open port in firewall for LibreChat";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.librechat = {
      description = "LibreChat AI Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ] ++ lib.optional cfg.database.createLocally "mongodb.service";
      
      environment = {
        HOST = cfg.host;
        PORT = toString cfg.port;
        MONGO_URI = cfg.database.url;
      } // cfg.settings;

      serviceConfig = {
        Type = "simple";
        User = "librechat";
        Group = "librechat";
        EnvironmentFile = cfg.environmentFile;
        WorkingDirectory = "${cfg.package}";
        ExecStart = "${pkgs.nodejs}/bin/node api/server";
        Restart = "always";
        RestartSec = "10";
        
        # Hardening options
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ReadWritePaths = [ "/var/lib/librechat" ];
      };
    };

    services.mongodb = lib.mkIf cfg.database.createLocally {
      enable = true;
      bind_ip = "127.0.0.1";
      enableAuth = false;
    };

    users.users.librechat = {
      isSystemUser = true;
      group = "librechat";
      home = "/var/lib/librechat";
      createHome = true;
    };

    users.groups.librechat = {};

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
