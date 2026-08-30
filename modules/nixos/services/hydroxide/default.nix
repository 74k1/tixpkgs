{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    types
    ;

  cfg = config.services.hydroxide;

  serviceName = "hydroxide";
  stateDir = "/var/lib/${serviceName}";
  hydroxideConfigDir = "${stateDir}/${serviceName}";
  authJsonPath = "${hydroxideConfigDir}/auth.json";

  defaultServiceHosts = {
    smtp = "127.0.0.1";
    imap = "127.0.0.1";
    carddav = "127.0.0.1";
  };

  defaultServicePorts = {
    smtp = 1025;
    imap = 1143;
    carddav = 8080;
  };

  normaliseService =
    name: value:
    let
      defaultHost = defaultServiceHosts.${name};
      defaultPort = defaultServicePorts.${name};
    in
    if builtins.isBool value then
      {
        enable = value;
        host = defaultHost;
        port = defaultPort;
      }
    else
      {
        enable = value.enable or true;
        host = value.host or defaultHost;
        port = value.port or defaultPort;
      };

  svc = builtins.mapAttrs normaliseService cfg.serve;

  # CLI flag helpers
  flag =
    name: value: default:
    if value == default then "" else "--${name} ${lib.escapeShellArg (toString value)}";

  flagBool =
    name: cond: default:
    if cond == default then
      ""
    else if cond then
      "--${name}"
    else
      "";

  flagDisable = name: enable: if enable then "" else "--disable-${name}";

  # hydroxide uses Go's `flag` package: all flags must be passed before the
  # `serve` subcommand, otherwise they are silently ignored.
  serveArgs = lib.concatStringsSep " " (
    lib.filter (s: s != "") [
      (flagBool "debug" cfg.debug false)
      (flag "api-endpoint" cfg.apiEndpoint "https://mail.proton.me/api")
      (flag "app-version" cfg.appVersion "Other")
      (flag "tls-cert" cfg.tls.certFile null)
      (flag "tls-key" cfg.tls.keyFile null)
      (flag "tls-client-ca" cfg.tls.clientCAFile null)

      (flagDisable "smtp" svc.smtp.enable)
      (flag "smtp-host" svc.smtp.host defaultServiceHosts.smtp)
      (flag "smtp-port" svc.smtp.port defaultServicePorts.smtp)

      (flagDisable "imap" svc.imap.enable)
      (flag "imap-host" svc.imap.host defaultServiceHosts.imap)
      (flag "imap-port" svc.imap.port defaultServicePorts.imap)

      (flagDisable "carddav" svc.carddav.enable)
      (flag "carddav-host" svc.carddav.host defaultServiceHosts.carddav)
      (flag "carddav-port" svc.carddav.port defaultServicePorts.carddav)
    ]
  );

  copyAuthScript = pkgs.writeShellScript "hydroxide-copy-auth" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg hydroxideConfigDir}
    ${pkgs.coreutils}/bin/install \
      -m 600 \
      -o "$STATE_DIRECTORY_OWNER" \
      -g "$STATE_DIRECTORY_GROUP" \
      "$CREDENTIALS_DIRECTORY/auth.json" \
      ${lib.escapeShellArg authJsonPath}
  '';
