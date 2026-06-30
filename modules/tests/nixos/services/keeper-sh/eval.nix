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
  evalKeeper =
    keeperConfig:
    import (inputs.nixpkgs + "/nixos") {
      inherit system;
      configuration = {
        imports = [ module ];
        nixpkgs.overlays = [ self.overlays.default ];
        system.stateVersion = "26.05";
        services.keeper-sh = keeperConfig;
      };
    };

  minimal = evalKeeper {
    enable = true;
    domain = "keeper.example.test";
    secretKeyFile = "/run/secrets/keeper-auth-secret";
    encryptionKeyFile = "/run/secrets/keeper-encryption-key";
  };

  withMcp = evalKeeper {
    enable = true;
    domain = "keeper-mcp.example.test";
    secretKeyFile = "/run/secrets/keeper-auth-secret";
    encryptionKeyFile = "/run/secrets/keeper-encryption-key";
    mcp.enable = true;
    nginx = { };
  };

  external = evalKeeper {
    enable = true;
    domain = "keeper-ext.example.test";
    secretKeyFile = "/run/secrets/keeper-auth-secret";
    encryptionKeyFile = "/run/secrets/keeper-encryption-key";

    database = {
      createLocally = false;
      host = "db.example.test";
      port = 5432;
      passwordFile = "/run/secrets/keeper-db-password";
    };

    redis = {
      createLocally = false;
      host = "redis.example.test";
      port = 6379;
    };
  };

  cfg = minimal.config;
  mcpCfg = withMcp.config;
  extCfg = external.config;

  checks = [
    {
      assertion = cfg.services.keeper-sh.package.version == "2.10.1";
      message = "Keeper module should use Keeper 2.10.1 by default.";
    }
    {
      assertion = cfg.services.keeper-sh.dataDir == "/var/lib/keeper-sh";
      message = "Keeper module should default dataDir to /var/lib/keeper-sh.";
    }
    {
      assertion =
        cfg.services.postgresql.enable && lib.elem "keeper-sh" cfg.services.postgresql.ensureDatabases;
      message = "Keeper minimal config should create a local PostgreSQL database.";
    }
    {
      assertion = cfg.services.redis.servers.keeper-sh.enable;
      message = "Keeper minimal config should create a local Redis server.";
    }
    {
      assertion = cfg.systemd.services ? keeper-sh-migrate;
      message = "Keeper module should define a keeper-migrate service.";
    }
    {
      assertion = cfg.systemd.services.keeper-sh-migrate.serviceConfig.Type == "oneshot";
      message = "keeper-migrate should be a oneshot service.";
    }
    {
      assertion = cfg.systemd.services ? keeper-sh-api;
      message = "Keeper module should define a keeper-api service.";
    }
    {
      assertion = cfg.systemd.services ? keeper-sh-cron;
      message = "Keeper module should define a keeper-cron service.";
    }
    {
      assertion = cfg.systemd.services ? keeper-sh-worker;
      message = "Keeper module should define a keeper-worker service.";
    }
    {
      assertion = cfg.systemd.services ? keeper-sh-web;
      message = "Keeper module should define a keeper-web service.";
    }
    {
      assertion = lib.hasInfix "host=/run/postgresql" cfg.systemd.services.keeper-sh-migrate.script;
      message = "keeper-migrate should use the PostgreSQL Unix socket for local PostgreSQL.";
    }
    {
      assertion = lib.hasInfix "WORKER_JOB_QUEUE_ENABLED=true" cfg.systemd.services.keeper-sh-cron.script;
      message = "keeper-cron should set WORKER_JOB_QUEUE_ENABLED=true.";
    }
    {
      assertion = cfg.services.nginx.virtualHosts."keeper.example.test".locations ? "/";
      message = "Keeper nginx config should proxy / to the web frontend.";
    }
    {
      assertion = cfg.services.nginx.virtualHosts."keeper.example.test".locations ? "/api/";
      message = "Keeper nginx config should proxy /api/ to the API server.";
    }
    {
      assertion = !(cfg.systemd.services ? keeper-sh-mcp);
      message = "keeper-mcp should not be defined when mcp.enable = false.";
    }
    # MCP-enabled config
    {
      assertion = mcpCfg.systemd.services ? keeper-sh-mcp;
      message = "keeper-mcp service should exist when mcp.enable = true.";
    }
    {
      assertion = mcpCfg.services.nginx.virtualHosts."keeper-mcp.example.test".locations ? "/mcp/";
      message = "Keeper nginx config should proxy /mcp/ when MCP is enabled.";
    }
    # External config
    {
      assertion = extCfg.services.postgresql.enable == false;
      message = "Keeper external database config should not enable local PostgreSQL.";
    }
    {
      assertion =
        !(extCfg.services.redis.servers ? keeper-sh)
        || extCfg.services.redis.servers.keeper.enable == false;
      message = "Keeper external Redis config should not enable local Redis.";
    }
  ];

  failed = builtins.filter (check: !check.assertion) checks;
in
assert lib.assertMsg (failed == [ ]) (lib.concatMapStringsSep "\n" (check: check.message) failed);
pkgs.runCommand "keeper-sh-module-eval" { } ''
  echo ok > $out
''
