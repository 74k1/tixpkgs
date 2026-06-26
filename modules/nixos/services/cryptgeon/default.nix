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
    getExe
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

  cfg = config.services.cryptgeon;
  serviceName = "cryptgeon";
  redisName = "cryptgeon";
  redisPort = 6379;

  nixpkgsPath =
    if inputs != null then
      "${inputs.nixpkgs}/nixos/modules/services/web-servers/nginx/vhost-options.nix"
    else
      "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix";

  envVars = {
    REDIS = if cfg.redis.createLocally then "redis://127.0.0.1:${toString redisPort}/" else cfg.redis.url;
    LISTEN_ADDR = "${cfg.address}:${toString cfg.port}";
    SIZE_LIMIT = cfg.settings.sizeLimit;
    MAX_VIEWS = toString cfg.settings.maxViews;
    MAX_EXPIRATION = toString cfg.settings.maxExpiration;
    ALLOW_ADVANCED = lib.boolToString cfg.settings.allowAdvanced;
    ALLOW_FILES = lib.boolToString cfg.settings.allowFiles;
    ID_LENGTH = toString cfg.settings.idLength;
    VERBOSITY = cfg.settings.verbosity;
  } // optionalAttrs (cfg.settings.redisPrefix != "") { REDIS_PREFIX = cfg.settings.redisPrefix; }
    // optionalAttrs (cfg.settings.imprintUrl != null) { IMPRINT_URL = cfg.settings.imprintUrl; }
    // optionalAttrs (cfg.settings.imprintHtml != null) { IMPRINT_HTML = cfg.settings.imprintHtml; }
    // optionalAttrs (cfg.settings.themeImage != null) { THEME_IMAGE = cfg.settings.themeImage; }
    // optionalAttrs (cfg.settings.themeText != null) { THEME_TEXT = cfg.settings.themeText; }
    // optionalAttrs (cfg.settings.themePageTitle != null) { THEME_PAGE_TITLE = cfg.settings.themePageTitle; }
    // optionalAttrs (cfg.settings.themeFavicon != null) { THEME_FAVICON = cfg.settings.themeFavicon; }
    // optionalAttrs (!cfg.settings.themeNewNoteNotice) { THEME_NEW_NOTE_NOTICE = "false"; }
    // optionalAttrs (!cfg.settings.themeHomeLink) { THEME_HOME_LINK = "false"; };
in
{
  meta.maintainers = [ "74k1" ];

  options.services.cryptgeon = {
    enable = mkEnableOption "cryptgeon, a secure, open source note & file sharing service inspired by PrivNote";

    package = mkPackageOption tixpkgs "cryptgeon" { };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Address cryptgeon listens on.";
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = "TCP port cryptgeon listens on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the configured cryptgeon port in the firewall.";
    };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which cryptgeon runs.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which cryptgeon runs.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/cryptgeon.env";
      description = ''
        systemd environment file passed to cryptgeon.

        Any environment variable listed in {option}`services.cryptgeon.settings`
        (and theme options) can be set here instead, which keeps secrets out of
        the Nix store. Variables set here take precedence over the Nix-level
        settings.

        ```
        REDIS=redis://my-private-redis:6379
        SIZE_LIMIT=4 MiB
        ```
      '';
    };

    redis = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Run a local Redis instance for cryptgeon.";
      };

      url = mkOption {
        type = types.str;
        default = "redis://127.0.0.1/";
        description = ''
          Redis URL to connect to.

          Ignored when {option}`services.cryptgeon.redis.createLocally` is
          enabled (uses TCP on localhost instead).
        '';
      };
    };

    settings = {
      sizeLimit = mkOption {
        type = types.str;
        default = "1 KiB";
        example = "4 MiB";
        description = "Maximum size for a single note. 512 MiB is the hard limit.";
      };

      maxViews = mkOption {
        type = types.int;
        default = 100;
        description = "Maximum number of views per note.";
      };

      maxExpiration = mkOption {
        type = types.int;
        default = 360;
        description = "Maximum expiration time in minutes (default: 6 hours).";
      };

      allowAdvanced = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Allow users to configure custom expiration and view counts.

          When set to `false`, all notes are one-view only.
        '';
      };

      allowFiles = mkOption {
        type = types.bool;
        default = true;
        description = "Allow file uploads.";
      };

      idLength = mkOption {
        type = types.int;
        default = 32;
        description = "Size of the note ID in bytes. Does not affect encryption strength, only link length.";
      };

      redisPrefix = mkOption {
        type = types.str;
        default = "";
        description = "Optional prefix for all Redis keys. Useful when sharing a Redis instance with other apps.";
      };

      verbosity = mkOption {
        type = types.enum [
          "error"
          "warn"
          "info"
          "debug"
          "trace"
        ];
        default = "warn";
        description = "Log verbosity level.";
      };

      imprintUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://example.com/imprint";
        description = "URL to an imprint/legal notice page. Takes precedence over imprintHtml.";
      };

      imprintHtml = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Raw HTML for the /imprint page. Ignored if imprintUrl is set.";
      };

      themeImage = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://example.com/logo.png";
        description = "Custom image URL to replace the logo. Must be publicly reachable.";
      };

      themeText = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom text to replace the description below the logo.";
      };

      themePageTitle = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom page title.";
      };

      themeFavicon = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://example.com/favicon.ico";
        description = "Custom favicon URL. Must be publicly reachable.";
      };

      themeNewNoteNotice = mkOption {
        type = types.bool;
        default = true;
        description = "Show the notice about notes being stored in memory after creating a new note.";
      };

      themeHomeLink = mkOption {
        type = types.bool;
        default = true;
        description = "Show the /home link in the footer.";
      };
    };

    hostname = mkOption {
      type = types.str;
      default = "localhost";
      example = "notes.example.com";
      description = ''
        Hostname for the nginx virtual host.

        Only used when {option}`services.cryptgeon.nginx` is set.
      '';
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
        nginx virtual host configuration for cryptgeon.
        Set to a non-null value to enable the nginx reverse proxy.
        HTTPS is required — browsers will not support the cryptographic
        functions over plain HTTP.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      users.users = optionalAttrs (cfg.user == serviceName) {
        cryptgeon = {
          description = "cryptgeon service user";
          group = cfg.group;
          isSystemUser = true;
        };
      };

      users.groups = optionalAttrs (cfg.group == serviceName) {
        cryptgeon = { };
      };

      services.redis.servers.cryptgeon = mkIf cfg.redis.createLocally {
        enable = true;
        port = redisPort;
        bind = "127.0.0.1";
        # cryptgeon stores everything in memory; no persistence needed
        save = [ ];
      };

      systemd.services.cryptgeon = {
        description = "cryptgeon note & file sharing service";
        after = [
          "network.target"
        ] ++ optional cfg.redis.createLocally "redis-cryptgeon.service";
        wants = [
          "network.target"
        ] ++ optional cfg.redis.createLocally "redis-cryptgeon.service";
        requiredBy = [ "multi-user.target" ];
        restartTriggers = [ cfg.package ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = "${getExe cfg.package}";
          EnvironmentFile = optional (cfg.environmentFile != null) cfg.environmentFile;
          Environment = lib.mapAttrsToList (name: value: ''${name}="${value}"'') envVars;
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
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          UMask = "0027";
        };
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
            locations."/" = {
              proxyPass = "http://${cfg.address}:${toString cfg.port}";
              recommendedProxySettings = true;
            };
          }
        ];
      };
    })
  ]);
}