in
{
  options.services.hydroxide = {
    enable = mkEnableOption ''
      hydroxide, a third-party, open-source ProtonMail bridge.

      Before enabling, run `hydroxide auth <username>` to generate an
      auth.json file.  Point {option}`services.hydroxide.authFile` to that
      file.
    '';

    package = mkPackageOption pkgs "hydroxide" { };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug logging.";
    };

    authFile = mkOption {
      type = types.path;
      example = "/run/secrets/hydroxide-auth.json";
      description = ''
        Path to the auth.json file obtained by running
        `hydroxide auth `⟨username⟩``.

        This file contains your ProtonMail credentials encrypted with
        the bridge password.  It is copied into the service's state
        directory at startup.
      '';
    };

    apiEndpoint = mkOption {
      type = types.str;
      default = "https://mail.proton.me/api";
      description = "ProtonMail API endpoint.";
    };

    appVersion = mkOption {
      type = types.str;
      default = "Other";
      description = "ProtonMail app version string sent to the API.";
    };

    tls = {
      certFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to TLS certificate for incoming connections.";
      };
      keyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to TLS certificate key for incoming connections.";
      };
      clientCAFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to CA certificate for client verification (mTLS).
          Requires both {option}`services.hydroxide.tls.certFile`
          and {option}`services.hydroxide.tls.keyFile`.
        '';
      };
    };

    serve = {
      smtp = mkOption {
        type = types.either types.bool (
          types.submodule {
            options = {
              enable = mkOption {
                type = types.bool;
                default = true;
                description = "Whether to serve SMTP.";
              };
              host = mkOption {
                type = types.str;
                default = defaultServiceHosts.smtp;
                description = "Address the SMTP server binds to.";
              };
              port = mkOption {
                type = types.port;
                default = defaultServicePorts.smtp;
                description = "Port the SMTP server listens on.";
              };
            };
          }
        );
        default = false;
        description = ''
          SMTP server.  Set to `true` to enable with defaults, or pass
          an attrset for finer control.
        '';
      };

      imap = mkOption {
        type = types.either types.bool (
          types.submodule {
            options = {
              enable = mkOption {
                type = types.bool;
                default = true;
                description = "Whether to serve IMAP.";
              };
              host = mkOption {
                type = types.str;
                default = defaultServiceHosts.imap;
                description = "Address the IMAP server binds to.";
              };
              port = mkOption {
                type = types.port;
                default = defaultServicePorts.imap;
                description = "Port the IMAP server listens on.";
              };
            };
          }
        );
        default = false;
        description = ''
          IMAP server.  Set to `true` to enable with defaults, or pass
          an attrset for finer control.
        '';
      };

      carddav = mkOption {
        type = types.either types.bool (
          types.submodule {
            options = {
              enable = mkOption {
                type = types.bool;
                default = true;
                description = "Whether to serve CardDAV.";
              };
              host = mkOption {
                type = types.str;
                default = defaultServiceHosts.carddav;
                description = "Address the CardDAV server binds to.";
              };
              port = mkOption {
                type = types.port;
                default = defaultServicePorts.carddav;
                description = "Port the CardDAV server listens on.";
              };
            };
          }
        );
        default = false;
        description = ''
          CardDAV server.  Set to `true` to enable with defaults, or
          pass an attrset for finer control.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = svc.smtp.enable || svc.imap.enable || svc.carddav.enable;
        message = ''
          services.hydroxide: at least one of serve.smtp, serve.imap,
          or serve.carddav must be enabled.
        '';
      }
      {
        assertion =
          !(cfg.tls.clientCAFile != null && (cfg.tls.certFile == null || cfg.tls.keyFile == null));
        message = ''
          services.hydroxide.tls.clientCAFile requires both
          services.hydroxide.tls.certFile and
          services.hydroxide.tls.keyFile to be set.
        '';
      }
    ];

    systemd.services.hydroxide = {
      description = "hydroxide ProtonMail bridge";
      documentation = [ "https://codeberg.org/emersion/hydroxide" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ cfg.package ];

      environment.XDG_CONFIG_HOME = stateDir;

      serviceConfig = {
        Type = "simple";

        DynamicUser = true;

        StateDirectory = serviceName;
        StateDirectoryMode = "0750";

        WorkingDirectory = stateDir;

        LoadCredential = [ "auth.json:${cfg.authFile}" ];

        ExecStartPre = [ "+${copyAuthScript}" ];

        # hydroxide parses flags with Go's `flag` package, which stops at the
        # first non-flag argument: they must all precede `serve`.
        ExecStart = "${getExe cfg.package} ${serveArgs} serve";

        Restart = "on-failure";
        RestartSec = "10s";

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
        UMask = "0077";
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ _74k1 ];
}
