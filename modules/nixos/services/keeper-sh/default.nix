{ tixpkgs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.keeper-sh;

  inherit (lib)
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    optional
    optionalAttrs
    optionals
    optionalString
    types
    ;

  serviceName = "keeper-sh";

  nginxVhostOptions = import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix" {
    inherit config lib;
  };

  databaseActuallyCreateLocally =
    cfg.database.createLocally && cfg.database.host == "/run/postgresql";
  redisActuallyCreateLocally = cfg.redis.createLocally;
  mcpEnabled = cfg.mcp.enable;
  nginxEnabled = cfg.nginx != null;

  protocol =
    if nginxEnabled && (cfg.nginx.forceSSL or false || cfg.nginx.enableACME or false) then
      "https"
    else
      "http";
  publicUrl = "${protocol}://${cfg.domain}";

  databaseUrl =
    if databaseActuallyCreateLocally then
      "postgresql://${cfg.database.user}@/${cfg.database.name}?host=/run/postgresql"
    else
      "postgresql://${cfg.database.user}:$db_pass@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}";

  redisUrl =
    if redisActuallyCreateLocally then
      "unix:///run/redis-${serviceName}/redis.sock"
    else if cfg.redis.passwordFile != null then
      "redis://:$redis_pass@${cfg.redis.host}:${toString cfg.redis.port}"
    else
      "redis://${cfg.redis.host}:${toString cfg.redis.port}";

  appEnv = {
    NODE_ENV = "production";
    BETTER_AUTH_URL = publicUrl;
    TRUSTED_ORIGINS = lib.concatStringsSep "," cfg.corsAllowedOrigins;
  }
  // optionalAttrs mcpEnabled {
    MCP_PUBLIC_URL = "${publicUrl}/mcp";
  };

  envFile = pkgs.writeText "keeper-env" (
    lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name}=${lib.escapeShellArg value}") appEnv)
  );

  withSecrets = text: ''
    set -a
    source ${envFile}
    ${optionalString (cfg.environmentFile != null) "source ${lib.escapeShellArg cfg.environmentFile}"}
    set +a
    ${optionalString (cfg.secretKeyFile != null) ''export BETTER_AUTH_SECRET="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.secretKeyFile})"''}
    ${optionalString (cfg.encryptionKeyFile != null) ''export ENCRYPTION_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.encryptionKeyFile})"''}
    ${optionalString (cfg.database.passwordFile != null) ''db_pass="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.database.passwordFile})"''}
    ${optionalString (cfg.redis.passwordFile != null) ''redis_pass="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.redis.passwordFile})"''}
    export DATABASE_URL="${databaseUrl}"
    export REDIS_URL="${redisUrl}"
    ${text}
  '';

  serviceConfig = {
    User = cfg.user;
    Group = cfg.group;
    WorkingDirectory = cfg.dataDir;
    Restart = "always";
    RestartSec = 10;
    UMask = "0027";
    # Systemd hardening
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    SystemCallArchitectures = "native";
    RestrictRealtime = true;
    MemoryDenyWriteExecute = true;
    ReadWritePaths = [ cfg.dataDir ];
  };

  localDependencyUnits =
    optional redisActuallyCreateLocally "redis-${serviceName}.service"
    ++ optional databaseActuallyCreateLocally "postgresql.target";
