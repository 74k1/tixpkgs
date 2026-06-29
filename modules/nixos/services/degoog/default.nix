{
  tixpkgs,
  inputs ? null,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
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
    types
    ;

  cfg = config.services.degoog;

  serviceName = "degoog";
  stateDir = "/var/lib/${serviceName}";

  nixpkgsPath = "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix";
in
{
  meta.maintainers = with lib.maintainers; [ _74k1 ];

  options.services.degoog = {
    enable = mkEnableOption ''
      Degoog, a search engine aggregator with a comprehensive plugin/extension system.

      ::: {.warning}
      If you expose this instance to the internet, set
      `DEGOOG_SETTINGS_PASSWORDS` in {option}`services.degoog.environment` (or
      {option}`services.degoog.environmentFile`) to a strong password.
      An unlocked settings page lets anyone install extensions, which runs
      arbitrary code on the server.
      :::
    '';

    package = mkPackageOption tixpkgs "degoog" { };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which Degoog runs.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which Degoog runs.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Address Degoog binds to.";
    };

    port = mkOption {
      type = types.port;
      default = 4444;
      description = "TCP port Degoog listens on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the configured Degoog port in the firewall.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = literalExpression ''
        {
          DEGOOG_PUBLIC_INSTANCE = "true";
          DEGOOG_SETTINGS_PASSWORDS = "changeme";
          LOG_LEVEL = "debug";
        }
      '';
      description = ''
        Environment variables passed to Degoog.

        Secrets should go in {option}`services.degoog.environmentFile` instead.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/degoog.env";
      description = ''
        systemd environment file for Degoog secrets and settings. The file is
        not copied to the Nix store. Contents follow the `KEY=value` format.
      '';
    };

    database = {
      type = mkOption {
        type = types.enum [
          "sqlite3"
          "postgres"
        ];
        default = "sqlite3";
        description = ''
          Database backend for Degoog. `sqlite3` requires no additional
          setup. `postgres` requires either {option}`services.degoog.database.createLocally`
          or an external PostgreSQL instance configured via
          {option}`services.degoog.environment`.
        '';
      };

      createLocally = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to create and configure a local database for Degoog
          automatically. Only applies when
          {option}`services.degoog.database.type` is `postgres`.
        '';
      };

      name = mkOption {
        type = types.str;
        default = serviceName;
        description = "Name of the Degoog database.";
      };

      user = mkOption {
        type = types.str;
        default = cfg.user;
        defaultText = literalExpression "config.services.degoog.user";
        description = "Database user for Degoog.";
      };
    };

    cache.createLocally = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to create and run a local Valkey instance for Degoog search
        result caching. When enabled, the module starts
        `services.redis.servers.degoog` with Valkey over a unix socket (no
        TCP port exposed) and sets `DEGOOG_VALKEY_URL` automatically.
      '';
    };

    mcp = {
      enable = mkEnableOption "the Degoog MCP server sidecar";

      package = mkPackageOption tixpkgs "degoog-mcp" { };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = "Address the MCP server binds to.";
      };

      port = mkOption {
        type = types.port;
        default = 4443;
        description = "TCP port the MCP server listens on.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to open the configured MCP server port in the firewall.";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = literalExpression ''
          {
            DEGOOG_MCP_MAX_RESULTS = "10";
            DEGOOG_MCP_ENGINES = "google,brave";
            DEGOOG_MCP_TIMEOUT = "30s";
          }
        '';
        description = ''
          Extra environment variables passed to the MCP server. The module
          already sets `DEGOOG_MCP_BIND_HOST`, `DEGOOG_MCP_PORT`, and
          `DEGOOG_MCP_DEGOOG_URL` automatically.

          Secrets such as `DEGOOG_MCP_AUTH_TOKEN` or `DEGOOG_MCP_DEGOOG_API_KEY`
          should go in {option}`services.degoog.mcp.environmentFile`.
        '';
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/degoog-mcp.env";
        description = ''
          systemd environment file for MCP server secrets. Not copied to the
          Nix store.
        '';
      };
    };

    hostname = mkOption {
      type = types.str;
      default = "localhost";
      example = "search.example.com";
      description = ''
        Hostname for the nginx virtual host.

        Only used when {option}`services.degoog.nginx` is set.
      '';
    };

    nginx = mkOption {
      type = types.nullOr (
        types.submodule (import nixpkgsPath { inherit config lib; })
      );
      default = null;
      example = literalExpression ''
        {
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = ''
        nginx virtual host configuration for Degoog. Set to a non-null value to
        enable the nginx reverse proxy. See `services.nginx.virtualHosts` for
        available options.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      systemd.services.degoog = {
        description = "Degoog search aggregator";
        after = [ "network.target" ];
        wants = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [ cfg.package ];

        environment = {
          DEGOOG_PORT = toString cfg.port;
          DEGOOG_DATA_DIR = stateDir;
          HOST = cfg.host;
        } // cfg.environment;

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = serviceName;
          StateDirectoryMode = "0750";
          WorkingDirectory = stateDir;
          ExecStartPre = "${pkgs.writeShellScript "degoog-init-data" ''
            set -eu
            for f in aliases.json plugin-settings.json default-engines.json user-settings.json; do
              [ -f "${stateDir}/$f" ] || echo "{}" > "${stateDir}/$f"
            done
            for f in blocklist.json settings-tokens.json; do
              [ -f "${stateDir}/$f" ] || echo "[]" > "${stateDir}/$f"
            done
          ''}";
          ExecStart = "${cfg.package}/bin/degoog";
          EnvironmentFile = optional (cfg.environmentFile != null) cfg.environmentFile;
          Restart = "on-failure";
          RestartSec = "10";

          CapabilityBoundingSet = "";
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
          ReadWritePaths = [ stateDir ];
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          UMask = "0027";
        };
      };

      systemd.tmpfiles.rules = [
        "d ${stateDir} 0750 ${cfg.user} ${cfg.group} -"
        "d ${stateDir}/plugins 0750 ${cfg.user} ${cfg.group} -"
        "d ${stateDir}/themes 0750 ${cfg.user} ${cfg.group} -"
        "d ${stateDir}/engines 0750 ${cfg.user} ${cfg.group} -"
        "d ${stateDir}/autocomplete 0750 ${cfg.user} ${cfg.group} -"
        "d ${stateDir}/transports 0750 ${cfg.user} ${cfg.group} -"
      ];

      users.users = optionalAttrs (cfg.user == serviceName) {
        degoog = {
          description = "Degoog service user";
          group = cfg.group;
          home = stateDir;
          isSystemUser = true;
        };
      };

      users.groups = optionalAttrs (cfg.group == serviceName) {
        degoog = { };
      };

      networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;
    }

    (mkIf (cfg.database.type == "postgres" && cfg.database.createLocally) {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ cfg.database.name ];
        ensureUsers = [
          {
            name = cfg.database.user;
            ensureDBOwnership = true;
          }
        ];
      };

      systemd.services.degoog = {
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
      };
    })

    (mkIf cfg.cache.createLocally {
      services.redis.servers.degoog = {
        enable = true;
        package = pkgs.valkey;
        user = cfg.user;
        port = 0;
      };

      systemd.services.degoog = {
        after = [ "redis-degoog.service" ];
        requires = [ "redis-degoog.service" ];
        environment.DEGOOG_VALKEY_URL = "unix://${config.services.redis.servers.degoog.unixSocket}";
      };
    })

    (mkIf cfg.mcp.enable {
      systemd.services.degoog-mcp = {
        description = "Degoog MCP server";
        after = [
          "network.target"
          "degoog.service"
        ];
        wants = [
          "network.target"
          "degoog.service"
        ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [ cfg.mcp.package ];

        environment = {
          DEGOOG_MCP_BIND_HOST = cfg.mcp.host;
          DEGOOG_MCP_PORT = toString cfg.mcp.port;
          DEGOOG_MCP_DEGOOG_URL = "http://${cfg.host}:${toString cfg.port}";
        } // cfg.mcp.environment;

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = lib.getExe cfg.mcp.package;
          EnvironmentFile = optional (cfg.mcp.environmentFile != null) cfg.mcp.environmentFile;
          Restart = "on-failure";
          RestartSec = "10";

          CapabilityBoundingSet = "";
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
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          UMask = "0027";
        };
      };

      networking.firewall.allowedTCPPorts = optional cfg.mcp.openFirewall cfg.mcp.port;
    })

    (mkIf (cfg.nginx != null) {
      services.nginx = {
        enable = true;
        recommendedProxySettings = mkDefault true;
        recommendedGzipSettings = mkDefault true;
        recommendedOptimisation = mkDefault true;
        recommendedTlsSettings = mkDefault true;

        virtualHosts.${cfg.hostname} = mkMerge [
          cfg.nginx
          {
            locations."/" = {
              proxyPass = "http://${cfg.host}:${toString cfg.port}";
              recommendedProxySettings = true;
              proxyWebsockets = true;
            };
          }
        ];
      };
    })
  ]);
}
