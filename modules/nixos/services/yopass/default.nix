{ tixpkgs, inputs ? null }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe'
    dirOf
    escapeShellArg
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    concatMapStringsSep
    concatStringsSep
    optional
    optionalAttrs
    optionalString
    types
    ;

  cfg = config.services.yopass;
  serviceName = "yopass";
  redisName = "yopass";
  redisSocket = "/run/redis-${redisName}/redis.sock";

  nixpkgsPath =
    if inputs != null
    then "${inputs.nixpkgs}/nixos/modules/services/web-servers/nginx/vhost-options.nix"
    else "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix";

  mkStringFlag = name: value: "--${name}=${escapeShellArg (toString value)}";
  mkBoolFlag = name: value: optionalString value "--${name}";
  mkRepeatFlag = name: values:
    concatMapStringsSep " " (v: "--${name}=${escapeShellArg v}") values;

  cliFlags = concatStringsSep " " (
    [
      (mkStringFlag "address" cfg.address)
      (mkStringFlag "port" cfg.port)
      (mkStringFlag "database" cfg.database.backend)
      (mkStringFlag "max-length" cfg.settings.maxLength)
      (mkStringFlag "default-expiry" cfg.settings.defaultExpiry)
      (mkStringFlag "log-level" cfg.settings.logLevel)
      (mkStringFlag "cors-allow-origin" cfg.settings.corsAllowOrigin)
      (mkStringFlag "cleanup-interval" cfg.settings.cleanupInterval)
      (mkBoolFlag "force-onetime-secrets" cfg.settings.forceOnetimeSecrets)
      (mkBoolFlag "disable-upload" cfg.settings.disableUpload)
      (mkBoolFlag "disable-features" cfg.settings.disableFeatures)
      (mkBoolFlag "no-language-switcher" cfg.settings.noLanguageSwitcher)
      (mkBoolFlag "prefetch-secret" cfg.settings.prefetchSecret)
      (mkBoolFlag "disable-file-cleanup" cfg.settings.disableFileCleanup)
      (mkBoolFlag "read-only" cfg.settings.readOnly)
      (mkStringFlag "max-file-size" cfg.settings.maxFileSize)
    ]
    ++ optional (cfg.database.backend == "memcached")
      (mkStringFlag "memcached" cfg.database.memcached)
    ++ optional (cfg.database.backend == "redis")
      (mkStringFlag "redis" (if cfg.database.createLocally then "unix://${redisSocket}" else cfg.database.redis))
    ++ optional (cfg.publicUrl != null) (mkStringFlag "public-url" cfg.publicUrl)
    ++ optional cfg.metrics.enable (mkStringFlag "metrics-port" cfg.metrics.port)
    ++ optional (cfg.fileStore.enable) (mkStringFlag "file-store" "disk")
    ++ optional (cfg.fileStore.enable) (mkStringFlag "file-store-path" cfg.fileStore.path)
    ++ optional (cfg.tls.certFile != null) (mkStringFlag "tls-cert" cfg.tls.certFile)
    ++ optional (cfg.tls.keyFile != null) (mkStringFlag "tls-key" cfg.tls.keyFile)
    ++ optional (cfg.settings.imprintUrl != null) (mkStringFlag "imprint-url" cfg.settings.imprintUrl)
    ++ optional (cfg.settings.privacyNoticeUrl != null) (mkStringFlag "privacy-notice-url" cfg.settings.privacyNoticeUrl)
    ++ optional (cfg.settings.trustedProxies != [ ]) (mkRepeatFlag "trusted-proxies" cfg.settings.trustedProxies)
    ++ cfg.extraFlags
  );
