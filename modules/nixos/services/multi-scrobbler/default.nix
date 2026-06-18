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
  configEntryType = lib.types.submodule {
    freeformType = jsonFormat.type;
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Runtime name for this source/client entry.";
      };

      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this source/client entry is enabled.";
      };
    };
  };

  sourceTypes = [
    "spotify"
    "plex"
    "subsonic"
    "jellyfin"
    "lastfm"
    "librefm"
    "deezer"
    "endpointlz"
    "endpointlfm"
    "ytmusic"
    "mpris"
    "mopidy"
    "musiccast"
    "listenbrainz"
    "jriver"
    "kodi"
    "webscrobbler"
    "chromecast"
    "maloja"
    "musikcube"
    "mpd"
    "vlc"
    "icecast"
    "azuracast"
    "koito"
    "tealfm"
    "rocksky"
    "sonos"
    "ymbridge"
  ];

  clientTypes = [
    "maloja"
    "lastfm"
    "librefm"
    "listenbrainz"
    "koito"
    "tealfm"
    "rocksky"
    "discord"
  ];

  configFileTypes = lib.unique (sourceTypes ++ clientTypes);

  upstreamAutoConfigEnvPrefixes = [
    "AZURACAST_"
    "CHROMECAST_"
    "DEEZER_"
    "DISCORD_"
    "LFM_"
    "LZE_"
    "ICECAST_"
    "JELLYFIN_"
    "JRIVER_"
    "KODI_"
    "KOITO_"
    "LASTFM_"
    "LIBREFM_"
    "LIBRFM_"
    "LISTENBRAINZ_"
    "LZ_"
    "MALOJA_"
    "MOPIDY_"
    "MPD_"
    "MPRIS_"
    "MUSICCAST_"
    "MUSIKCUBE_"
    "PLEX_"
    "ROCKSKY_"
    "SONOS_"
    "SPOTIFY_"
    "SUBSONIC_"
    "TEALFM_"
    "VLC_"
    "WEBSCROBBLER_"
    "YMBRIDGE_"
    "YTMUSIC_"
  ];

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
  reservedConfigFileKeys = filter (key: key == "config") (attrNames cfg.configFiles);
  invalidConfigFileTypeKeys = filter (key: key != "config" && !(builtins.elem key configFileTypes)) (
    attrNames cfg.configFiles
  );

  upstreamAutoConfigEnvironmentKeys = filter (
    key: lib.any (prefix: lib.hasPrefix prefix key) upstreamAutoConfigEnvPrefixes
  ) (attrNames cfg.environment);

  normalizeConfigEntries = _: value: if builtins.isList value then value else [ value ];

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
    map (resource: lib.nameValuePair resource "${packageShare}/${resource}") projectResources
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
  meta.maintainers = [ "74k1" ];

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

        WARNING: upstream also treats many source/client env keys like
        `SPOTIFY_*`, `LASTFM_*`, `LIBREFM_*`, `MALOJA_*`, `LISTENBRAINZ_*`, and
        similar as single-user config. If those names are present alongside
        `configFiles` or `config`, multi-scrobbler will auto-create additional
        `unnamed` / `unnamed-lfm` configs.

        Prefer neutral names like `CUSTOM_SPOTIFY_CLIENT_ID` for interpolation.
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

        WARNING: upstream treats many source/client env keys like `SPOTIFY_*`,
        `LASTFM_*`, `LIBREFM_*`, `MALOJA_*`, `LISTENBRAINZ_*`, and similar as
        single-user config and will auto-create additional `unnamed` or
        `unnamed-lfm` sources/clients when they are present.

        If you want ENV interpolation inside `configFiles` or `config`, prefer
        neutral names like `CUSTOM_SPOTIFY_CLIENT_ID` and reference them from JSON
        as `[[CUSTOM_SPOTIFY_CLIENT_ID]]`.

        `PORT`, `BASE_URL`, and `CONFIG_DIR` are managed by dedicated module
        options and must not be set here.
      '';
    };

    configFiles = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          configEntryType
          (lib.types.listOf configEntryType)
        ]
      );
      default = { };
      example = lib.literalExpression ''
        {
          lastfm = {
            name = "lastfm_client";
            configureAs = "client";
            data = {
              apiKey = "[[CUSTOM_LASTFM_API_KEY]]";
              secret = "[[CUSTOM_LASTFM_SECRET]]";
            };
          };

          spotify = {
            name = "spotify";
            clients = [ "lastfm_client" ];
            data = {
              clientId = "[[CUSTOM_SPOTIFY_CLIENT_ID]]";
              clientSecret = "[[CUSTOM_SPOTIFY_CLIENT_SECRET]]";
            };
          };
        }
      '';
      description = ''
        File-based source/client configuration written into the managed
        multi-scrobbler `CONFIG_DIR` as `<type>.json`.

        The top-level attribute name becomes the upstream file type, so the key
        must be a real upstream type like `spotify`, `lastfm`, or `maloja`.

        Values may be either a single JSON object or a list of JSON objects.
        Single objects are wrapped in a one-element array automatically because
        upstream file-based configuration expects arrays.

        For single objects and list entries alike, `name` is required and
        `enable` defaults to `true`.

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
        like `[[CUSTOM_SPOTIFY_CLIENT_SECRET]]`.

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
        assertion = reservedConfigFileKeys == [ ];
        message = "services.multi-scrobbler.configFiles must not define a `config` attribute; use services.multi-scrobbler.config for config.json.";
      }
      {
        assertion = invalidConfigFileTypeKeys == [ ];
        message = "services.multi-scrobbler.configFiles keys must be upstream file types: ${lib.concatStringsSep ", " configFileTypes}. Set the runtime name explicitly with `name = \"...\"`. Invalid keys: ${lib.concatStringsSep ", " invalidConfigFileTypeKeys}.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.stateDir;
        message = "services.multi-scrobbler.stateDir must be an absolute path.";
      }
    ];

    warnings =
      lib.optional
        ((attrNames cfg.configFiles != [ ] || cfg.config != null) && cfg.environmentFile != "/dev/null")
        ''
          services.multi-scrobbler is using `environmentFile` together with `configFiles` or `config`.
          Upstream single-user ENV keys like `SPOTIFY_*`, `LASTFM_*`, `LIBREFM_*`, `MALOJA_*`, `LISTENBRAINZ_*`, `LZ_*`, and similar will auto-create extra `unnamed` / `unnamed-lfm` configs.
          Prefer neutral names like `CUSTOM_SPOTIFY_CLIENT_ID` and reference them from JSON with `[[TIX_SPOTIFY_CLIENT_ID]]`.
        ''
      ++
        lib.optional
          (
            (attrNames cfg.configFiles != [ ] || cfg.config != null) && upstreamAutoConfigEnvironmentKeys != [ ]
          )
          ''
            services.multi-scrobbler.environment contains upstream single-user ENV keys: ${lib.concatStringsSep ", " upstreamAutoConfigEnvironmentKeys}.
            These will cause multi-scrobbler to auto-create additional single-user configs.
            Use neutral names like `CUSTOM_SPOTIFY_CLIENT_ID` instead.
          '';

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
      ]
      ++ attrValues managedRuntimeFiles;

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
