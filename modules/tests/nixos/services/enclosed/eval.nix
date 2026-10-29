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
  evalEnclosed =
    enclosedConfig:
    import (inputs.nixpkgs + "/nixos") {
      inherit system;
      configuration = {
        imports = [ module ];
        nixpkgs.overlays = [ self.overlays.default ];
        system.stateVersion = "26.05";
        services.enclosed = enclosedConfig;
      };
    };

  minimal = evalEnclosed { enable = true; };

  withNginx = evalEnclosed {
    enable = true;
    domain = "notes.example.test";
    nginx = { };
  };

  withAuthentication = evalEnclosed {
    enable = true;
    authenticationRequired = true;
    jwtSecretFile = "/run/secrets/enclosed-jwt-secret";
    usersFile = "/run/secrets/enclosed-users";
    environmentFile = "/run/secrets/enclosed.env";
  };

  incompleteAuthentication = evalEnclosed {
    enable = true;
    authenticationRequired = true;
  };

  withOverrides = evalEnclosed {
    enable = true;
    port = 9000;
    publicBaseApiUrl = "/enclosed";
    environment.PUBLIC_DEFAULT_NOTE_TTL_SECONDS = "86400";
  };

  missingDomain = evalEnclosed {
    enable = true;
    nginx = { };
  };

  cfg = minimal.config;
  nginxCfg = withNginx.config;
  authCfg = withAuthentication.config;
  incompleteAuthCfg = incompleteAuthentication.config;
  overrideCfg = withOverrides.config;
  missingDomainCfg = missingDomain.config;

  checks = [
    {
      assertion = cfg.services.enclosed.package.pname == "enclosed";
      message = "Enclosed module should default to the tixpkgs enclosed package.";
    }
    {
      assertion = cfg.services.enclosed.dataDir == "/var/lib/enclosed";
      message = "Enclosed module should default dataDir to /var/lib/enclosed.";
    }
    {
      assertion = cfg.services.enclosed.port == 8787;
      message = "Enclosed module should default to port 8787.";
    }
    {
      assertion = cfg.systemd.services ? enclosed;
      message = "Enclosed module should define an enclosed service.";
    }
    {
      assertion = cfg.systemd.services.enclosed.serviceConfig.Type == "simple";
      message = "Enclosed service should be of type simple.";
    }
    {
      assertion = cfg.systemd.services.enclosed.environment.NODE_ENV == "production";
      message = "Enclosed service should set NODE_ENV=production.";
    }
    {
      assertion = cfg.systemd.services.enclosed.environment.PORT == "8787";
      message = "Enclosed service should pass PORT from the module option.";
    }
    {
      assertion =
        cfg.systemd.services.enclosed.environment.STORAGE_DRIVER_FS_LITE_PATH == "/var/lib/enclosed/data";
      message = "Enclosed service should store notes below dataDir.";
    }
    {
      assertion = cfg.systemd.services.enclosed.environment.PUBLIC_IS_AUTHENTICATION_REQUIRED == "false";
      message = "Enclosed service should disable required authentication by default.";
    }
    {
      assertion = lib.hasInfix "share/enclosed" cfg.systemd.services.enclosed.serviceConfig.WorkingDirectory;
      message = "Enclosed service should start in the package share directory.";
    }
    {
      assertion = cfg.users.users ? enclosed;
      message = "Enclosed module should create an enclosed system user.";
    }
    {
      assertion = cfg.users.groups ? enclosed;
      message = "Enclosed module should create an enclosed group.";
    }
    {
      assertion = lib.all (rule: builtins.elem rule cfg.systemd.tmpfiles.rules) [
        "d /var/lib/enclosed 0750 enclosed enclosed - -"
        "d /var/lib/enclosed/data 0750 enclosed enclosed - -"
      ];
      message = "Enclosed module should create the data directories with restrictive permissions.";
    }
    {
      assertion = cfg.networking.firewall.allowedTCPPorts == [ ];
      message = "Enclosed module should not open the firewall by default.";
    }
    {
      assertion = !(cfg.services.nginx.virtualHosts ? "notes.example.test");
      message = "Enclosed should not configure nginx by default.";
    }
    {
      assertion =
        nginxCfg.services.nginx.virtualHosts."notes.example.test".locations."/".proxyPass
        == "http://127.0.0.1:8787";
      message = "Enclosed nginx config should proxy / to the local port.";
    }
    {
      assertion =
        authCfg.systemd.services.enclosed.environment.PUBLIC_IS_AUTHENTICATION_REQUIRED == "true";
      message = "Enclosed service should require authentication when enabled.";
    }
    {
      assertion = lib.hasInfix "AUTHENTICATION_JWT_SECRET" authCfg.systemd.services.enclosed.script;
      message = "Enclosed service should export AUTHENTICATION_JWT_SECRET when jwtSecretFile is set.";
    }
    {
      assertion = lib.hasInfix "AUTHENTICATION_USERS" authCfg.systemd.services.enclosed.script;
      message = "Enclosed service should export AUTHENTICATION_USERS when usersFile is set.";
    }
    {
      assertion =
        authCfg.systemd.services.enclosed.serviceConfig.LoadCredential == [
          "jwt-secret:/run/secrets/enclosed-jwt-secret"
          "users:/run/secrets/enclosed-users"
        ];
      message = "Enclosed service should load secret files as systemd credentials.";
    }
    {
      assertion =
        authCfg.systemd.services.enclosed.serviceConfig.EnvironmentFile == [ "/run/secrets/enclosed.env" ];
      message = "Enclosed service should let systemd read the environment file.";
    }
    {
      assertion = cfg.systemd.services.enclosed.serviceConfig.LoadCredential == [ ];
      message = "Enclosed service should load no credentials by default.";
    }
    {
      assertion = cfg.warnings == [ ];
      message = "Enclosed module should not warn about authentication unless authentication is required.";
    }
    {
      assertion = lib.any (
        warning: lib.hasInfix "no users are configured" warning
      ) incompleteAuthCfg.warnings;
      message = "Enclosed should warn when authentication is required without configured users.";
    }
    {
      assertion = lib.any (warning: lib.hasInfix "change-me" warning) incompleteAuthCfg.warnings;
      message = "Enclosed should warn when authentication is required without a JWT secret file.";
    }
    {
      assertion = authCfg.warnings == [ ];
      message = "Enclosed should not warn when authentication is fully configured.";
    }
    {
      assertion = cfg.systemd.services.enclosed.serviceConfig.ProtectSystem == "strict";
      message = "Enclosed service should run with a read-only system.";
    }
    {
      assertion = cfg.systemd.services.enclosed.serviceConfig.CapabilityBoundingSet == "";
      message = "Enclosed service should drop all capabilities.";
    }
    {
      assertion = cfg.systemd.services.enclosed.serviceConfig.ProtectProc == "invisible";
      message = "Enclosed service should hide other processes.";
    }
    {
      assertion = cfg.systemd.services.enclosed.serviceConfig.RemoveIPC;
      message = "Enclosed service should remove IPC objects on shutdown.";
    }
    {
      assertion =
        cfg.systemd.services.enclosed.serviceConfig.SystemCallFilter == [
          "@system-service"
          "~@privileged"
        ];
      message = "Enclosed service should restrict system calls.";
    }
    {
      assertion = !(cfg.systemd.services.enclosed.serviceConfig.MemoryDenyWriteExecute or false);
      message = "Enclosed service must not deny write and execute mappings, V8 needs them.";
    }
    {
      assertion = overrideCfg.systemd.services.enclosed.environment.PORT == "9000";
      message = "Enclosed service should pass a custom port.";
    }
    {
      assertion = overrideCfg.systemd.services.enclosed.environment.PUBLIC_BASE_API_URL == "/enclosed";
      message = "Enclosed service should pass a custom public API base URL.";
    }
    {
      assertion =
        overrideCfg.systemd.services.enclosed.environment.PUBLIC_DEFAULT_NOTE_TTL_SECONDS == "86400";
      message = "Enclosed service should pass extra environment variables.";
    }
    {
      assertion = builtins.any (
        assertion: lib.hasInfix "services.enclosed.domain must be set" assertion.message
      ) missingDomainCfg.assertions;
      message = "Enclosed should assert that domain is set when nginx is enabled.";
    }
  ];

  failed = builtins.filter (check: !check.assertion) checks;
in
assert lib.assertMsg (failed == [ ]) (lib.concatMapStringsSep "\n" (check: check.message) failed);
pkgs.runCommand "enclosed-module-eval" { } ''
  echo ok > $out
''
