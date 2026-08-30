{
  lib,
  module,
  pkgs,
  ...
}:
let
  evalHydroxide =
    cfg:
    import (pkgs.path + "/nixos") {
      inherit (pkgs.stdenv.hostPlatform) system;
      configuration = {
        imports = [ module ];
        services.hydroxide = cfg;
      };
    };

  allEnabled = evalHydroxide {
    enable = true;
    authFile = "/tmp/fake-auth.json";
    serve = {
      smtp = true;
      imap = true;
      carddav = true;
    };
  };

  smtpOnly = evalHydroxide {
    enable = true;
    authFile = "/tmp/fake-auth.json";
    serve.smtp = true;
  };

  customAddrs = evalHydroxide {
    enable = true;
    authFile = "/tmp/fake-auth.json";
    tls = {
      certFile = "/tmp/tls.pem";
      keyFile = "/tmp/tls-key.pem";
    };
    serve = {
      smtp = {
        host = "0.0.0.0";
        port = 587;
      };
      imap = {
        host = "::1";
        port = 10143;
      };
    };
  };

  getExecStart = cfg: cfg.config.systemd.services.hydroxide.serviceConfig.ExecStart;
  getUnit = cfg: cfg.config.systemd.services.hydroxide;

  checks = [
    # All enabled → clean minimal command, no disable/host/port flags.
    {
      assertion =
        let
          start = getExecStart allEnabled;
        in
        !lib.hasInfix "--disable" start
        && !lib.hasInfix "--smtp-host" start
        && !lib.hasInfix "--imap-port" start
        && lib.hasInfix "serve" start;
      message = "All-enabled should emit a minimal serve command.";
    }

    # Flags must precede `serve` (Go's flag package stops at the first
    # non-flag argument); nothing may follow it.
    {
      assertion =
        let
          start = getExecStart allEnabled;
        in
        lib.hasSuffix " serve" start;
      message = "All flags must be passed before the serve subcommand.";
    }

    # SMTP only → imap/carddav disabled, smtp not.
    {
      assertion =
        let
          start = getExecStart smtpOnly;
        in
        lib.hasInfix "--disable-imap" start
        && lib.hasInfix "--disable-carddav" start
        && !lib.hasInfix "--disable-smtp" start;
      message = "SMTP-only must disable imap/carddav only.";
    }

    # Custom host/port overrides and TLS flags appear.
    {
      assertion =
        let
          start = getExecStart customAddrs;
        in
        lib.hasInfix "--smtp-host 0.0.0.0" start
        && lib.hasInfix "--smtp-port 587" start
        && lib.hasInfix "--imap-host ::1" start
        && lib.hasInfix "--imap-port 10143" start
        && lib.hasInfix "--tls-cert /tmp/tls.pem" start
        && lib.hasInfix "--tls-key /tmp/tls-key.pem" start;
      message = "Custom host/port and TLS options must appear in serve args.";
    }

    # Privileged ports require CAP_NET_BIND_SERVICE via ambient capabilities.
    {
      assertion =
        let
          u = getUnit customAddrs;
        in
        u.serviceConfig.AmbientCapabilities == [ "CAP_NET_BIND_SERVICE" ]
        && u.serviceConfig.CapabilityBoundingSet == [ "CAP_NET_BIND_SERVICE" ];
      message = "Binding privileged ports must grant CAP_NET_BIND_SERVICE.";
    }

    # Default ports (1025/1143/8080) are unprivileged → no capability granted.
    {
      assertion =
        let
          u = getUnit allEnabled;
        in
        u.serviceConfig.AmbientCapabilities == [ ] && u.serviceConfig.CapabilityBoundingSet == "";
      message = "Unprivileged ports must not receive CAP_NET_BIND_SERVICE.";
    }

    # Systemd unit: DynamicUser, hardening, XDG_CONFIG_HOME, auth wiring.
    {
      assertion =
        let
          u = getUnit allEnabled;
          preStart = builtins.elemAt u.serviceConfig.ExecStartPre 0;
          scriptBody = builtins.readFile (lib.removePrefix "+" preStart);
        in
        u.serviceConfig.DynamicUser == true
        && u.serviceConfig.StateDirectory == "hydroxide"
        && u.environment.XDG_CONFIG_HOME == "/var/lib/hydroxide"
        && u.serviceConfig.ProtectSystem == "strict"
        && u.serviceConfig.NoNewPrivileges == true
        && u.serviceConfig.Restart == "on-failure"
        && builtins.length u.serviceConfig.ExecStartPre == 1
        # The copy must run as the DynamicUser itself (no "+"), so the copied
        # auth.json stays writable by the service (hydroxide rewrites it on
        # re-auth). It also must not reference nonexistent env vars.
        && !lib.hasPrefix "+" preStart
        && !lib.hasInfix "STATE_DIRECTORY_OWNER" scriptBody
        && !lib.hasInfix "STATE_DIRECTORY_GROUP" scriptBody
        && lib.hasInfix "-m 600" scriptBody
        && lib.hasInfix "CREDENTIALS_DIRECTORY/auth.json" scriptBody
        && lib.hasInfix "/var/lib/hydroxide/hydroxide/auth.json" scriptBody
        && builtins.length u.serviceConfig.LoadCredential >= 1
        && lib.elem "AF_INET" u.serviceConfig.RestrictAddressFamilies
        && lib.elem "AF_UNIX" u.serviceConfig.RestrictAddressFamilies;
      message = "Systemd unit must use DynamicUser, hardening, XDG_CONFIG_HOME, and credential wiring.";
    }
  ];

  failed = builtins.filter (check: !check.assertion) checks;
in
assert lib.assertMsg (failed == [ ]) (
  lib.concatMapStringsSep "\n" (check: "FAIL: ${check.message}") failed
);
pkgs.runCommand "hydroxide-module-eval" { } ''
  echo ok > $out
''
