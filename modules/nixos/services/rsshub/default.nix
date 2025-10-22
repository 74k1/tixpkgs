{ tixpkgs }:
{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    mkEnableOption
    mkOption
    mkPackageOption
    optionalAttrs
    ;
  inherit (lib.types)
    bool
    path
    port
    submodule
    str
    ;

  cfg = config.services.rsshub;

  format = pkgs.formats.keyValue { };
  envFile = format.generate "rsshub-env-vars" (
    cfg.environment
    // lib.optionalAttrs cfg.settings.caching.enable {
      CACHE_TYPE = "redis";
      REDIS_URL = "unix://${config.services.redis.servers.rsshub.unixSocket}";
    }
  );
in
{
  meta.maintainers = [ "74k1" ];

  options.services.rsshub = {
    enable = mkEnableOption "RSSHub service";

    package = mkPackageOption pkgs "rsshub" { };

    environmentFile = mkOption {
      type = path;
      description = ''
        Path to an environment file loaded for the RSSHub service.

        This can be used to securely store tokens and secrets outside of the world-readable Nix store.

        Example contents of the file:
        TWITTER_AUTH_TOKEN=0000000000000000000000000000000000000000

        also see [configuration options](https://docs.rsshub.app/guide/) for supported values.
      '';
      default = "/dev/null";
      example = "/var/lib/secrets/pocket-id";
    };

    environment = mkOption {
      default = {
        PORT = 1200;
      };
      description = ''
        Environment variables that will be passed to RSSHub, see [configuration options](https://docs.rsshub.app/guide/) for supported values.
      '';
      type = submodule {
        freeformType = format.type;

        options = {
          PORT = mkOption {
            type = port;
            description = ''
              Specify the PORT for the RSSHub service.
            '';
            default = 1200;
          };
        };
      };
    };

    settings = mkOption {
      type = submodule {
        options = {
          caching = mkOption {
            type = submodule {
              options = {
                enable = mkOption {
                  default = false;
                  description = ''
                    Wether to enable caching through redis.
                    This will override the following environment variables to:

                    `CACHE_TYPE=redis`
                    `REDIS_URL = "unix://''${config.services.redis.servers.rsshub.unixSocket}"`
                  '';
                  example = true;
                  type = bool;
                };
              };
            };
            default = { };
          };
        };
      };
      default = { };
      description = ''
        Some basic settings for RSSHub.
      '';
      example = {
        caching.enable = true;
      };
    };

    dataDir = mkOption {
      type = path;
      default = "/var/lib/rsshub";
      description = ''
        The directory where RSSHub will store its data.
      '';
    };

    user = mkOption {
      type = str;
      default = "rsshub";
      description = "User account under which RSSHub runs.";
    };

    group = mkOption {
      type = str;
      default = "rsshub";
      description = "Group under which RSSHub runs.";
    };

  };

  config = lib.mkIf cfg.enable {
    systemd.services = {
      rsshub = {
        description = "RSSHub is an open source, easy to use, and extensible RSS feed aggregator.";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [
          cfg.package
          cfg.environmentFile
          envFile
        ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          ExecStart = getExe cfg.package;
          Restart = "always";
          EnvironmentFile = [
            cfg.environmentFile
            envFile
          ];

          # TODO: RSSHub Hardening
          # None.. Feel free to open a PR. I'm not yet experienced enough to harden systemd services.
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group}"
    ];

    services.redis.servers.rsshub = lib.mkIf cfg.settings.caching.enable {
      enable = true;
      user = cfg.user;
      port = 0;
    };

    users.users = optionalAttrs (cfg.user == "rsshub") {
      rsshub = {
        description = "RSSHub service user";
        group = cfg.group;
        home = cfg.dataDir;
        isSystemUser = true;
      };
    };
    users.groups = optionalAttrs (cfg.group == "rsshub") {
      rsshub = { };
    };
  };
}
