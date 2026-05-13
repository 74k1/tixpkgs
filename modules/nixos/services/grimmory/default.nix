{ tixpkgs, inputs ? null }:
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
    optionalString
    types
    ;

  cfg = config.services.grimmory;

  serviceName = "grimmory";
  stateDir = "/var/lib/${serviceName}";

  pathStringType = types.str // {
    check = value: lib.isString value && lib.types.path.check value;
  };

  secretFileType = types.nullOr pathStringType;

  envVarNameType = types.strMatching "[A-Za-z_][A-Za-z0-9_]*";

  nixpkgsPath =
    if inputs != null then
      "${inputs.nixpkgs}/nixos/modules/services/web-servers/nginx/vhost-options.nix"
    else
      "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix";

  databaseUrl =
    if cfg.database.url != null then
      cfg.database.url
    else
      "jdbc:mariadb://${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}?createDatabaseIfNotExist=true&connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true";

  generatedDatabasePasswordFile = "${stateDir}/database-password";

  localDatabaseSetupScript = pkgs.writeShellScript "grimmory-local-database-setup" ''
    set -euo pipefail

    password_file=${lib.escapeShellArg generatedDatabasePasswordFile}

    ${optionalString (cfg.secretFiles ? DATABASE_PASSWORD) ''
      if [ -z "''${DATABASE_PASSWORD-}" ]; then
        DATABASE_PASSWORD="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.secretFiles.DATABASE_PASSWORD})"
      fi
    ''}

    if [ -z "''${DATABASE_PASSWORD-}" ]; then
      if [ ! -s "$password_file" ]; then
        umask 077
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$password_file")"
        ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 | ${pkgs.coreutils}/bin/tr -dc 'A-Za-z0-9' | ${pkgs.coreutils}/bin/head -c 32 > "$password_file"
        ${pkgs.coreutils}/bin/chown ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} "$password_file"
      fi
      DATABASE_PASSWORD="$(${pkgs.coreutils}/bin/cat "$password_file")"
    fi

    ${pkgs.mariadb}/bin/mariadb <<SQL
    ALTER USER '${cfg.database.user}'@'localhost' IDENTIFIED BY '$DATABASE_PASSWORD';
    FLUSH PRIVILEGES;
    SQL
  '';

  startupScript = pkgs.writeShellScript "grimmory-start" ''
    set -euo pipefail

    ${lib.concatMapAttrsStringSep "\n" (
      key: path: ''
        export ${key}="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg path})"
      ''
    ) cfg.secretFiles}

    if [ -z "''${DATABASE_PASSWORD-}" ] && [ -r ${lib.escapeShellArg generatedDatabasePasswordFile} ]; then
      export DATABASE_PASSWORD="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg generatedDatabasePasswordFile})"
    fi

    # Upstream resolves spring.datasource.password via DATABASE_PASSWORD first,
    # then MYSQL_ROOT_PASSWORD. Ensure an empty password is an explicit value so
    # deployments with an intentionally empty password do not fail placeholder
    # resolution.
    export DATABASE_PASSWORD="''${DATABASE_PASSWORD-}"

    exec ${lib.getExe cfg.package}
  '';