in
{
  meta.maintainers = [ "74k1" ];

  options.services.keeper-sh = {
    enable = mkEnableOption "Keeper calendar synchronization platform";
    package = mkPackageOption tixpkgs "keeper-sh" { };

    domain = mkOption {
      type = types.str;
      description = "Public domain for Keeper (e.g. keeper.example.com).";
      example = "keeper.example.com";
    };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which Keeper services run.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which Keeper services run.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/${serviceName}";
      description = "Directory for Keeper mutable state and logs.";
    };

    secretKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the BETTER_AUTH_SECRET (session signing key). Set to null to provide it via environmentFile instead.";
      example = "/run/secrets/keeper-auth-secret";
    };

    encryptionKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the ENCRYPTION_KEY (CalDAV credential encryption). Set to null to provide it via environmentFile instead.";
      example = "/run/secrets/keeper-encryption-key";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional environment file sourced by all Keeper services.
        Use this for provider credentials and other optional settings:
        GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET,
        MICROSOFT_CLIENT_ID, MICROSOFT_CLIENT_SECRET,
        RESEND_API_KEY, etc.
      '';
      example = "/run/secrets/keeper.env";
    };

    corsAllowedOrigins = mkOption {
      type = types.listOf types.str;
      default = [ publicUrl ];
      defaultText = literalExpression ''[ "http(s)://<services.keeper-sh.domain>" ]'';
      description = "Origins allowed for CSRF protection (TRUSTED_ORIGINS).";
    };

    web.port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for the Keeper web frontend.";
    };

    api.port = mkOption {
      type = types.port;
      default = 3001;
      description = "Port for the Keeper API server.";
    };

    mcp = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the Keeper MCP server for AI agent calendar access.";
      };

      port = mkOption {
        type = types.port;
        default = 3002;
        description = "Port for the Keeper MCP server.";
      };
    };

    database = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Configure a local PostgreSQL database for Keeper.";
      };

      host = mkOption {
        type = types.str;
        default = "/run/postgresql";
        example = "db.example.com";
        description = "PostgreSQL host address or Unix socket directory.";
      };

      port = mkOption {
        type = types.nullOr types.port;
        default = if cfg.database.createLocally then null else 5432;
        defaultText = literalExpression "if config.services.keeper-sh.database.createLocally then null else 5432";
        description = "PostgreSQL port. Required for external databases.";
      };

      user = mkOption {
        type = types.str;
        default = serviceName;
        description = "PostgreSQL user for Keeper.";
      };

      name = mkOption {
        type = types.str;
        default = serviceName;
        description = "PostgreSQL database name for Keeper.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "File containing the PostgreSQL password. Required for external databases.";
        example = "/run/secrets/keeper-db-password";
      };
    };

    redis = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Configure a local Redis server for Keeper.";
      };

      host = mkOption {
        type = types.str;
        default = "";
        description = "Redis host address. Only used when createLocally is false.";
        example = "redis.example.com";
      };

      port = mkOption {
        type = types.port;
        default = 6379;
        description = "Redis port. Only used when createLocally is false.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "File containing the Redis password.";
        example = "/run/secrets/keeper-redis-password";
      };
    };

    nginx = mkOption {
      type = types.nullOr (types.submodule nginxVhostOptions);
      default = { };
      example = literalExpression ''
        {
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = ''
        nginx virtual host configuration for Keeper.
        Set to null to disable nginx management.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = lib.hasPrefix "/" cfg.dataDir;
          message = "services.keeper-sh.dataDir must be an absolute path.";
        }
        {
          assertion = databaseActuallyCreateLocally -> cfg.user == cfg.database.user;
          message = "services.keeper-sh.database.user must match services.keeper-sh.user when using local PostgreSQL peer authentication.";
        }
        {
          assertion = !databaseActuallyCreateLocally -> (cfg.database.host != "/run/postgresql" && cfg.database.port != null);
          message = "services.keeper-sh.database.host must not be /run/postgresql and .port must be set for external databases.";
        }
        {
          assertion = !databaseActuallyCreateLocally -> cfg.database.passwordFile != null;
          message = "services.keeper-sh.database.passwordFile is required for external PostgreSQL.";
        }
        {
          assertion = !redisActuallyCreateLocally -> cfg.redis.host != "";
          message = "services.keeper-sh.redis.host must be set when not creating Redis locally.";
        }
        {
          assertion =
            let
              ports = [ cfg.web.port cfg.api.port ] ++ optional mcpEnabled cfg.mcp.port;
            in
            lib.length (lib.unique ports) == lib.length ports;
          message = "services.keeper-sh web, api, and mcp ports must be distinct.";
        }
      ];

      users.users = optionalAttrs (cfg.user == serviceName) {
        ${serviceName} = {
          inherit (cfg) group;
          home = cfg.dataDir;
          isSystemUser = true;
        };
      };

      users.groups = optionalAttrs (cfg.group == serviceName) {
        ${serviceName} = { };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
        "d ${cfg.dataDir}/logs 0750 ${cfg.user} ${cfg.group} - -"
      ];

      services.postgresql = mkIf databaseActuallyCreateLocally {
        enable = true;
        ensureDatabases = [ cfg.database.name ];
        ensureUsers = [
          {
            name = cfg.database.user;
            ensureDBOwnership = true;
            ensureClauses.login = true;
          }
        ];
      };

      services.redis.servers.${serviceName} = mkIf redisActuallyCreateLocally {
        enable = true;
      };

      systemd.services = {
        keeper-sh-migrate = {
          description = "Keeper database migrations";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ] ++ localDependencyUnits;
          requires = localDependencyUnits;
          serviceConfig = serviceConfig // {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "no";
          };
          script = withSecrets ''
            exec ${cfg.package}/bin/keeper-sh-migrate
          '';
        };

        keeper-sh-api = {
          description = "Keeper API server";
          wantedBy = [ "multi-user.target" ];
          after = [ "keeper-sh-migrate.service" ] ++ localDependencyUnits;
          requires = [ "keeper-sh-migrate.service" ] ++ localDependencyUnits;
          serviceConfig = serviceConfig;
          script = withSecrets ''
            export API_PORT=${toString cfg.api.port}
            exec ${cfg.package}/bin/keeper-sh-api
          '';
        };

        keeper-sh-worker = {
          description = "Keeper job worker";
          wantedBy = [ "multi-user.target" ];
          after = [ "keeper-sh-migrate.service" ] ++ localDependencyUnits;
          requires = [ "keeper-sh-migrate.service" ] ++ localDependencyUnits;
          serviceConfig = serviceConfig;
          script = withSecrets ''
            exec ${cfg.package}/bin/keeper-sh-worker
          '';
        };

        keeper-sh-cron = {
          description = "Keeper cron scheduler";
          wantedBy = [ "multi-user.target" ];
          after = [ "keeper-sh-migrate.service" "keeper-sh-worker.service" ] ++ localDependencyUnits;
          requires = [ "keeper-sh-migrate.service" ] ++ localDependencyUnits;
          serviceConfig = serviceConfig;
          script = withSecrets ''
            export WORKER_JOB_QUEUE_ENABLED=true
            exec ${cfg.package}/bin/keeper-sh-cron
          '';
        };

        keeper-sh-web = {
          description = "Keeper web frontend";
          wantedBy = [ "multi-user.target" ];
          after = [ "keeper-sh-api.service" "network.target" ];
          requires = [ "keeper-sh-api.service" ];
          serviceConfig = serviceConfig;
          script = withSecrets ''
            export PORT=${toString cfg.web.port}
            # The web SSR server proxies API calls server-side; point it at
            # the local API.  Client-side requests go through nginx (/api/).
            export VITE_API_URL="http://127.0.0.1:${toString cfg.api.port}"
            ${optionalString mcpEnabled ''export VITE_MCP_URL="http://127.0.0.1:${toString cfg.mcp.port}"''}
            exec ${cfg.package}/bin/keeper-sh-web
          '';
        };
      };
    }

    (mkIf mcpEnabled {
      systemd.services.keeper-sh-mcp = {
        description = "Keeper MCP server";
        wantedBy = [ "multi-user.target" ];
        after = [ "keeper-sh-migrate.service" ] ++ localDependencyUnits;
        requires = [ "keeper-sh-migrate.service" ] ++ localDependencyUnits;
        serviceConfig = serviceConfig;
        script = withSecrets ''
          export MCP_PORT=${toString cfg.mcp.port}
          exec ${cfg.package}/bin/keeper-sh-mcp
        '';
      };
    })

    (mkIf nginxEnabled {
      services.nginx = {
        enable = true;
        recommendedProxySettings = mkDefault true;
        virtualHosts.${cfg.domain} = mkMerge [
          cfg.nginx
          {
            locations = mkMerge [
              {
                # Proxy all web traffic to the Keeper web SSR server.
                "/" = {
                  proxyPass = "http://127.0.0.1:${toString cfg.web.port}";
                  proxyWebsockets = true;
                };
                # API — proxied separately so health checks and direct API
                # clients can bypass the web server.
                "/api/".proxyPass = "http://127.0.0.1:${toString cfg.api.port}";
              }
              (mkIf mcpEnabled {
                "/mcp/" = {
                  proxyPass = "http://127.0.0.1:${toString cfg.mcp.port}";
                  proxyWebsockets = true;
                };
              })
            ];
          }
        ];
      };
    })
  ]);
}
