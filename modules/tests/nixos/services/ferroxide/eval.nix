{
  lib,
  module,
  pkgs,
  ...
}:
let
  evalFerroxide =
    cfg:
    import (pkgs.path + "/nixos") {
      inherit (pkgs.stdenv.hostPlatform) system;
      configuration = {
        imports = [ module ];
        services.ferroxide = cfg;
      };
    };

  allEnabled = evalFerroxide {
    enable = true;
    authFile = "/tmp/fake-auth.json";
    serve = {
      smtp = true;
      imap = true;
      carddav = true;
      caldav = true;
    };
  };

  smtpImap = evalFerroxide {
    enable = true;
    authFile = "/tmp/fake-auth.json";
    serve = {
      smtp = true;
      imap = true;
    };
  };

  customAddrs = evalFerroxide {
    enable = true;
    authFile = "/tmp/fake-auth.json";
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

  getExecStart = cfg: cfg.config.systemd.services.ferroxide.serviceConfig.ExecStart;
  getUnit = cfg: cfg.config.systemd.services.ferroxide;

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

    # SMTP+IMAP only → carddav/caldav disabled, smtp/imap not.
    {
      assertion =
        let
          start = getExecStart smtpImap;
        in
        lib.hasInfix "--disable-carddav" start
        && lib.hasInfix "--disable-caldav" start
        && !lib.hasInfix "--disable-smtp" start
        && !lib.hasInfix "--disable-imap" start;
      message = "SMTP+IMAP must disable carddav/caldav only.";
    }

    # Custom host/port overrides appear.
    {
      assertion =
        let
          start = getExecStart customAddrs;
        in
        lib.hasInfix "--smtp-host 0.0.0.0" start
        && lib.hasInfix "--smtp-port 587" start
        && lib.hasInfix "--imap-host ::1" start
        && lib.hasInfix "--imap-port 10143" start;
      message = "Custom host/port must appear in serve args.";
    }

    # Systemd unit: DynamicUser, hardening, auth wiring.
    {
      assertion =
        let
          u = getUnit allEnabled;
          preStart = builtins.elemAt u.serviceConfig.ExecStartPre 0;
          scriptBody = builtins.readFile (lib.removePrefix "+" preStart);
        in
        u.serviceConfig.DynamicUser == true
        && u.serviceConfig.StateDirectory == "ferroxide"
        && u.serviceConfig.ProtectSystem == "strict"
        && u.serviceConfig.NoNewPrivileges == true
        && u.serviceConfig.Restart == "on-failure"
        && builtins.length u.serviceConfig.ExecStartPre == 1
        && lib.hasInfix "CREDENTIALS_DIRECTORY/auth.json" scriptBody
        && builtins.length u.serviceConfig.LoadCredential >= 1
        && lib.elem "AF_INET" u.serviceConfig.RestrictAddressFamilies
        && lib.elem "AF_UNIX" u.serviceConfig.RestrictAddressFamilies;
      message = "Systemd unit must use DynamicUser, hardening, and credential wiring.";
    }
  ];

  failed = builtins.filter (check: !check.assertion) checks;
in
assert lib.assertMsg (failed == [ ]) (
  lib.concatMapStringsSep "\n" (check: "FAIL: ${check.message}") failed
);
pkgs.runCommand "ferroxide-module-eval" { } ''
  echo ok > $out
''