in
{
  options.services.grimmory = {
    enable = mkEnableOption "Grimmory, a self-hosted digital library";

    package = mkPackageOption tixpkgs "grimmory" { };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which Grimmory runs.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which Grimmory runs.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Address Grimmory binds to.";
    };

    port = mkOption {
      type = types.port;
      default = 6060;
      description = "TCP port Grimmory listens on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the configured Grimmory port in the firewall.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "${stateDir}/data";
      description = "Directory for Grimmory application data and libraries.";
    };

    bookdropDir = mkOption {
      type = types.str;
      default = "${stateDir}/bookdrop";
      description = "Directory Grimmory watches for automatically imported books.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        ALLOWED_ORIGINS = "https://books.example.com";
        ROOT_LOG_LEVEL = "WARN";
      };
      description = ''
        Extra environment variables passed to Grimmory.

        Secrets should go in `services.grimmory.environmentFile` or
        `services.grimmory.secretFiles` instead.
      '';
    };

    environmentFile = mkOption {
      type = secretFileType;
      default = null;
      example = "/run/secrets/grimmory.env";
      description = ''
        Optional systemd environment file for Grimmory secrets and settings.

        This file is not copied to the Nix store. For an external database,
        this is a suitable place to define `DATABASE_PASSWORD=...`.
      '';
    };

    secretFiles = mkOption {
      type = types.attrsOf pathStringType;
      default = { };
      example = literalExpression ''
        {
          DATABASE_PASSWORD = "/run/secrets/grimmory-database-password";
        }
      '';
      description = ''
        Attribute set mapping environment variable names to files whose contents
        are exported as those variables before Grimmory starts. The files are not
        copied to the Nix store.
      '';
    };

    settings.maxBodySize = mkOption {
      type = types.str;
      default = "1024M";
      description = "Maximum request body size used by the optional nginx reverse proxy.";
    };

    database = {
      createLocally = mkEnableOption "a local MariaDB database for Grimmory" // {
        default = true;
      };

      name = mkOption {
        type = types.str;
        default = serviceName;
        description = "Name of the Grimmory database.";
      };

      user = mkOption {
        type = types.str;
        default = cfg.user;
        defaultText = literalExpression "config.services.grimmory.user";
        description = "Database user for Grimmory.";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Hostname or address of the MariaDB server when not using a local socket.";
      };

      port = mkOption {
        type = types.port;
        default = 3306;
        description = "Port of the MariaDB server when not using a local socket.";
      };

      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "jdbc:mariadb://db.example.com:3306/grimmory?connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true";
        description = ''
          Full JDBC database URL. When unset, the module builds one from the
          other database options. Local databases use MariaDB's unix socket.
        '';
      };
    };

    hostname = mkOption {
      type = types.str;
      default = "localhost";
      example = "books.example.com";
      description = "Hostname for the optional nginx reverse proxy.";
    };

    nginx = mkOption {
      type = types.nullOr (
        types.submodule (lib.recursiveUpdate (import nixpkgsPath { inherit config lib; }).options { })
      );
      default = null;
      example = literalExpression ''
        {
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = ''
        nginx virtual host configuration for Grimmory.
        Set to a non-null value to enable the nginx reverse proxy.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.secretFiles == lib.filterAttrs (name: _: envVarNameType.check name) cfg.secretFiles;
          message = "services.grimmory.secretFiles attribute names must be valid environment variable names.";
        }
      ];

      systemd.services.grimmory = {
        description = "Grimmory digital library";
        after = [ "network-online.target" ] ++ optional cfg.database.createLocally "mysql.service";
        wants = [ "network-online.target" ];
        requires = optional cfg.database.createLocally "mysql.service";
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [ cfg.package ];

        environment = {
          APP_VERSION = cfg.package.version or "";
          BOOKLORE_DATA_DIR = cfg.dataDir;
          BOOKLORE_BOOKDROP_DIR = cfg.bookdropDir;
          BOOKLORE_PORT = toString cfg.port;
          SERVER_ADDRESS = cfg.host;
          DATABASE_NAME = cfg.database.name;
          DATABASE_USERNAME = cfg.database.user;
          DATABASE_URL = databaseUrl;
        } // cfg.environment;

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = serviceName;
          StateDirectoryMode = "0750";
          WorkingDirectory = stateDir;
          ExecStartPre = optional cfg.database.createLocally "+${localDatabaseSetupScript}";
          ExecStart = startupScript;
          EnvironmentFile = optional (cfg.environmentFile != null) cfg.environmentFile;
          Restart = "on-failure";

          ReadWritePaths = [
            stateDir
            cfg.dataDir
            cfg.bookdropDir
          ];

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

      systemd.tmpfiles.rules = [
        "d ${stateDir} 0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.bookdropDir} 0750 ${cfg.user} ${cfg.group} -"
      ];

      services.mysql = mkIf cfg.database.createLocally {
        enable = true;
        package = mkDefault pkgs.mariadb;
        ensureDatabases = [ cfg.database.name ];
        ensureUsers = [
          {
            name = cfg.database.user;
            ensurePermissions = {
              "${cfg.database.name}.*" = "ALL PRIVILEGES";
            };
          }
        ];
      };

      users.users = optionalAttrs (cfg.user == serviceName) {
        grimmory = {
          description = "Grimmory service user";
          group = cfg.group;
          home = stateDir;
          isSystemUser = true;
        };
      };

      users.groups = optionalAttrs (cfg.group == serviceName) {
        grimmory = { };
      };

      networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;
    }

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
            extraConfig = optionalString (cfg.settings.maxBodySize != null) ''
              client_max_body_size ${cfg.settings.maxBodySize};
            '';

            locations = {
              "/" = {
                proxyPass = "http://${cfg.host}:${toString cfg.port}";
                recommendedProxySettings = true;
              };

              "/ws" = {
                proxyPass = "http://${cfg.host}:${toString cfg.port}/ws";
                recommendedProxySettings = true;
                proxyWebsockets = true;
              };
            };
          }
        ];
      };
    })
  ]);
}
