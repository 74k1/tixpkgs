{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.librechat;
in {
  options.services.librechat = {
    enable = lib.mkEnableOption "librechat";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3080;
      description = "Port on which LibreChat will listen";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the environment file containing secrets";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "v0.7.6";
      description = "LibreChat version to use";
    };

    # Add MongoDB options
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
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      librechat = {
        image = "ghcr.io/danny-avila/librechat:${cfg.version}";

        environment = {
          HOST = "0.0.0.0";
          PORT = toString cfg.port;
          MONGO_URI = cfg.database.url;
          ENDPOINTS = "openAI,google,bingAI,gptPlugins";
          REFRESH_TOKEN_EXPIRY = toString (1000 * 60 * 60 * 24 * 30); # 30 days
        };

        environmentFiles = [
          cfg.environmentFile
        ];

        ports = [
          "${toString cfg.port}:${toString cfg.port}"
        ];

        extraOptions = [
          "--network=host"
        ];
      };
    };

    services.mongodb = lib.mkIf cfg.database.createLocally {
      enable = true;
      bind_ip = "127.0.0.1";
      # Basic security practices
      enableAuth = false; # Set to true if you want to enable authentication
      # If enableAuth is true, you'll need to set up initial admin user
    };

    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.dockerSocket.enable = true;
    virtualisation.podman.dockerCompat = true;

    networking.firewall = {
      allowedTCPPorts = [cfg.port];
      trustedInterfaces = ["podman0"];
    };
  };
}
