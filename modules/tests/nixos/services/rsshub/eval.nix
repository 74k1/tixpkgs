{
  inputs,
  lib,
  module,
  pkgs,
  system,
  ...
}:
let
  evalRsshub =
    rsshubConfig:
    import (inputs.nixpkgs + "/nixos") {
      inherit system;
      configuration = {
        imports = [ module ];
        system.stateVersion = "26.05";
        services.rsshub = rsshubConfig;
      };
    };

  minimal = evalRsshub { enable = true; };

  withCaching = evalRsshub {
    enable = true;
    settings.caching.enable = true;
  };

  withOverrides = evalRsshub {
    enable = true;
    user = "feeds";
    group = "feeds";
    dataDir = "/srv/rsshub";
    environmentFile = "/run/secrets/rsshub.env";
    environment = {
      PORT = 1300;
      CACHE_EXPIRE = 600;
    };
  };

  cfg = minimal.config;
  cachingCfg = withCaching.config;
  overrideCfg = withOverrides.config;

  unit = cfg.systemd.services.rsshub;
  environmentText =
    config: (lib.last config.systemd.services.rsshub.serviceConfig.EnvironmentFile).text;

  checks = [
    {
      assertion = cfg.services.rsshub.package.pname == "rsshub";
      message = "RSSHub module should default to the nixpkgs rsshub package.";
    }
    {
      assertion = unit.wantedBy == [ "multi-user.target" ];
      message = "rsshub service should start with multi-user.target.";
    }
    {
      assertion = unit.serviceConfig.ExecStart == lib.getExe cfg.services.rsshub.package;
      message = "rsshub service should run the package executable.";
    }
    {
      assertion = unit.serviceConfig.User == "rsshub" && unit.serviceConfig.Group == "rsshub";
      message = "rsshub service should run as the rsshub user and group.";
    }
    {
      assertion = unit.serviceConfig.WorkingDirectory == "/var/lib/rsshub";
      message = "rsshub service should default its working directory to /var/lib/rsshub.";
    }
    {
      assertion = cfg.services.rsshub.environment.PORT == 1200;
      message = "RSSHub module should default PORT to 1200.";
    }
    {
      assertion = lib.head unit.serviceConfig.EnvironmentFile == "/dev/null";
      message = "rsshub service should default environmentFile to /dev/null.";
    }
    {
      assertion = cfg.users.users ? rsshub && cfg.users.users.rsshub.isSystemUser;
      message = "RSSHub module should create a rsshub system user.";
    }
    {
      assertion = cfg.users.groups ? rsshub;
      message = "RSSHub module should create a rsshub group.";
    }
    {
      assertion = lib.elem "d /var/lib/rsshub 0755 rsshub rsshub" cfg.systemd.tmpfiles.rules;
      message = "RSSHub module should create the data directory.";
    }
    {
      assertion = !(cfg.services.redis.servers ? rsshub);
      message = "RSSHub module should not configure Redis by default.";
    }
    {
      assertion = cachingCfg.services.redis.servers.rsshub.enable;
      message = "RSSHub module should enable a Redis server when caching is enabled.";
    }
    {
      assertion = cachingCfg.services.redis.servers.rsshub.port == 0;
      message = "The RSSHub Redis server should listen on no TCP port.";
    }
    {
      assertion = cachingCfg.services.redis.servers.rsshub.user == "rsshub";
      message = "The RSSHub Redis server should run as the rsshub user.";
    }
    {
      assertion = lib.hasInfix "CACHE_TYPE=redis" (environmentText cachingCfg);
      message = "rsshub environment should set CACHE_TYPE=redis when caching is enabled.";
    }
    {
      assertion = lib.hasInfix "REDIS_URL=unix:///run/redis-rsshub/redis.sock" (
        environmentText cachingCfg
      );
      message = "rsshub environment should point REDIS_URL at the Redis Unix socket.";
    }
    {
      assertion = !(lib.hasInfix "CACHE_TYPE" (environmentText cfg));
      message = "rsshub environment should not set CACHE_TYPE when caching is disabled.";
    }
    {
      assertion = lib.hasInfix "PORT=1300" (environmentText overrideCfg);
      message = "rsshub environment should pass a custom PORT.";
    }
    {
      assertion = lib.hasInfix "CACHE_EXPIRE=600" (environmentText overrideCfg);
      message = "rsshub environment should pass extra environment variables.";
    }
    {
      assertion =
        lib.head overrideCfg.systemd.services.rsshub.serviceConfig.EnvironmentFile
        == "/run/secrets/rsshub.env";
      message = "rsshub service should load a custom environmentFile.";
    }
    {
      assertion = overrideCfg.systemd.services.rsshub.serviceConfig.User == "feeds";
      message = "rsshub service should run as a custom user.";
    }
    {
      assertion = !(overrideCfg.users.users ? rsshub) && !(overrideCfg.users.groups ? rsshub);
      message = "RSSHub module should not create the default user and group when both are overridden.";
    }
    {
      assertion = lib.elem "d /srv/rsshub 0755 feeds feeds" overrideCfg.systemd.tmpfiles.rules;
      message = "RSSHub module should create a custom data directory for the custom user.";
    }
  ];

  failed = builtins.filter (check: !check.assertion) checks;
in
assert lib.assertMsg (failed == [ ]) (lib.concatMapStringsSep "\n" (check: check.message) failed);
pkgs.runCommand "rsshub-module-eval" { } ''
  echo ok > $out
''
