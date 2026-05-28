{ tixpkgs, inputs ? null }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    getExe'
    literalExpression
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    optional
    optionalAttrs
    optionalString
    types
    ;

  cfg = config.services.rybbit;

  nixpkgsPath = if inputs != null then inputs.nixpkgs else pkgs.path;

  inherit (lib.types)
    bool
    nullOr
    path
    port
    str
    submodule
    ;

  envToKeyValue =
    attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: value:
        "${name}=${
          if builtins.isBool value then
            if value then "true" else "false"
          else if builtins.isNull value then
            ""
          else
            toString value
        }"
      ) (lib.filterAttrs (n: _v: n != "_module") attrs)
    );

  envFile = pkgs.writeText "rybbit-env" (envToKeyValue cfg.environment);
in
{
  meta.maintainers = [ "74k1" ];

  options.services.rybbit = {
    enable = mkEnableOption "Rybbit web analytics service";

    package = mkPackageOption tixpkgs "rybbit" { };

    user = mkOption {
      type = str;
      default = "rybbit";
      description = "User account under which rybbit runs.";
    };

    group = mkOption {
      type = str;
      default = "rybbit";
      description = "Group account under which rybbit runs.";
    };

    dataDir = mkOption {
      type = path;
      default = "/var/lib/rybbit";
      description = "Directory for rybbit runtime state.";
    };

    hostname = mkOption {
      type = str;
      default = "localhost";
      example = "analytics.example.com";
      description = "Hostname to serve rybbit on.";
    };

    clientPort = mkOption {
      type = port;
      default = 3002;
      description = "TCP port the Rybbit web UI listens on.";
    };

    environmentFile = mkOption {
      type = nullOr path;
      default = null;
      description = ''
        Path to an environment file loaded for the rybbit service.
        Use this to securely store secrets outside the Nix store.

        Example contents:
          BETTER_AUTH_SECRET=your-secret-here
          POSTGRES_PASSWORD=your-db-password
          CLICKHOUSE_PASSWORD=your-ch-password
      '';
    };

    environment = mkOption {
      type = submodule {
        freeformType = types.attrsOf types.str;

        options = {
          BETTER_AUTH_SECRET = mkOption {
            type = str;
            default = "";
            description = "Secret key for Better Auth. Required. Generate with: openssl rand -base64 32";
          };

          BASE_URL = mkOption {
            type = str;
            default = "http://localhost:3002";
            description = "Public-facing base URL of the rybbit web UI.";
          };

          CLICKHOUSE_HOST = mkOption {
            type = str;
            default = "http://localhost:8123";
            description = "ClickHouse host URL.";
          };

          CLICKHOUSE_DB = mkOption {
            type = str;
            default = "analytics";
            description = "ClickHouse database name.";
          };

          CLICKHOUSE_USER = mkOption {
            type = str;
            default = "default";
            description = "ClickHouse user.";
          };

          CLICKHOUSE_PASSWORD = mkOption {
            type = str;
            default = "";
            description = "ClickHouse password.";
          };

          POSTGRES_HOST = mkOption {
            type = str;
            default = if cfg.settings.postgresql.createLocally then "/run/postgresql" else "localhost";
            defaultText = literalExpression ''
              if config.services.rybbit.settings.postgresql.createLocally
              then "/run/postgresql"
              else "localhost"
            '';
            description = "PostgreSQL host name/address or Unix socket directory.";
          };

          POSTGRES_PORT = mkOption {
            type = port;
            default = 5432;
            description = "PostgreSQL port.";
          };

          POSTGRES_DB = mkOption {
            type = str;
            default = cfg.user;
            defaultText = literalExpression "config.services.rybbit.user";
            description = "PostgreSQL database name.";
          };

          POSTGRES_USER = mkOption {
            type = str;
            default = cfg.user;
            defaultText = literalExpression "config.services.rybbit.user";
            description = "PostgreSQL user.";
          };

          POSTGRES_PASSWORD = mkOption {
            type = str;
            default = "";
            description = "PostgreSQL password.";
          };

          REDIS_HOST = mkOption {
            type = str;
            default = "localhost";
            description = "Redis host.";
          };

          REDIS_PORT = mkOption {
            type = port;
            default = 6379;
            description = "Redis port.";
          };

          REDIS_PASSWORD = mkOption {
            type = str;
            default = "";
            description = "Redis password.";
          };

          DISABLE_SIGNUP = mkOption {
            type = bool;
            default = false;
            description = "Whether to disable new user signup.";
          };

          DISABLE_TELEMETRY = mkOption {
            type = bool;
            default = true;
            description = "Whether to disable anonymous telemetry.";
          };

          MAPBOX_TOKEN = mkOption {
            type = nullOr str;
            default = null;
            description = "Optional Mapbox token for map visualizations.";
          };

          CLUSTER_WORKERS = mkOption {
            type = types.either types.ints.unsigned (types.enum [ 0 ]);
            default = 0;
            description = "Number of cluster workers. 0 = single-process (recommended with bun).";
          };
        };
      };
      default = { };
      description = "Environment variables passed to the rybbit server.";
    };

    settings = mkOption {
      type = submodule {
        options = {
          postgresql.createLocally = mkOption {
            type = bool;
            default = true;
            description = "Create PostgreSQL database and user locally.";
          };
          clickhouse.createLocally = mkOption {
            type = bool;
            default = true;
            description = "Run a local ClickHouse instance.";
          };
          redis.createLocally = mkOption {
            type = bool;
            default = false;
            description = "Run a local Redis instance. Only needed for uptime monitoring.";
          };
          autoMigrations = mkOption {
            type = bool;
            default = true;
            description = "Run database migrations on startup.";
          };
          puppeteer = {
            enable = mkOption {
              type = bool;
              default = true;
              description = "Enable Chromium for PDF report generation.";
            };
            package = mkOption {
              type = types.package;
              default = pkgs.chromium;
              defaultText = "pkgs.chromium";
              description = "Chromium package for Puppeteer.";
            };
          };
        };
      };
      default = { };
    };

    nginx = mkOption {
      type = nullOr (
        submodule (
          lib.recursiveUpdate
            (import "${nixpkgsPath}/nixos/modules/services/web-servers/nginx/vhost-options.nix" {
              inherit config lib;
            }).options
            { }
        )
      );
      default = null;
      example = lib.literalExpression ''
        {
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = ''
        nginx virtual host configuration for rybbit.
        Set to a non-null value to enable nginx reverse proxy.
        See `services.nginx.virtualHosts` for available options.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.environment.BETTER_AUTH_SECRET != "" || (cfg.environmentFile != null);
        message = "services.rybbit.environment.BETTER_AUTH_SECRET must be set, or provide it via environmentFile.";
      }
      {
        assertion =
          !cfg.settings.postgresql.createLocally
          || cfg.environment.POSTGRES_DB == cfg.environment.POSTGRES_USER;
        message = "services.rybbit.environment.POSTGRES_DB must match POSTGRES_USER when services.rybbit.settings.postgresql.createLocally is enabled.";
      }
    ];

    services.postgresql = mkIf cfg.settings.postgresql.createLocally {
      enable = true;
      ensureDatabases = [ cfg.environment.POSTGRES_DB ];
      ensureUsers = [
        {
          name = cfg.environment.POSTGRES_USER;
          ensureDBOwnership = true;
        }
      ];
    };

    services.clickhouse.enable = cfg.settings.clickhouse.createLocally;

    services.redis.servers.rybbit = mkIf cfg.settings.redis.createLocally {
      enable = true;
      port = cfg.environment.REDIS_PORT;
      bind = "127.0.0.1";
    };

    users.users = optionalAttrs (cfg.user == "rybbit") {
      rybbit = {
        description = "Rybbit service user";
        group = cfg.group;
        isSystemUser = true;
      };
    };

    users.groups = optionalAttrs (cfg.group == "rybbit") {
      rybbit = { };
    };

    systemd.services.rybbit =
      let
        serverDir = "${cfg.package}/share/rybbit-server";
      in
      {
        description = "Rybbit web analytics service";
        after = [
          "network.target"
        ]
        ++ optional cfg.settings.postgresql.createLocally "postgresql.target"
        ++ optional cfg.settings.clickhouse.createLocally "clickhouse.service"
        ++ optional cfg.settings.redis.createLocally "redis-rybbit.service";
        wants = [
          "network.target"
        ]
        ++ optional cfg.settings.postgresql.createLocally "postgresql.target"
        ++ optional cfg.settings.clickhouse.createLocally "clickhouse.service"
        ++ optional cfg.settings.redis.createLocally "redis-rybbit.service";
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [
          cfg.package
          envFile
        ] ++ optional (cfg.environmentFile != null) cfg.environmentFile;

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          Restart = "always";
          RestartSec = "10";
          EnvironmentFile = [ envFile ] ++ optional (cfg.environmentFile != null) cfg.environmentFile;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ cfg.dataDir ];
        };

        environment = optionalAttrs cfg.settings.puppeteer.enable {
          PUPPETEER_EXECUTABLE_PATH = getExe cfg.settings.puppeteer.package;
          PUPPETEER_SKIP_CHROMIUM_DOWNLOAD = "true";
        };

        script = ''
          set -euo pipefail

          export PORT=${toString cfg.clientPort}
          export HOSTNAME=127.0.0.1

          ${getExe' cfg.package "rybbit-server-cluster"} &
          backend_pid=$!

          ${getExe' cfg.package "rybbit-client"} &
          client_pid=$!

          stop_children() {
            kill "$backend_pid" "$client_pid" 2>/dev/null || true
            wait "$backend_pid" "$client_pid" 2>/dev/null || true
          }

          trap stop_children INT TERM EXIT

          wait -n "$backend_pid" "$client_pid"
          status=$?
          stop_children
          exit "$status"
        '';

        preStart = ''
          ${optionalString cfg.settings.clickhouse.createLocally ''
            echo "Ensuring ClickHouse database exists..."
            ${pkgs.coreutils}/bin/env -u CLICKHOUSE_HOST -u CLICKHOUSE_PORT -u CLICKHOUSE_USER -u CLICKHOUSE_PASSWORD \
              ${getExe' config.services.clickhouse.package "clickhouse-client"} \
              --host 127.0.0.1 \
              --query ${lib.escapeShellArg "CREATE DATABASE IF NOT EXISTS ${cfg.environment.CLICKHOUSE_DB}"}
          ''}
          ${optionalString cfg.settings.autoMigrations ''
            echo "Running database migrations..."
            cd ${serverDir}
            ${getExe pkgs.nodejs} node_modules/.bin/drizzle-kit migrate --config drizzle.config.ts
          ''}
        '';
      };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    services.nginx = mkIf (cfg.nginx != null) {
      enable = true;
      virtualHosts.${cfg.hostname} = mkMerge [
        cfg.nginx
        {
          locations = {
            "/api/" = {
              proxyPass = "http://127.0.0.1:3001/api/";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };

            "/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.clientPort}";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
          };
        }
      ];
    };
  };
}
