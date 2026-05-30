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
  evalTrek =
    trekConfig:
    import (inputs.nixpkgs + "/nixos") {
      inherit system;
      configuration = {
        imports = [ module ];
        nixpkgs.overlays = [ self.overlays.default ];
        system.stateVersion = "26.05";
        services.trek = trekConfig;
      };
    };

  minimal = evalTrek {
    enable = true;
    domain = "trek.example.test";
  };

  withEncryptionKey = evalTrek {
    enable = true;
    domain = "trek-enc.example.test";
    encryptionKeyFile = "/run/secrets/trek-encryption-key";
  };

  withoutNginx = evalTrek {
    enable = true;
    domain = "trek-nonginx.example.test";
    nginx = null;
  };

  cfg = minimal.config;
  encCfg = withEncryptionKey.config;
  noNginxCfg = withoutNginx.config;

  checks = [
    {
      assertion = cfg.services.trek.package.version == "3.0.22";
      message = "TREK module should use TREK 3.0.22 by default.";
    }
    {
      assertion = cfg.services.trek.dataDir == "/var/lib/trek";
      message = "TREK module should default dataDir to /var/lib/trek.";
    }
    {
      assertion = cfg.systemd.services ? trek;
      message = "TREK module should define a trek service.";
    }
    {
      assertion = cfg.systemd.services.trek.serviceConfig.Type == "simple";
      message = "trek service should be of type simple.";
    }
    {
      assertion = cfg.systemd.services.trek.environment.NODE_ENV == "production";
      message = "trek service should set NODE_ENV=production.";
    }
    {
      assertion = cfg.systemd.services.trek.environment.TREK_DATA_DIR == "/var/lib/trek/data";
      message = "trek service should set TREK_DATA_DIR to /var/lib/trek/data.";
    }
    {
      assertion = cfg.systemd.services.trek.environment.TREK_UPLOADS_DIR == "/var/lib/trek/uploads";
      message = "trek service should set TREK_UPLOADS_DIR to /var/lib/trek/uploads.";
    }
    {
      assertion = cfg.users.users ? trek;
      message = "TREK module should create a trek system user.";
    }
    {
      assertion = cfg.users.groups ? trek;
      message = "TREK module should create a trek group.";
    }
    {
      assertion = cfg.services.nginx.virtualHosts."trek.example.test".locations ? "/";
      message = "TREK nginx config should proxy / to the server.";
    }
    # encryptionKeyFile
    {
      assertion = lib.hasInfix "ENCRYPTION_KEY" encCfg.systemd.services.trek.script;
      message = "trek service should export ENCRYPTION_KEY when encryptionKeyFile is set.";
    }
    {
      assertion = lib.hasInfix "/run/secrets/trek-encryption-key" encCfg.systemd.services.trek.script;
      message = "trek service script should reference the encryptionKeyFile path.";
    }
    # nginx = null
    {
      assertion = !(noNginxCfg.services.nginx.virtualHosts ? "trek-nonginx.example.test");
      message = "TREK should not configure nginx when nginx = null.";
    }
  ];

  failed = builtins.filter (check: !check.assertion) checks;
in
assert lib.assertMsg (failed == [ ]) (lib.concatMapStringsSep "\n" (check: check.message) failed);
pkgs.runCommand "trek-module-eval" { } ''
  echo ok > $out
''
