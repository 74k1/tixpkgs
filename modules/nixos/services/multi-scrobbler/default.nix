{ tixpkgs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins)
    attrNames
    attrValues
    filter
    hasAttr
    ;

  cfg = config.services.multi-scrobbler;
  serviceName = "multi-scrobbler";
  defaultStateDir = "/var/lib/${serviceName}";
  packageShare = "${cfg.package}/share/${serviceName}";

  projectResources = [
    "dist"
    "node_modules"
    "package-lock.json"
    "package.json"
    "public"
    "src"
  ];

  envFormat = pkgs.formats.keyValue { };
  jsonFormat = pkgs.formats.json { };
  jsonObjectType = lib.types.submodule {
    freeformType = jsonFormat.type;
  };

  reservedEnvironmentKeys = [
    "BASE_URL"
    "CONFIG_DIR"
    "PORT"
  ];

  reservedConfigKeys = [
    "baseUrl"
    "port"
  ];

  invalidEnvironmentKeys = filter (key: hasAttr key cfg.environment) reservedEnvironmentKeys;
  invalidAioKeys = filter (key: cfg.config != null && hasAttr key cfg.config) reservedConfigKeys;
  invalidConfigFileKeys = filter (key: key == "config") (attrNames cfg.configFiles);

  normalizeConfigEntries =
    fileType: value:
    let
      entries = if builtins.isList value then value else [ value ];
    in
    map (
      entry:
      {
        enable = true;
        name = fileType;
      }
      // entry
    ) entries;

  normalizedConfigFiles = lib.mapAttrs normalizeConfigEntries cfg.configFiles;

  managedConfigFiles =
    lib.mapAttrs' (
      fileType: entries:
      lib.nameValuePair "${fileType}.json" (jsonFormat.generate "${serviceName}-${fileType}.json" entries)
    ) normalizedConfigFiles
    // lib.optionalAttrs (cfg.config != null) {
      "config.json" = jsonFormat.generate "${serviceName}-config.json" cfg.config;
    };

  managedProjectFiles = builtins.listToAttrs (
    map (
      resource:
      lib.nameValuePair resource "${packageShare}/${resource}"
    ) projectResources
  );

  managedRuntimeFiles = managedProjectFiles // managedConfigFiles;

  generatedEnvironmentFile = envFormat.generate "${serviceName}-env" (
    cfg.environment
    // {
      CONFIG_DIR = cfg.stateDir;
      PORT = cfg.port;
    }
    // lib.optionalAttrs (cfg.baseUrl != null) {
      BASE_URL = cfg.baseUrl;
    }
  );

  managedConfigSetup = ''
    set -eu

    config_dir="''${STATE_DIRECTORY%%:*}"
    manifest="$config_dir/.nix-managed-config-files"

    if [ -f "$manifest" ]; then
      while IFS= read -r relpath; do
        [ -n "$relpath" ] || continue
        target="$config_dir/$relpath"

        if [ -L "$target" ]; then
          rm -f "$target"
        fi
      done < "$manifest"
    fi

    : > "$manifest"

    ${lib.concatMapStringsSep "\n" (
      fileName:
      let
        source = managedRuntimeFiles.${fileName};
        quotedFileName = lib.escapeShellArg fileName;
        quotedSource = lib.escapeShellArg source;
      in
      ''
        target="$config_dir/"${quotedFileName}

        if [ -e "$target" ] && [ ! -L "$target" ]; then
          printf '%s\n' "Refusing to replace unmanaged file $target" >&2
          exit 1
        fi

        ln -sfn ${quotedSource} "$target"
        printf '%s\n' ${quotedFileName} >> "$manifest"
      ''
    ) (attrNames managedRuntimeFiles)}

    mkdir -p "$config_dir/logs"
  '';
