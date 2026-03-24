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

  cfg = config.services.mcp-outline;

  settingsFormat = pkgs.formats.keyValue { };
  generatedEnvironmentFile = settingsFormat.generate "mcp-outline-env" cfg.settings;
in
{
  options.services.mcp-outline = {
    enable = mkEnableOption "mcp-outline service";

    package = mkPackageOption pkgs "mcp-outline" { };

    environmentFile = mkOption {
      type = types.path;
      default = "/dev/null";
      example = "/run/secrets/mcp-outline.env";
      description = ''
        Path to an environment file loaded by the service.

        Use this for secrets like `OUTLINE_API_KEY` so they stay out of the Nix store.
      '';
    };

    settings = mkOption {
      type = settingsFormat.type;
      default = {
        MCP_TRANSPORT = "streamable-http";
        MCP_HOST = "127.0.0.1";
        MCP_PORT = 3000;
      };
      example = {
        MCP_TRANSPORT = "streamable-http";
        MCP_HOST = "0.0.0.0";
        MCP_PORT = 3000;
        OUTLINE_URL = "https://outline.example.com";
      };
      description = ''
        Environment variables written to a generated environment file for mcp-outline.

        Common values are `MCP_TRANSPORT`, `MCP_HOST`, `MCP_PORT`, and `OUTLINE_URL`.
        Put secrets such as `OUTLINE_API_KEY` in `services.mcp-outline.environmentFile` instead.

        Also see: https://github.com/Vortiago/mcp-outline/blob/main/docs/configuration.md
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the configured MCP port in the firewall.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.settings.MCP_TRANSPORT != "stdio";
        message = "services.mcp-outline.settings.MCP_TRANSPORT must be \"sse\" or \"streamable-http\" when running mcp-outline as a NixOS service.";
      }
    ];

    systemd.services.mcp-outline = {
      description = "mcp-outline service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        cfg.package
        cfg.environmentFile
        generatedEnvironmentFile
      ];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        ExecStart = getExe cfg.package;
        Restart = "on-failure";
        EnvironmentFile = [
          cfg.environmentFile
          generatedEnvironmentFile
        ];

        StateDirectory = "mcp-outline";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
      };
    };

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.settings.MCP_PORT;
  };
}
