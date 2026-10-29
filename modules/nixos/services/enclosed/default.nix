{ tixpkgs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.enclosed;

  inherit (lib)
    boolToString
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

  serviceName = "enclosed";

  nginxVhostOptions =
    import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix"
      {
        inherit config lib;
      };

  nginxEnabled = cfg.nginx != null;
in
{
  meta.maintainers = with lib.maintainers; [ _74k1 ];

  options.services.enclosed = {
    enable = mkEnableOption "Enclosed, a self-hosted end-to-end encrypted note service";

    package = mkPackageOption tixpkgs "enclosed" { };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which Enclosed runs.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which Enclosed runs.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/${serviceName}";
      description = "Directory for Enclosed mutable state (encrypted notes and attachments).";
    };

    port = mkOption {
      type = types.port;
      default = 8787;
      description = ''
        TCP port for the Enclosed HTTP server. Enclosed listens on all
        interfaces; use {option}`services.enclosed.nginx` or the firewall to
        restrict access.
      '';
    };

    domain = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Public domain for Enclosed. Required when `nginx` is set.";
      example = "notes.example.com";
    };

    publicBaseApiUrl = mkOption {
      type = types.str;
      default = "/";
      description = ''
        Base URL the client uses for API requests, either absolute
        (`https://example.com/enclosed`) or a path (`/enclosed`).
        Change this when Enclosed is served from a subpath.
      '';
      example = "/enclosed";
    };

    authenticationRequired = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether creating and reading notes requires authentication.
        Set `AUTHENTICATION_USERS` and `AUTHENTICATION_JWT_SECRET` through
        {option}`services.enclosed.environmentFile` (or
        {option}`services.enclosed.jwtSecretFile`) before enabling this.
      '';
    };

    jwtSecretFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing the JWT signing secret. Upstream falls back to the
        literal string `change-me`, so set this whenever authentication is
        enabled.

        The file is loaded as a systemd credential, so systemd reads it as
        root before the sandbox starts. It does not need to be readable by the
        `enclosed` user.
      '';
      example = "/run/secrets/enclosed-jwt-secret";
    };

    usersFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing `AUTHENTICATION_USERS`: a comma-separated list of
        `email:bcrypt-hash` pairs. Generate the hashes with the
        [key generator](https://docs.enclosed.cc/self-hosting/users-authentication-key-generator).

        Upstream reads this value from the environment only, so pass it as a
        file here. The file is loaded as a systemd credential and read as
        root, which makes it usable with agenix or sops-nix secrets.
      '';
      example = "/run/secrets/enclosed-users";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File with additional environment variables, in systemd
        `EnvironmentFile` format (`KEY=value`, one per line, no shell syntax).
        Systemd reads it as root before the sandbox starts.

        Use it for the remaining upstream settings that are not module
        options: `SERVER_CORS_ORIGINS`, `PUBLIC_DEFAULT_NOTE_TTL_SECONDS`,
        `NOTES_MAX_ENCRYPTED_PAYLOAD_LENGTH`, `TASK_DELETE_EXPIRED_NOTES_CRON`,
        `AUTHENTICATION_USERS`, `AUTHENTICATION_JWT_SECRET`.
      '';
      example = "/run/secrets/enclosed.env";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables passed to Enclosed. Overrides the generated defaults.";
      example = literalExpression ''
        {
          PUBLIC_DEFAULT_NOTE_TTL_SECONDS = "86400";
        }
      '';
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
        nginx virtual host configuration for Enclosed.
        Set to a non-null value to enable the nginx reverse proxy.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the Enclosed port in the firewall.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !nginxEnabled || cfg.domain != null;
        message = "services.enclosed.domain must be set when services.enclosed.nginx is enabled.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.enclosed.dataDir must be an absolute path.";
      }
    ];

    warnings =
      optional
        (cfg.authenticationRequired && cfg.usersFile == null && !(cfg.environment ? AUTHENTICATION_USERS))
        "services.enclosed: authenticationRequired is enabled, but no users are configured. Set services.enclosed.usersFile, or AUTHENTICATION_USERS through environmentFile."
      ++
        optional
          (
            cfg.authenticationRequired
            && cfg.jwtSecretFile == null
            && !(cfg.environment ? AUTHENTICATION_JWT_SECRET)
          )
          "services.enclosed: authenticationRequired is enabled, but AUTHENTICATION_JWT_SECRET is not set. Enclosed falls back to the public default secret 'change-me'.";

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
    ];

    systemd.services.enclosed = {
      description = "Enclosed end-to-end encrypted note service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartTriggers = [ cfg.package ];

      environment = {
        NODE_ENV = "production";
        PORT = toString cfg.port;
        STORAGE_DRIVER_FS_LITE_PATH = "${cfg.dataDir}/data";
        PUBLIC_BASE_API_URL = cfg.publicBaseApiUrl;
        PUBLIC_IS_AUTHENTICATION_REQUIRED = boolToString cfg.authenticationRequired;
      }
      // cfg.environment;

      script = ''
        ${optionalString (cfg.jwtSecretFile != null) ''
          export AUTHENTICATION_JWT_SECRET="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/jwt-secret")"
        ''}
        ${optionalString (cfg.usersFile != null) ''
          export AUTHENTICATION_USERS="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/users")"
        ''}
        exec ${lib.getExe cfg.package}
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        # The server resolves its `public/` directory relative to the working
        # directory, so it has to start in the package's share directory.
        WorkingDirectory = "${cfg.package}/share/enclosed";

        # Systemd reads both files as root before the sandbox starts, so
        # secrets do not need to be readable by the service user.
        EnvironmentFile = optional (cfg.environmentFile != null) cfg.environmentFile;
        LoadCredential =
          optional (cfg.jwtSecretFile != null) "jwt-secret:${cfg.jwtSecretFile}"
          ++ optional (cfg.usersFile != null) "users:${cfg.usersFile}";

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
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        # V8 compiles JavaScript into executable memory, so
        # MemoryDenyWriteExecute cannot be enabled.
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    services.nginx = mkIf nginxEnabled {
      enable = true;
      recommendedProxySettings = mkDefault true;
      virtualHosts.${cfg.domain} = mkMerge [
        cfg.nginx
        {
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
          };
        }
      ];
    };
  };
}
