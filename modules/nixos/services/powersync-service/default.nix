{ tixpkgs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.powersync-service;
  serviceName = "powersync-service";

  inherit (lib)
    concatMapStringsSep
    escapeShellArg
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    optionalString
    toJSON
    types
    ;

  pgCfg = cfg.postgresql;

  # base64(secret) for the JWKS `k` of an HS256 key. PowerSync expects `k` to be
  # urlsafe base64 of the raw secret bytes; the app backend signs with the raw
  # secret via POWERSYNC_JWT_SECRET.
  jwtSecretK = builtins.readFile (
    pkgs.runCommandLocal "powersync-jwt-k" { } ''
      printf %s ${escapeShellArg cfg.jwtSecret} | ${pkgs.coreutils}/bin/base64 -w0 > $out
    ''
  );

  pgUri =
    user: password: db:
    # Passwords here are alphanumeric, so no percent-encoding is needed.
    "postgresql://${user}:${password}@${pgCfg.host}:${toString pgCfg.port}/${db}";

  replicationUri = pgUri cfg.postgresql.replicationUser cfg.postgresql.replicationPassword cfg.postgresql.appDatabase;
  storageUri = pgUri cfg.postgresql.storageUser cfg.postgresql.storagePassword cfg.postgresql.storageDatabase;

  # Indent the user's bucket_definitions YAML under `content: |`.
  syncRulesFile = pkgs.writeText "powersync-sync-rules.yaml" cfg.syncRules;

  configFile = pkgs.writeText "powersync-service-config.yaml" ''
    port: ${toString cfg.port}
    migrations:
      disable_auto_migration: false

    replication:
      connections:
        - type: postgresql
          uri: ${replicationUri}
          sslmode: ${pgCfg.sslmode}

    storage:
      type: postgresql
      uri: ${storageUri}
      sslmode: ${pgCfg.sslmode}

    sync_config:
      # Absolute path (writeText store path); the service resolves it as-is.
      path: ${syncRulesFile}

    client_auth:
      audience: ${toJSON cfg.audience}
      jwks:
        keys:
          - kty: oct
            alg: HS256
            kid: ${cfg.jwtKid}
            k: ${jwtSecretK}

    system:
      logging:
        level: ${cfg.logLevel}
        format: json
  '';

  initSql = pkgs.writeText "powersync-postgres-init.sql" ''
    ALTER USER ${pgCfg.adminUser} WITH PASSWORD '${pgCfg.adminPassword}';
    CREATE SCHEMA IF NOT EXISTS "powersync";
    CREATE ROLE ${pgCfg.replicationUser} WITH REPLICATION BYPASSRLS LOGIN PASSWORD '${pgCfg.replicationPassword}';
    GRANT USAGE ON SCHEMA powersync TO ${pgCfg.replicationUser};
    GRANT SELECT ON ALL TABLES IN SCHEMA powersync TO ${pgCfg.replicationUser};
    ALTER DEFAULT PRIVILEGES IN SCHEMA powersync GRANT SELECT ON TABLES TO ${pgCfg.replicationUser};
    CREATE PUBLICATION powersync FOR ALL TABLES;
    CREATE DATABASE ${pgCfg.storageDatabase} OWNER ${pgCfg.adminUser};
  '';
in
{
  meta.maintainers = with lib.maintainers; [ _74k1 ];

  options.services.powersync-service = {
    enable = mkEnableOption "PowerSync sync service";

    package = mkPackageOption tixpkgs "powersync-service" { };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which the PowerSync service runs.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which the PowerSync service runs.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/powersync";
      description = "Directory for PowerSync mutable state.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port the PowerSync API listens on.";
    };

    logLevel = mkOption {
      type = types.enum [
        "silly"
        "debug"
        "verbose"
        "http"
        "info"
        "warn"
        "error"
      ];
      default = "info";
      description = "PowerSync service log level.";
    };

    audience = mkOption {
      type = types.listOf types.str;
      default = [
        "powersync-enterprise"
        "powersync"
      ];
      description = "Accepted JWT audiences.";
    };

    jwtSecret = mkOption {
      type = types.str;
      description = ''
        HS256 JWT secret shared with the app backend. Must match the backend's
        POWERSYNC_JWT_SECRET and be at least 32 characters.
      '';
    };

    jwtKid = mkOption {
      type = types.str;
      description = ''
        JWT key id. Must match the backend's POWERSYNC_JWT_KID.
      '';
    };

    syncRules = mkOption {
      type = types.str;
      default = "";
      description = "YAML `bucket_definitions` for the sync rules (without the leading `bucket_definitions:` key if empty).";
      example = literalExpression ''
        '''
          bucket_definitions:
            user_data:
              data:
                - SELECT * FROM todos WHERE owner_id = auth.user_id()
        '''
      '';
    };

    postgresql = {
      enable = mkEnableOption "managed local PostgreSQL for PowerSync (logical replication + storage DB)";

      package = mkPackageOption pkgs "postgresql" { };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "PostgreSQL host.";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "PostgreSQL port.";
      };

      sslmode = mkOption {
        type = types.enum [
          "disable"
          "verify-ca"
          "verify-full"
        ];
        default = "disable";
        description = "sslmode for replication and storage connections.";
      };

      appDatabase = mkOption {
        type = types.str;
        default = "postgres";
        description = ''
          Database containing the replicated app schema (the `powersync` schema).
        '';
      };

      storageDatabase = mkOption {
        type = types.str;
        default = "powersync_storage";
        description = "Database for PowerSync bucket storage.";
      };

      adminUser = mkOption {
        type = types.str;
        default = "postgres";
        description = "Superuser used to bootstrap and for storage access.";
      };

      adminPassword = mkOption {
        type = types.str;
        description = "Password set for the admin superuser (enables password auth over TCP).";
      };

      replicationUser = mkOption {
        type = types.str;
        default = "powersync_role";
        description = "PostgreSQL replication role used by PowerSync.";
      };

      replicationPassword = mkOption {
        type = types.str;
        description = "Password for the replication role.";
      };

      storageUser = mkOption {
        type = types.str;
        default = "postgres";
        description = "PostgreSQL user for the storage database.";
      };

      storagePassword = mkOption {
        type = types.str;
        default = cfg.postgresql.adminPassword;
        description = "Password for the storage user.";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the PowerSync port in the firewall.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = lib.stringLength cfg.jwtSecret >= 32;
          message = "services.powersync-service.jwtSecret must be at least 32 characters.";
        }
      ];

      services.postgresql = mkIf pgCfg.enable {
        enable = true;
        inherit (pgCfg) package;
        settings = {
          wal_level = "logical";
          max_wal_senders = 10;
          max_replication_slots = 10;
        };
        ensureDatabases = [ pgCfg.appDatabase ];
        initialScript = initSql;
        # Allow password auth over TCP (replication + storage + app all connect via 127.0.0.1)
        authentication = lib.mkAfter ''
          host all all 127.0.0.1/32 scram-sha-256
          host all all ::1/128 scram-sha-256
        '';
      };

      systemd.services.${serviceName} = {
        description = "PowerSync sync service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" "postgresql.service" ];
        wants = [ "network-online.target" ];
        requires = lib.mkIf pgCfg.enable [ "postgresql.service" ];
        restartTriggers = [ cfg.package configFile ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = "${cfg.package}/bin/${serviceName} start -c ${configFile}";
          Restart = "on-failure";
          RestartSec = "5s";
          WorkingDirectory = cfg.stateDir;
          UMask = "0077";
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.stateDir ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
        };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group} - -"
      ];

      users.users = lib.mkIf (cfg.user == serviceName) {
        ${serviceName} = {
          group = cfg.group;
          home = cfg.stateDir;
          isSystemUser = true;
        };
      };

      users.groups = lib.mkIf (cfg.group == serviceName) {
        ${serviceName} = { };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
    }
  ]);
}
