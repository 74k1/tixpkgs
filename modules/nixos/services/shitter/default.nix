{ tixpkgs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    optional
    optionalAttrs
    types
    ;

  cfg = config.services.shitter;

  redis = config.services.redis.servers.shitter;

  configFile = pkgs.writeText "shitter.conf" (
    lib.generators.toINI
      {
        # Upstream reads string values only when they are quoted.
        mkKeyValue = lib.generators.mkKeyValueDefault {
          mkValueString =
            v:
            if lib.isString v then
              "\"${lib.escape [ "\"" ] v}\""
            else
              lib.generators.mkValueStringDefault { } v;
        } " = ";
      }
      (
        lib.recursiveUpdate cfg.settings {
          Server = {
            inherit (cfg) address port;
          };
          Config.hmacKey = "@hmac@";
        }
        // optionalAttrs cfg.redisCreateLocally {
          # The package accepts a Unix socket path as the Redis host.
          Cache.redisHost = redis.unixSocket;
        }
      )
  );

  # The HMAC key signs media URLs. It is generated on first start and kept out
  # of the Nix store. The shell substitution keeps it out of process arguments.
  preStart = pkgs.writeShellScript "shitter-pre-start" ''
    umask 077
    if [ ! -s "$STATE_DIRECTORY/hmac" ]; then
      od -An -tx1 -N32 /dev/urandom | tr -d ' \n' > "$STATE_DIRECTORY/hmac"
    fi
    config="$(< ${configFile})"
    printf '%s\n' "''${config//@hmac@/$(< "$STATE_DIRECTORY/hmac")}" > "$STATE_DIRECTORY/shitter.conf"
  '';
in
{
  options.services.shitter = {
    enable = mkEnableOption "Shitter, an alternative Twitter front-end";

    package = mkPackageOption tixpkgs "shitter" { };

    address = mkOption {
      type = types.str;
      default = "0.0.0.0";
      example = "127.0.0.1";
      description = "The address to listen on.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      example = 8000;
      description = "The port to listen on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open ports in the firewall for the Shitter web interface.";
    };

    settings = mkOption {
      type = types.submodule {
        freeformType =
          with types;
          attrsOf (
            attrsOf (oneOf [
              bool
              int
              str
            ])
          );
        options = { };
      };
      default = { };
      example = {
        Server = {
          hostname = "shitter.example.com";
          https = true;
        };
        Preferences.theme = "Nitter";
      };
      description = ''
        Contents of `nitter.conf`, one attribute set for each section.
        See [nitter.example.conf](https://codeberg.org/shitter/shitter/src/branch/master/nitter.example.conf) for available settings.

        The module sets `Server.address`, `Server.port` and `Config.hmacKey`.
        It also sets `Cache.redisHost` when
        {option}`services.shitter.redisCreateLocally` is enabled.
        Values for these keys are ignored here.

        These values are written to the Nix store, so do not put secrets here.
      '';
    };

    sessionsFile = mkOption {
      type = types.path;
      default = "/var/lib/shitter/sessions.jsonl";
      description = ''
        Path to the session tokens file, in JSONL format. Shitter does not
        start without it.

        See [Creating session tokens](https://codeberg.org/shitter/shitter/wiki/Creating-session-tokens).
      '';
    };

    redisCreateLocally = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Configure a local Redis server for Shitter. Shitter connects to it
        through a Unix socket, so the server listens on no TCP port.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.shitter = {
      description = "Shitter (An alternative Twitter front-end)";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ] ++ optional cfg.redisCreateLocally "redis-shitter.service";
      requires = optional cfg.redisCreateLocally "redis-shitter.service";
      environment = {
        NITTER_CONF_FILE = "/var/lib/shitter/shitter.conf";
        NITTER_SESSIONS_FILE = "%d/sessionsFile";
      };
      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "shitter";
        LoadCredential = "sessionsFile:${cfg.sessionsFile}";
        SupplementaryGroups = optional cfg.redisCreateLocally redis.group;
        # Shitter looks for the `public` directory in the working directory.
        WorkingDirectory = "${cfg.package}/share/shitter";
        ExecStartPre = preStart;
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = "5s";

        # Hardening
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateIPC = true;
        PrivateTmp = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "full";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ]
        ++ optional cfg.redisCreateLocally "AF_UNIX";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "~@mount"
          "~@swap"
          "~@resources"
          "~@reboot"
          "~@raw-io"
          "~@obsolete"
          "~@module"
          "~@debug"
          "~@cpu-emulation"
          "~@clock"
          "~@privileged"
        ];
        UMask = "0027";
      }
      // (
        if (cfg.port < 1024) then
          {
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
          }
        else
          {
            # A private user cannot have process capabilities on the host's user
            # namespace and thus CAP_NET_BIND_SERVICE has no effect.
            PrivateUsers = true;
            CapabilityBoundingSet = false;
          }
      );
    };

    services.redis.servers.shitter = mkIf cfg.redisCreateLocally {
      enable = true;
      port = 0;
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };

  meta.maintainers = with lib.maintainers; [ _74k1 ];
}