in
{
  meta.maintainers = [ "74k1" ];

  options.services.yopass = {
    enable = mkEnableOption "Yopass, a secure sharing service for secrets, passwords and files";

    package = mkPackageOption tixpkgs "yopass" { };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--file-store=s3" "--file-store-s3-bucket=my-bucket" ];
      description = ''
        Extra CLI flags appended to the yopass-server invocation.
        Use this for flags not exposed as module options (S3 file store,
        OIDC, license key, branding, audit logging, etc.).
        For secret-based flags, use {option}`services.yopass.environmentFile` instead.
      '';
    };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which yopass runs.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which yopass runs.";
    };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Address yopass-server listens on.";
    };

    port = mkOption {
      type = types.port;
      default = 1337;
      description = "TCP port yopass-server listens on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the configured yopass port in the firewall.";
    };

    publicUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://secrets.example.com";
      description = "Public base URL used in generated secret links.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/yopass.env";
      description = ''
        Optional systemd environment file for yopass secrets.
        Environment variables are prefixed with `YOPASS_` and dashes become underscores
        (e.g. `YOPASS_OIDC_CLIENT_SECRET` maps to `--oidc-client-secret`).
      '';
    };

    database = {
      backend = mkOption {
        type = types.enum [ "memcached" "redis" ];
        default = "memcached";
        description = "Database backend for secret storage. memcached uses TCP only; redis supports unix sockets when running locally.";
      };

      memcached = mkOption {
        type = types.str;
        default = "localhost:11211";
        description = "memcached address. Must be a TCP address (unix sockets not supported by yopass upstream).";
      };

      redis = mkOption {
        type = types.str;
        default = "redis://localhost:6379/0";
        description = "Redis URL. Ignored when {option}`services.yopass.database.createLocally` is enabled (uses unix socket instead).";
      };

      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Run a local memcached or redis instance.";
      };
    };

    fileStore = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Store large files on disk instead of the database backend.";
      };

      path = mkOption {
        type = types.str;
        default = "/var/lib/yopass/files";
        description = "Base path for disk file store.";
      };
    };

    tls = {
      certFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to TLS certificate file. Prefer using nginx for TLS termination.";
      };

      keyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to TLS key file.";
      };
    };

    metrics = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Prometheus metrics endpoint on {option}`services.yopass.metrics.port`.";
      };

      port = mkOption {
        type = types.port;
        default = 9090;
        description = "Port for the metrics HTTP server.";
      };
    };

    settings = {
      maxLength = mkOption {
        type = types.int;
        default = 10000;
        description = "Maximum length of encrypted secret in bytes.";
      };

      maxFileSize = mkOption {
        type = types.str;
        default = "512KB";
        example = "1MB";
        description = "Maximum file upload size. Capped at 1MB without a license key.";
      };

      defaultExpiry = mkOption {
        type = types.enum [ "1h" "1d" "1w" ];
        default = "1h";
        description = "Default expiry time for secrets.";
      };

      logLevel = mkOption {
        type = types.enum [ "debug" "info" "warn" "error" ];
        default = "info";
        description = "Log level.";
      };

      forceOnetimeSecrets = mkOption {
        type = types.bool;
        default = false;
        description = "Reject non one-time secrets from being created.";
      };

      disableUpload = mkOption {
        type = types.bool;
        default = false;
        description = "Disable the /file upload endpoints.";
      };

      disableFeatures = mkOption {
        type = types.bool;
        default = false;
        description = "Disable premium features UI.";
      };

      noLanguageSwitcher = mkOption {
        type = types.bool;
        default = false;
        description = "Disable the language switcher in the UI.";
      };

      prefetchSecret = mkOption {
        type = types.bool;
        default = true;
        description = "Display a notice that the secret might be one-time use.";
      };

      cleanupInterval = mkOption {
        type = types.int;
        default = 60;
        description = "File cleanup interval in seconds.";
      };

      disableFileCleanup = mkOption {
        type = types.bool;
        default = false;
        description = "Disable the file store cleanup goroutine.";
      };

      readOnly = mkOption {
        type = types.bool;
        default = false;
        description = "Disable all secret creation endpoints (retrieval-only mode).";
      };

      trustedProxies = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "10.0.0.0/8" "172.16.0.0/12" ];
        description = "Trusted proxy IP addresses or CIDR blocks for X-Forwarded-For header validation.";
      };

      corsAllowOrigin = mkOption {
        type = types.str;
        default = "*";
        description = "Access-Control-Allow-Origin header value.";
      };

      imprintUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://example.com/imprint";
        description = "URL to imprint/legal notice page.";
      };

      privacyNoticeUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://example.com/privacy";
        description = "URL to privacy notice page.";
      };
    };

    hostname = mkOption {
      type = types.str;
      default = "localhost";
      example = "secrets.example.com";
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
        nginx virtual host configuration for yopass.
        Set to a non-null value to enable the nginx reverse proxy.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      users.users = optionalAttrs (cfg.user == serviceName) {
        yopass = {
          description = "Yopass service user";
          group = cfg.group;
          isSystemUser = true;
        };
      };

      users.groups = optionalAttrs (cfg.group == serviceName) {
        yopass = { };
      };

      services.memcached = mkIf (cfg.database.createLocally && cfg.database.backend == "memcached") {
        enable = true;
        listen = "127.0.0.1";
        maxMemory = 64;
      };

      services.redis.servers.yopass = mkIf (cfg.database.createLocally && cfg.database.backend == "redis") {
        enable = true;
        port = 0;
        unixSocket = redisSocket;
        unixSocketPerm = 660;
      };

      systemd.tmpfiles.rules = mkIf cfg.fileStore.enable [
        "d ${cfg.fileStore.path} 0750 ${cfg.user} ${cfg.group} -"
      ];

      systemd.services.yopass = {
        description = "Yopass secret sharing service";
        after = [ "network.target" ]
          ++ optional (cfg.database.createLocally && cfg.database.backend == "memcached") "memcached.service"
          ++ optional (cfg.database.createLocally && cfg.database.backend == "redis") "redis-yopass.service";
        wants = [ "network.target" ]
          ++ optional (cfg.database.createLocally && cfg.database.backend == "memcached") "memcached.service"
          ++ optional (cfg.database.createLocally && cfg.database.backend == "redis") "redis-yopass.service";
        requiredBy = [ "multi-user.target" ];
        restartTriggers = [ cfg.package ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = "${getExe' cfg.package "yopass-server"} ${cliFlags}";
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
        } // optionalAttrs cfg.fileStore.enable {
          ReadWritePaths = [ cfg.fileStore.path ];
        } // optionalAttrs (cfg.tls.certFile != null || cfg.tls.keyFile != null) {
          ReadWritePaths = builtins.filter (p: p != null) [
            (if cfg.tls.certFile != null then dirOf cfg.tls.certFile else null)
            (if cfg.tls.keyFile != null then dirOf cfg.tls.keyFile else null)
          ];
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
              proxyWebsockets = true;
            };
          }
        ];
      };
    })
  ]);
}