in
{
  options.services.multi-scrobbler = {
    enable = lib.mkEnableOption "multi-scrobbler service";

    package = lib.mkPackageOption tixpkgs "multi-scrobbler" { };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = "/dev/null";
      example = "/run/secrets/multi-scrobbler.env";
      description = ''
        Path to an environment file loaded by the multi-scrobbler service.

        This is the recommended place for source/client credentials and other
        secrets, since multi-scrobbler supports extensive ENV-based configuration
        and ENV interpolation inside JSON config files.
      '';
    };

    environment = lib.mkOption {
      type = envFormat.type;
      default = { };
      example = {
        TZ = "Etc/UTC";
        CACHE_METADATA = "valkey";
        CACHE_METADATA_CONN = "redis://127.0.0.1:6379";
        PROMETHEUS_FULL = true;
      };
      description = ''
        Non-secret environment variables passed to multi-scrobbler.

        This is suitable for application-level options like `TZ`, `DEBUG_MODE`,
        cache settings, `DISABLE_WEB`, or `PROMETHEUS_FULL`.

        Secrets should go in `services.multi-scrobbler.environmentFile` instead.

        `PORT`, `BASE_URL`, and `CONFIG_DIR` are managed by dedicated module
        options and must not be set here.
      '';
    };

    configFiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [
        jsonObjectType
        (lib.types.listOf jsonObjectType)
      ]);
      default = { };
      example = lib.literalExpression ''
        {
          spotify = {
            clients = [ "lastfm-main" ];
            data = {
              clientId = "[[SPOTIFY_CLIENT_ID]]";
              clientSecret = "[[SPOTIFY_CLIENT_SECRET]]";
            };
          };

          lastfm = [
            {
              name = "lastfm-main";
              data = {
                apiKey = "[[LASTFM_API_KEY]]";
                secret = "[[LASTFM_SECRET]]";
              };
            }
          ];
        }
      '';
      description = ''
        File-based source/client configuration written into the managed
        multi-scrobbler `CONFIG_DIR` as `<type>.json`.

        Values may be either a single JSON object or a list of JSON objects.
        Single objects are wrapped in a one-element array automatically because
        upstream file-based configuration expects arrays.

        For single objects and list entries alike, `enable` defaults to `true`
        and `name` defaults to the top-level attribute name when omitted.

        The attribute name `config` is reserved for
        `services.multi-scrobbler.config`.
      '';
    };

    config = lib.mkOption {
      type = lib.types.nullOr jsonObjectType;
      default = null;
      example = {
        sourceDefaults.interval = 30;
        webhooks = [
          {
            type = "ntfy";
            name = "alerts";
            url = "http://ntfy.internal:8080";
            topic = "multi-scrobbler";
          }
        ];
      };
      description = ''
        All-in-one configuration written to `config.json` in the managed
        multi-scrobbler `CONFIG_DIR`.

        This can be combined with `environmentFile`, `environment`, and
        `configFiles`. Secrets should still be referenced via ENV interpolation
        like `[[SPOTIFY_CLIENT_SECRET]]`.

        Top-level `port` and `baseUrl` are managed by dedicated module options
        and must not be set here.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = defaultStateDir;
      example = "/opt/multi-scrobbler";
      description = ''
        Directory used as multi-scrobbler's `CONFIG_DIR` and working directory.

        With `DynamicUser = true`, the service's mutable state is still managed by
        systemd. When this path differs from the default, the module exposes it as
        a symlink to the systemd-managed state directory.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9078;
      description = ''
        Port exposed by multi-scrobbler's web UI and API.
      '';
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://scrobble.example.com";
      description = ''
        Optional base URL exposed to multi-scrobbler as `BASE_URL`.

        This is used to derive callback URLs and other externally visible links.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the configured multi-scrobbler port in the firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = invalidEnvironmentKeys == [ ];
        message = "services.multi-scrobbler.environment must not set reserved keys: ${lib.concatStringsSep ", " invalidEnvironmentKeys}";
      }
      {
        assertion = invalidAioKeys == [ ];
        message = "services.multi-scrobbler.config must not set reserved top-level keys: ${lib.concatStringsSep ", " invalidAioKeys}";
      }
      {
        assertion = invalidConfigFileKeys == [ ];
        message = "services.multi-scrobbler.configFiles must not define a `config` attribute; use services.multi-scrobbler.config for config.json.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.stateDir;
        message = "services.multi-scrobbler.stateDir must be an absolute path.";
      }
    ];

    systemd.tmpfiles.rules = lib.optionals (cfg.stateDir != defaultStateDir) [
      "d ${builtins.dirOf cfg.stateDir} 0755 root root -"
      "L+ ${cfg.stateDir} - - - - ${defaultStateDir}"
    ];

    systemd.services.multi-scrobbler = {
      description = "multi-scrobbler service";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        cfg.package
        cfg.environmentFile
        generatedEnvironmentFile
      ] ++ attrValues managedRuntimeFiles;

      preStart = managedConfigSetup;

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = serviceName;
        StateDirectoryMode = "0750";
        WorkingDirectory = cfg.stateDir;
        ExecStart = "${cfg.package}/bin/${serviceName}-service";
        Restart = "on-failure";
        EnvironmentFile = [
          cfg.environmentFile
          generatedEnvironmentFile
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;
  };
}
