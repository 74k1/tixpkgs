{ tixpkgs }:
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.holyarrs;

  inherit (lib)
    boolToString
    concatStringsSep
    filterAttrs
    hasInfix
    literalExpression
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    optionalAttrs
    types
    ;

  serviceName = "holyarrs";

  listenAddress =
    if hasInfix ":" cfg.address then
      "[${cfg.address}]:${toString cfg.port}"
    else
      "${cfg.address}:${toString cfg.port}";

  # Systemd reads these files as root and hands them to the service under
  # $CREDENTIALS_DIRECTORY, so the service user does not need to read the originals.
  credentials = filterAttrs (_: file: file != null) {
    owner-password = cfg.ownerPasswordFile;
    api-key = cfg.apiKeyFile;
    master-key = cfg.masterKeyFile;
    oidc-client-secret = cfg.oidc.clientSecretFile;
    tmdb-key = cfg.metadata.tmdbKeyFile;
  };
  credentialPath = name: if credentials ? ${name} then "%d/${name}" else null;

  commaList = values: if values == [ ] then null else concatStringsSep "," values;
  trueOrNull = value: if value then "true" else null;

  generatedEnvironment = filterAttrs (_: value: value != null) (
    {
      HOLYARRS_URL_BASE = cfg.urlBase;
      HOLYARRS_ALLOWED_HOSTS = commaList cfg.allowedHosts;
      HOLYARRS_TRUSTED_PROXIES = commaList cfg.trustedProxies;
      HOLYARRS_SAVE_PATH = cfg.savePath;
      HOLYARRS_UPDATE_CHECK = if cfg.updateCheck then null else "off";

      HOLYARRS_OWNER_NAME = cfg.ownerName;
      HOLYARRS_OWNER_PASSWORD_FILE = credentialPath "owner-password";
      HOLYARRS_API_KEY_FILE = credentialPath "api-key";
      HOLYARRS_API_KEY_SCOPES = if cfg.apiKeyFile != null then commaList cfg.apiKeyScopes else null;
      HOLYARRS_MASTER_KEY_FILE = credentialPath "master-key";

      HOLYARRS_METADATA_MODE = cfg.metadata.mode;
      # The FILE__ prefix makes HolyArrs read the value from the file.
      FILE__HOLYARRS_TMDB_KEY = credentialPath "tmdb-key";

      # These limits also apply to single sign-on set up in Settings.
      HOLYARRS_OIDC_ALLOW_LOCAL_NETWORK = trueOrNull cfg.oidc.allowLocalNetwork;
      HOLYARRS_OIDC_ALLOW_LOOPBACK_HTTP = trueOrNull cfg.oidc.allowLoopbackHttp;
    }
    # HolyArrs locks single sign-on in Settings as soon as HOLYARRS_OIDC_ENABLED
    # is present, even as false. Set nothing unless the module owns it.
    // optionalAttrs cfg.oidc.enable {
      HOLYARRS_OIDC_ENABLED = "true";
      HOLYARRS_OIDC_ISSUER = cfg.oidc.issuer;
      HOLYARRS_OIDC_CLIENT_ID = cfg.oidc.clientId;
      HOLYARRS_OIDC_CLIENT_SECRET_FILE = credentialPath "oidc-client-secret";
      HOLYARRS_OIDC_REDIRECT_URL = cfg.oidc.redirectUrl;
      HOLYARRS_OIDC_ALLOW_JOIN = boolToString cfg.oidc.allowJoin;
      HOLYARRS_OIDC_GROUPS_CLAIM = cfg.oidc.groupsClaim;
      HOLYARRS_OIDC_GROUP_ROLES = commaList (
        mapAttrsToList (group: role: "${group}=${role}") cfg.oidc.groupRoles
      );
    }
    // optionalAttrs cfg.forwardAuth.enable {
      HOLYARRS_FORWARD_AUTH_ENABLED = "true";
      HOLYARRS_FORWARD_AUTH_ISSUER = cfg.forwardAuth.issuer;
      HOLYARRS_FORWARD_AUTH_TRUSTED_PEERS = commaList cfg.forwardAuth.trustedPeers;
      HOLYARRS_FORWARD_AUTH_ALLOW_JOIN = boolToString cfg.forwardAuth.allowJoin;
    }
  );
