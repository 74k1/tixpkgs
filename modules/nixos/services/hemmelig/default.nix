{ tixpkgs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hemmelig;

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

  serviceName = "hemmelig";

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
  publicUrl = cfg.baseUrl or "${protocol}://${cfg.domain}";
in
{
  meta.maintainers = [ "74k1" ];

  options.services.hemmelig = {
    enable = mkEnableOption "Hemmelig encrypted secret sharing";

    package = mkPackageOption tixpkgs "hemmelig" { };

    domain = mkOption {
      type = types.str;
      description = "Public domain for Hemmelig (e.g. secrets.example.com).";
      example = "secrets.example.com";
    };

    baseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Public base URL of the instance (used for OAuth redirects, cookie handling).
        Defaults to the protocol + domain derived from the nginx configuration.
      '';
      example = "https://secrets.example.com";
    };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which Hemmelig runs.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which Hemmelig runs.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/${serviceName}";
      description = "Directory for Hemmelig mutable state (database, uploads).";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for the Hemmelig HTTP server.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        IP address Hemmelig binds to. Defaults to localhost so the service is not
        accidentally exposed on the network. Set to "0.0.0.0" if you need to
        reach it directly without a reverse proxy.
      '';
    };

    authSecretFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing the BETTER_AUTH_SECRET used to sign authentication
        sessions. Must be at least 32 characters. If not set, a random secret
        is auto-generated and persisted to `stateDir/auth-secret` on first
        start.
      '';
      example = "/run/secrets/hemmelig-auth-secret";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional environment file sourced by the Hemmelig service.
        Use this for optional settings such as OAuth credentials,
        instance branding, or rate limiting:
          HEMMELIG_AUTH_GITHUB_ID, HEMMELIG_AUTH_GITHUB_SECRET,
          HEMMELIG_ALLOW_REGISTRATION, HEMMELIG_INSTANCE_NAME,
          HEMMELIG_ENABLE_RATE_LIMITING
      '';
      example = "/run/secrets/hemmelig.env";
    };

    nginx = mkOption {
      type = types.nullOr (types.submodule (lib.recursiveUpdate nginxVhostOptions { }));
      default = null;
      example = literalExpression ''
        {
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = ''
        nginx virtual host configuration for Hemmelig.
        Set to a non-null value to enable the nginx reverse proxy.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.stateDir;
        message = "services.hemmelig.stateDir must be an absolute path.";
      }
    ];

    users.users = optionalAttrs (cfg.user == serviceName) {
      ${serviceName} = {
        inherit (cfg) group;
        home = cfg.stateDir;
        isSystemUser = true;
      };
    };

    users.groups = optionalAttrs (cfg.group == serviceName) {
      ${serviceName} = { };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.stateDir}/database 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.stateDir}/uploads 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.hemmelig = {
      description = "Hemmelig encrypted secret sharing";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartTriggers = [ cfg.package ];

      environment = {
        NODE_ENV = "production";
        HEMMELIG_PORT = toString cfg.port;
        DATABASE_URL = "file:${cfg.stateDir}/database/hemmelig.db";
        BETTER_AUTH_URL = publicUrl;
      };

      script = ''
        ${optionalString (cfg.authSecretFile != null) ''
          export BETTER_AUTH_SECRET="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.authSecretFile})"
        ''}
        ${optionalString (cfg.authSecretFile == null) ''
          auth_secret_file="${cfg.stateDir}/auth-secret"
          if [ ! -f "$auth_secret_file" ]; then
            umask 077
            ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 > "$auth_secret_file"
            ${pkgs.coreutils}/bin/chown ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} "$auth_secret_file"
          fi
          export BETTER_AUTH_SECRET="$(${pkgs.coreutils}/bin/cat "$auth_secret_file")"
        ''}
        ${optionalString (cfg.environmentFile != null) ''
          set -a
          source ${lib.escapeShellArg cfg.environmentFile}
          set +a
        ''}

        # Run prisma migrations before starting the server.
        # Runs as the service user so database files get correct ownership.
        ${lib.getExe pkgs.nodejs_24} \
          ${cfg.package}/libexec/hemmelig/node_modules/.bin/prisma \
          migrate deploy \
          --schema ${cfg.package}/libexec/hemmelig/prisma/schema.prisma

        exec ${cfg.package}/bin/hemmelig
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
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
        ReadWritePaths = [ cfg.stateDir ];
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
            proxyPass = "http://${cfg.host}:${toString cfg.port}";
            proxyWebsockets = true;
          };
        }
      ];
    };
  };
}
