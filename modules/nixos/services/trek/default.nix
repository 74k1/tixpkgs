{ tixpkgs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.trek;

  inherit (lib)
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    optionalAttrs
    optionalString
    types
    ;

  serviceName = "trek";

  nginxVhostOptions =
    import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix"
      {
        inherit config lib;
      };

  nginxEnabled = cfg.nginx != null;

  protocol =
    if nginxEnabled && (cfg.nginx.forceSSL or false || cfg.nginx.enableACME or false) then
      "https"
    else
      "http";
  publicUrl = "${protocol}://${cfg.domain}";
in
{
  meta.maintainers = [ "74k1" ];

  options.services.trek = {
    enable = mkEnableOption "TREK self-hosted travel planner";
    package = mkPackageOption tixpkgs "trek" { };

    domain = mkOption {
      type = types.str;
      description = "Public domain for TREK (e.g. trek.example.com).";
      example = "trek.example.com";
    };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which TREK runs.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which TREK runs.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/${serviceName}";
      description = "Directory for TREK mutable state (SQLite database, uploads, logs).";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for the TREK HTTP server.";
    };

    encryptionKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing the ENCRYPTION_KEY used to encrypt stored secrets
        (API keys, TOTP secrets, OIDC client secret, etc.).
        If not set, TREK auto-generates and persists a key to
        `dataDir/data/.encryption_key` on first start.
        Providing a stable key is recommended so secrets survive data migration.
      '';
      example = "/run/secrets/trek-encryption-key";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional environment file sourced by the TREK service.
        Use this for optional settings such as OIDC credentials, SMTP, or
        admin bootstrap values:
          OIDC_ISSUER, OIDC_CLIENT_ID, OIDC_CLIENT_SECRET,
          ADMIN_EMAIL, ADMIN_PASSWORD,
          SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS,
          APP_URL, DEFAULT_LANGUAGE, LOG_LEVEL, TZ
      '';
      example = "/run/secrets/trek.env";
    };

    nginx = mkOption {
      type = types.nullOr (types.submodule (lib.recursiveUpdate nginxVhostOptions { }));
      default = { };
      example = literalExpression ''
        {
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = ''
        nginx virtual host configuration for TREK.
        Set to null to disable nginx management.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.trek.dataDir must be an absolute path.";
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
      "d ${cfg.dataDir}/data 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/uploads 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.trek = {
      description = "TREK travel planner";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartTriggers = [ cfg.package ];

      environment = {
        NODE_ENV = "production";
        PORT = toString cfg.port;
        APP_URL = publicUrl;
        # Redirect __dirname-relative paths to the writable state directory.
        TREK_DATA_DIR = "${cfg.dataDir}/data";
        TREK_UPLOADS_DIR = "${cfg.dataDir}/uploads";
      };

      script = ''
        ${optionalString (cfg.encryptionKeyFile != null) ''
          export ENCRYPTION_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.encryptionKeyFile})"
        ''}
        ${optionalString (cfg.environmentFile != null) ''
          set -a
          source ${lib.escapeShellArg cfg.environmentFile}
          set +a
        ''}
        exec ${cfg.package}/bin/trek
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        Restart = "on-failure";
        RestartSec = "10s";
        UMask = "0027";
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
        ReadWritePaths = [ cfg.dataDir ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
      };
    };

    services.nginx = mkIf nginxEnabled {
      enable = true;
      recommendedProxySettings = mkDefault true;
      virtualHosts.${cfg.domain} = mkMerge [
        cfg.nginx
        {
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
          };
        }
      ];
    };
  };
}