in
{
  meta.maintainers = with lib.maintainers; [ _74k1 ];

  options.services.holyarrs = {
    enable = mkEnableOption "HolyArrs, a self-hosted manager for shows, movies, music, subtitles and requests";

    package = mkPackageOption tixpkgs "holyarrs" { };

    user = mkOption {
      type = types.str;
      default = serviceName;
      description = "User account under which HolyArrs runs.";
    };

    group = mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which HolyArrs runs.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/${serviceName}";
      description = ''
        Config folder of HolyArrs: databases, the master key `holyarrs.key`,
        backups, logs and plugins. HolyArrs refuses network shares, FUSE
        folders and memory-backed folders here, so keep it on a local disk.
      '';
    };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        IP address HolyArrs listens on. Defaults to localhost so the service is
        not exposed on the network by accident: the first visitor of a fresh
        install becomes the owner. Set {option}`services.holyarrs.ownerName`
        before you expose it.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 6262;
      description = "TCP port HolyArrs listens on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the HolyArrs port in the firewall.";
    };

    urlBase = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/holyarrs";
      description = ''
        Path HolyArrs is served under behind a reverse proxy
        (`HOLYARRS_URL_BASE`). The proxy must pass the path on unchanged.
        When set, the path saved in Settings is ignored.
      '';
    };

    allowedHosts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "holyarrs.example.com" ];
      description = ''
        Host names people use to reach HolyArrs (`HOLYARRS_ALLOWED_HOSTS`).
        IP addresses and `localhost` are always allowed. Add the domain of
        your reverse proxy here.
      '';
    };

    trustedProxies = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "127.0.0.1" ];
      description = ''
        Addresses or networks of reverse proxies that send `X-Forwarded-For`
        (`HOLYARRS_TRUSTED_PROXIES`). Without it, single sign-on, real client
        addresses and the Secure cookie do not work behind a proxy.
      '';
    };

    mediaDirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "/srv/media"
        "/srv/downloads"
      ];
      description = ''
        Folders HolyArrs may read and write besides
        {option}`services.holyarrs.dataDir`: the library folders and the
        downloader's save folder. The service sees the rest of the file system
        as read-only, and `/home` not at all.

        The folders must exist before the service starts. The service user
        also needs file permissions on them, for example through a shared
        group in `users.users.holyarrs.extraGroups`.
      '';
    };

    savePath = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/srv/downloads";
      description = ''
        The downloader's save folder, as the downloader sees it
        (`HOLYARRS_SAVE_PATH`). HolyArrs sends it with every download.
      '';
    };

    umask = mkOption {
      type = types.str;
      default = "0022";
      example = "0002";
      description = ''
        File mode creation mask of the service. Library files must stay
        readable for your media server. Use `0002` when HolyArrs, the
        downloader and the media server share a group.
      '';
    };

    updateCheck = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether HolyArrs tells you about new versions. The package is built
        without the in-app installer, so HolyArrs never installs a version
        itself. When false, HolyArrs starts with the check off and sends no
        update request (`HOLYARRS_UPDATE_CHECK=off`). The switch in the app
        still wins after the first start.
      '';
    };

    ownerName = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "admin";
      description = ''
        Name of the owner account to make on the first start
        (`HOLYARRS_OWNER_NAME`). Without it, the first visitor of the web
        interface becomes the owner. Needs
        {option}`services.holyarrs.ownerPasswordFile`. Once an owner exists,
        it changes nothing.
      '';
    };

    ownerPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/holyarrs-owner-password";
      description = ''
        File containing the password of the owner made from
        {option}`services.holyarrs.ownerName`, at most 4096 bytes. HolyArrs
        reads it only while there is no owner.

        The file is loaded as a systemd credential, so systemd reads it as
        root before the sandbox starts. It does not need to be readable by
        the `holyarrs` user.
      '';
    };

    apiKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/holyarrs-api-key";
      description = ''
        File containing an API key for the owner (`HOLYARRS_API_KEY_FILE`):
        `hak_` and 43 random characters. HolyArrs keeps one key from it and
        replaces that key when the file changes. Needs an owner.

        The file is loaded as a systemd credential.
      '';
    };

    apiKeyScopes = mkOption {
      type = types.listOf types.str;
      default = [ "all" ];
      example = [
        "read"
        "write"
      ];
      description = ''
        Scopes of the key from {option}`services.holyarrs.apiKeyFile`
        (`HOLYARRS_API_KEY_SCOPES`), as for a key made in
        **Settings > API > API keys**.
      '';
    };

    masterKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/holyarrs-master-key";
      description = ''
        File containing the master key that encrypts the stored passwords and
        API keys (`HOLYARRS_MASTER_KEY_FILE`). Generate one with
        `openssl rand -base64 32`. When null, HolyArrs makes
        `holyarrs.key` in {option}`services.holyarrs.dataDir` on the first
        start.

        Backups never hold the master key. A key from a file stays out of the
        config folder and out of its copies.

        The file is loaded as a systemd credential.
      '';
    };

    metadata = {
      mode = mkOption {
        type = types.nullOr (
          types.enum [
            "full"
            "own"
            "off"
          ]
        );
        default = null;
        description = ''
          Where titles, artwork and charts come from
          (`HOLYARRS_METADATA_MODE`): `full` (the HolyArrs metadata server),
          `own` (your own keys) or `off`. When set, it locks the choice in
          **Settings > Metadata**. When null, Settings decide, with `full` as
          the default.
        '';
      };

      tmdbKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/holyarrs-tmdb-key";
        description = ''
          File containing your own TMDB read access token
          (`HOLYARRS_TMDB_KEY`). When set, TMDB reads go straight to TMDB
          instead of the metadata server.

          The file is loaded as a systemd credential.
        '';
      };
    };

    oidc = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to set up single sign-on with OpenID Connect from the module.
          When enabled, Settings only show single sign-on. When disabled, it
          can be set up in Settings instead.
        '';
      };

      issuer = mkOption {
        type = types.str;
        example = "https://auth.example.com/application/o/holyarrs/";
        description = "Exact HTTPS issuer of the OpenID Connect provider.";
      };

      clientId = mkOption {
        type = types.str;
        example = "holyarrs";
        description = "Client ID registered with the provider.";
      };

      clientSecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/holyarrs-oidc-client-secret";
        description = ''
          File containing the client secret, at most 4096 bytes. Leave it
          null for a public client.

          The file is loaded as a systemd credential.
        '';
      };

      redirectUrl = mkOption {
        type = types.str;
        example = "https://holyarrs.example.com/api/v1/auth/oidc/callback";
        description = ''
          Exact callback URL: your address, then
          {option}`services.holyarrs.urlBase` if set, then
          `/api/v1/auth/oidc/callback`.
        '';
      };

      allowJoin = mkOption {
        type = types.bool;
        default = false;
        description = "Whether new people join as members who can only make requests.";
      };

      groupsClaim = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "groups";
        description = ''
          Claim that carries the groups. When null, roles are set in
          HolyArrs only.
        '';
      };

      groupRoles = mkOption {
        type = types.attrsOf (
          types.enum [
            "admin"
            "member"
          ]
        );
        default = { };
        example = {
          admins = "admin";
          family = "member";
        };
        description = ''
          Role for each group in {option}`services.holyarrs.oidc.groupsClaim`.
          Each sign-in gives the highest role. People in no listed group are
          members. It never makes or changes the owner.
        '';
      };

      allowLocalNetwork = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether the provider may be on your private network. This also
          applies to single sign-on set up in Settings.
        '';
      };

      allowLoopbackHttp = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether the provider may use plain HTTP on this machine, for tests.
          This also applies to single sign-on set up in Settings.
        '';
      };
    };

    forwardAuth = {
      enable = mkEnableOption "sign-in through a trusted reverse proxy that sends identity headers";

      issuer = mkOption {
        type = types.str;
        example = "https://auth.example.com";
        description = "Stable HTTPS name of the proxy.";
      };

      trustedPeers = mkOption {
        type = types.listOf types.str;
        example = [ "127.0.0.1" ];
        description = "Proxy addresses or networks allowed to send identity headers.";
      };

      allowJoin = mkOption {
        type = types.bool;
        default = false;
        description = "Whether new names from the proxy join as members who can only make requests.";
      };
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/holyarrs.env";
      description = ''
        File with additional environment variables, in systemd
        `EnvironmentFile` format (`KEY=value`, one per line, no shell syntax).
        Systemd reads it as root before the sandbox starts.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = literalExpression ''
        {
          HOLYARRS_FOLLOW_LINKS = "1";
          HOLYARRS_READONLY_DOWNLOADERS = "http://127.0.0.1:8080";
        }
      '';
      description = ''
        Environment variables passed to HolyArrs. Overrides the generated
        defaults. See the
        [upstream reference](https://docs.holyarrs.com/reference/env-vars/)
        for all variables.

        These values are written to the Nix store, so do not put secrets here.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.holyarrs.dataDir must be an absolute path.";
      }
      {
        assertion = (cfg.ownerName == null) == (cfg.ownerPasswordFile == null);
        message = "services.holyarrs.ownerName and services.holyarrs.ownerPasswordFile must be set together.";
      }
    ];

    users.users = optionalAttrs (cfg.user == serviceName) {
      ${serviceName} = {
        inherit (cfg) group;
        home = cfg.dataDir;
        isSystemUser = true;
      };
    };

    users.groups = optionalAttrs (cfg.group == serviceName) {
      ${serviceName} = { };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.holyarrs = {
      description = "HolyArrs media manager";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = generatedEnvironment // cfg.environment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${lib.getExe cfg.package} -config ${cfg.dataDir} -addr ${listenAddress}";
        WorkingDirectory = cfg.dataDir;

        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        LoadCredential = mapAttrsToList (name: file: "${name}:${file}") credentials;

        # A restart from the controls and a backup restore exit with 75 and
        # expect a new start. A shut down from the controls exits with 0.
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = cfg.umask;

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ] ++ cfg.mediaDirs;
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          # Go reads the local addresses through netlink.
          "AF_NETLINK"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        # The plugin sandbox needs Landlock and seccomp, which @system-service includes.
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
  };
}
