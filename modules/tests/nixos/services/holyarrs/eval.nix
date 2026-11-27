{
  inputs,
  lib,
  module,
  pkgs,
  self,
  system,
  ...
}:
let
  evalHolyArrs =
    holyarrsConfig:
    import (inputs.nixpkgs + "/nixos") {
      inherit system;
      configuration = {
        imports = [ module ];
        nixpkgs.overlays = [ self.overlays.default ];
        system.stateVersion = "26.05";
        services.holyarrs = holyarrsConfig;
      };
    };

  minimal = evalHolyArrs { enable = true; };

  full = evalHolyArrs {
    enable = true;
    address = "::";
    port = 8080;
    openFirewall = true;
    urlBase = "/holyarrs";
    allowedHosts = [
      "holyarrs.example.test"
      "media.example.test"
    ];
    trustedProxies = [
      "127.0.0.1"
      "10.0.0.0/8"
    ];
    mediaDirs = [
      "/srv/media"
      "/srv/downloads"
    ];
    savePath = "/srv/downloads";
    umask = "0002";
    updateCheck = false;
    ownerName = "admin";
    ownerPasswordFile = "/run/secrets/holyarrs-owner-password";
    apiKeyFile = "/run/secrets/holyarrs-api-key";
    apiKeyScopes = [
      "read"
      "write"
    ];
    masterKeyFile = "/run/secrets/holyarrs-master-key";
    metadata = {
      mode = "own";
      tmdbKeyFile = "/run/secrets/holyarrs-tmdb-key";
    };
    oidc = {
      enable = true;
      issuer = "https://auth.example.test/";
      clientId = "holyarrs";
      clientSecretFile = "/run/secrets/holyarrs-oidc-client-secret";
      redirectUrl = "https://holyarrs.example.test/holyarrs/api/v1/auth/oidc/callback";
      groupsClaim = "groups";
      groupRoles = {
        admins = "admin";
        family = "member";
      };
    };
    forwardAuth = {
      enable = true;
      issuer = "https://proxy.example.test";
      trustedPeers = [ "127.0.0.1" ];
    };
    environmentFile = "/run/secrets/holyarrs.env";
    environment = {
      HOLYARRS_FOLLOW_LINKS = "1";
      HOLYARRS_SAVE_PATH = "/srv/override";
    };
  };

  settingsSso = evalHolyArrs {
    enable = true;
    oidc.allowLocalNetwork = true;
  };

  ownerWithoutPassword = evalHolyArrs {
    enable = true;
    ownerName = "admin";
  };

  cfg = minimal.config;
  fullCfg = full.config;
  settingsSsoCfg = settingsSso.config;

  service = cfg.systemd.services.holyarrs;
  fullService = fullCfg.systemd.services.holyarrs;
  fullEnv = fullService.environment;

  # The bare configurations also fail the file system and boot loader assertions.
  failedAssertions =
    config:
    lib.filter (lib.hasPrefix "services.holyarrs") (
      map (a: a.message) (lib.filter (a: !a.assertion) config.assertions)
    );

  checks = [
    {
      assertion = cfg.services.holyarrs.package.pname == "holyarrs";
      message = "HolyArrs module should default to the tixpkgs holyarrs package.";
    }
    {
      assertion = lib.hasSuffix "/bin/holyarrs -config /var/lib/holyarrs -addr 127.0.0.1:6262" service.serviceConfig.ExecStart;
      message = "holyarrs service should listen on localhost port 6262 with the default config folder.";
    }
    {
      assertion = service.serviceConfig.Restart == "on-failure";
      message = "holyarrs service should restart on failure, so a shut down from the controls stays down.";
    }
    {
      assertion = service.serviceConfig.LoadCredential == [ ];
      message = "holyarrs service should load no credentials by default.";
    }
    {
      assertion = !(service.environment ? HOLYARRS_OIDC_ENABLED);
      message = "holyarrs service should leave single sign-on to Settings by default.";
    }
    {
      assertion = !(lib.elem 6262 cfg.networking.firewall.allowedTCPPorts);
      message = "HolyArrs module should not open the firewall by default.";
    }
    {
      assertion = failedAssertions cfg == [ ];
      message = "Minimal HolyArrs config should pass all assertions.";
    }
    {
      assertion = lib.hasSuffix "-addr [::]:8080" fullService.serviceConfig.ExecStart;
      message = "holyarrs service should put an IPv6 address in brackets.";
    }
    {
      assertion = lib.elem 8080 fullCfg.networking.firewall.allowedTCPPorts;
      message = "HolyArrs module should open the configured port when openFirewall is set.";
    }
    {
      assertion =
        fullService.serviceConfig.ReadWritePaths == [
          "/var/lib/holyarrs"
          "/srv/media"
          "/srv/downloads"
        ];
      message = "holyarrs service should make the config folder and mediaDirs writable.";
    }
    {
      assertion = fullService.serviceConfig.UMask == "0002";
      message = "holyarrs service should use the configured umask.";
    }
    {
      assertion =
        lib.sort lib.lessThan fullService.serviceConfig.LoadCredential == [
          "api-key:/run/secrets/holyarrs-api-key"
          "master-key:/run/secrets/holyarrs-master-key"
          "oidc-client-secret:/run/secrets/holyarrs-oidc-client-secret"
          "owner-password:/run/secrets/holyarrs-owner-password"
          "tmdb-key:/run/secrets/holyarrs-tmdb-key"
        ];
      message = "holyarrs service should load every secret file as a credential.";
    }
    {
      assertion =
        fullEnv.HOLYARRS_OWNER_PASSWORD_FILE == "%d/owner-password"
        && fullEnv.HOLYARRS_API_KEY_FILE == "%d/api-key"
        && fullEnv.HOLYARRS_MASTER_KEY_FILE == "%d/master-key"
        && fullEnv.HOLYARRS_OIDC_CLIENT_SECRET_FILE == "%d/oidc-client-secret"
        && fullEnv.FILE__HOLYARRS_TMDB_KEY == "%d/tmdb-key";
      message = "holyarrs service should point the file variables at the credentials.";
    }
    {
      assertion =
        fullEnv.HOLYARRS_ALLOWED_HOSTS == "holyarrs.example.test,media.example.test"
        && fullEnv.HOLYARRS_TRUSTED_PROXIES == "127.0.0.1,10.0.0.0/8"
        && fullEnv.HOLYARRS_API_KEY_SCOPES == "read,write";
      message = "holyarrs service should join list options with commas.";
    }
    {
      assertion =
        fullEnv.HOLYARRS_URL_BASE == "/holyarrs"
        && fullEnv.HOLYARRS_UPDATE_CHECK == "off"
        && fullEnv.HOLYARRS_METADATA_MODE == "own"
        && fullEnv.HOLYARRS_OWNER_NAME == "admin";
      message = "holyarrs service should pass the plain options as variables.";
    }
    {
      assertion =
        fullEnv.HOLYARRS_OIDC_ENABLED == "true"
        && fullEnv.HOLYARRS_OIDC_ALLOW_JOIN == "false"
        && fullEnv.HOLYARRS_OIDC_GROUPS_CLAIM == "groups"
        && fullEnv.HOLYARRS_OIDC_GROUP_ROLES == "admins=admin,family=member"
        && !(fullEnv ? HOLYARRS_OIDC_ALLOW_LOCAL_NETWORK);
      message = "holyarrs service should pass the OpenID Connect options as variables.";
    }
    {
      assertion =
        fullEnv.HOLYARRS_FORWARD_AUTH_ENABLED == "true"
        && fullEnv.HOLYARRS_FORWARD_AUTH_TRUSTED_PEERS == "127.0.0.1"
        && fullEnv.HOLYARRS_FORWARD_AUTH_ALLOW_JOIN == "false";
      message = "holyarrs service should pass the forward-auth options as variables.";
    }
    {
      assertion = fullEnv.HOLYARRS_SAVE_PATH == "/srv/override" && fullEnv.HOLYARRS_FOLLOW_LINKS == "1";
      message = "services.holyarrs.environment should override the generated variables.";
    }
    {
      assertion = fullService.serviceConfig.EnvironmentFile == [ "/run/secrets/holyarrs.env" ];
      message = "holyarrs service should read the environment file.";
    }
    {
      assertion =
        settingsSsoCfg.systemd.services.holyarrs.environment.HOLYARRS_OIDC_ALLOW_LOCAL_NETWORK == "true"
        && !(settingsSsoCfg.systemd.services.holyarrs.environment ? HOLYARRS_OIDC_ENABLED);
      message = "oidc.allowLocalNetwork should apply without locking single sign-on in Settings.";
    }
    {
      assertion = lib.elem "services.holyarrs.ownerName and services.holyarrs.ownerPasswordFile must be set together." (
        failedAssertions ownerWithoutPassword.config
      );
      message = "HolyArrs module should reject ownerName without ownerPasswordFile.";
    }
  ];

  failed = builtins.filter (check: !check.assertion) checks;
in
assert lib.assertMsg (failed == [ ]) (lib.concatMapStringsSep "\n" (check: check.message) failed);
pkgs.runCommand "holyarrs-module-eval" { } ''
  echo ok > $out
''
