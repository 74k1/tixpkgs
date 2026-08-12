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
    elemAt
    filter
    hasAttr
    head
    length
    map
    match
    ;

  inherit (lib)
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optional
    optionalAttrs
    optionals
    optionalString
    types
    ;

  cfg = config.services.thunderbolt;

  serviceName = "thunderbolt";
  defaultStateDir = "/var/lib/thunderbolt";
  defaultDatabaseUrl = "${cfg.stateDir}/db";
  envFormat = pkgs.formats.keyValue { };

  publicUrlParts =
    if cfg.publicUrl == null then
      null
    else
      match "^(https?)://([^/:]+)(:([0-9]+))?(/.*)?$" cfg.publicUrl;

  publicUrlHost =
    if publicUrlParts == null then
      null
    else
      elemAt publicUrlParts 1;

  publicUrlPort =
    if publicUrlParts == null then
      null
    else
      elemAt publicUrlParts 3;

  environmentKeys = attrNames cfg.environment;

  sensitiveEnvironmentKeys = filter (
    key:
    lib.any (suffix: lib.hasSuffix suffix key) [
      "_KEY"
      "_PASSWORD"
      "_SECRET"
      "_TOKEN"
    ]
  ) environmentKeys;

  publicUrlLooksLikeBackend =
    nginxEnabled
    && publicUrlHost != null
    && publicUrlPort == toString cfg.port
    && builtins.elem publicUrlHost [
      cfg.listenAddress
      "127.0.0.1"
      "localhost"
    ];

  nginxModule = import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix" {
    inherit config lib;
  };

  nginxEnabled = cfg.nginx != null;

  nginxListenPorts =
    if !nginxEnabled then
      [ ]
    else
      lib.unique (filter (port: port != null) (map (listen: listen.port) cfg.nginx.listen));

  nginxSslListenPorts =
    if !nginxEnabled then
      [ ]
    else
      lib.unique (filter (port: port != null) (map (listen: if listen.ssl then listen.port else null) cfg.nginx.listen));

  nginxUsesTls = nginxEnabled && (cfg.nginx.forceSSL || cfg.nginx.addSSL || cfg.nginx.onlySSL || nginxSslListenPorts != [ ]);

  nginxScheme = if nginxUsesTls then "https" else "http";

  nginxPort =
    if !nginxEnabled then
      null
    else if nginxSslListenPorts != [ ] then
      head nginxSslListenPorts
    else if nginxListenPorts != [ ] then
      head nginxListenPorts
    else if nginxUsesTls then
      443
    else
      80;

  nginxPortSuffix =
    if !nginxEnabled || nginxPort == null then
      ""
    else
      let
        defaultPort = if nginxScheme == "https" then 443 else 80;
      in
      optionalString (nginxPort != defaultPort) ":${toString nginxPort}";

  derivedNginxOrigins =
    if !nginxEnabled || cfg.nginx.serverName == null then
      [ ]
    else
      map (host: "${nginxScheme}://${host}${nginxPortSuffix}") ([ cfg.nginx.serverName ] ++ cfg.nginx.serverAliases);

  publicUrl =
    if cfg.publicUrl != null then
      cfg.publicUrl
    else if derivedNginxOrigins != [ ] then
      head derivedNginxOrigins
    else
      null;

  managedCorsOrigins = lib.unique ((optional (publicUrl != null) publicUrl) ++ derivedNginxOrigins ++ cfg.corsOrigins);
  managedTrustedOrigins =
    lib.unique ((optional (publicUrl != null) publicUrl) ++ derivedNginxOrigins ++ cfg.trustedOrigins);

  backendHost = if lib.hasInfix ":" cfg.listenAddress then "[${cfg.listenAddress}]" else cfg.listenAddress;
  backendUrl = "http://${backendHost}:${toString cfg.port}";

  managedEnvironment =
    cfg.environment
    // {
      AUTH_MODE = cfg.authMode;
      CORS_ORIGINS = lib.concatStringsSep "," managedCorsOrigins;
      CORS_ORIGIN_REGEX = if cfg.corsOriginRegex == null then "" else cfg.corsOriginRegex;
      DATABASE_DRIVER = cfg.database.driver;
      DATABASE_URL = if cfg.database.url == null then defaultDatabaseUrl else cfg.database.url;
      HOST = cfg.listenAddress;
      NODE_ENV = "production";
      PORT = cfg.port;
      TRUSTED_ORIGINS = lib.concatStringsSep "," managedTrustedOrigins;
    }
    // optionalAttrs (publicUrl != null) {
      APP_URL = publicUrl;
      BETTER_AUTH_URL = publicUrl;
    };

  generatedEnvironmentFile = envFormat.generate "${serviceName}-env" managedEnvironment;

  reservedEnvironmentKeys = [
    "APP_URL"
    "AUTH_MODE"
    "BETTER_AUTH_URL"
    "CORS_ORIGINS"
    "CORS_ORIGIN_REGEX"
    "DATABASE_DRIVER"
    "DATABASE_URL"
    "HOST"
    "NODE_ENV"
    "PORT"
    "TRUSTED_ORIGINS"
  ];

  invalidEnvironmentKeys = filter (key: hasAttr key cfg.environment) reservedEnvironmentKeys;

  firewallPorts =
    if !nginxEnabled || !cfg.nginx.openFirewall then
      [ ]
    else if nginxListenPorts != [ ] then
      nginxListenPorts
    else if cfg.nginx.onlySSL then
      [ 443 ]
    else if cfg.nginx.forceSSL || cfg.nginx.addSSL then
      [ 80 443 ]
    else
      [ 80 ];

  nginxExtraLocations = if nginxEnabled then cfg.nginx.locations else { };
  nginxVhostConfig = if nginxEnabled then lib.removeAttrs cfg.nginx [ "locations" "openFirewall" "root" ] else { };
in
{
  options.services.thunderbolt = {
    enable = mkEnableOption "Thunderbolt self-hosted web service";

    package = mkOption {
      type = types.package;
      default = tixpkgs.thunderbolt.override {
        inherit (cfg) authMode;
        cloudUrl = "/v1";
      };
      defaultText = literalExpression ''
        tixpkgs.thunderbolt.override {
          authMode = config.services.thunderbolt.authMode;
          cloudUrl = "/v1";
        }
      '';
      description = ''
        Thunderbolt package to run.

        The module defaults to a locally built frontend bundle that points the web UI
        at `/v1` and matches `services.thunderbolt.authMode`.
      '';
    };

    authMode = mkOption {
      type = types.enum [
        "consumer"
        "oidc"
      ];
      default = "oidc";
      description = ''
        Authentication mode baked into the frontend and passed to the backend.

        `oidc` matches the upstream self-hosting flow best. `consumer` can be used for
        email OTP / third-party OAuth flows when the required upstream environment
        variables are supplied.
      '';
    };

    environmentFile = mkOption {
      type = types.path;
      default = "/dev/null";
      example = "/run/secrets/thunderbolt.env";
      description = ''
        Environment file loaded by the Thunderbolt backend.

        This is the recommended place for secrets such as `BETTER_AUTH_SECRET`,
        `OIDC_CLIENT_SECRET`, `RESEND_API_KEY`, inference provider API keys, and
        PowerSync secrets.
      '';
    };

    environment = mkOption {
      type = envFormat.type;
      default = { };
      example = {
        OIDC_ISSUER = "https://sso.example.com/realms/thunderbolt";
        OIDC_CLIENT_ID = "thunderbolt";
        POSTHOG_API_KEY = "phc_example";
        THUNDERBOLT_INFERENCE_URL = "https://llm.example.com/v1";
      };
      description = ''
        Non-secret environment variables passed to the Thunderbolt backend.

        Secrets should go in `services.thunderbolt.environmentFile` instead.

        `APP_URL`, `AUTH_MODE`, `BETTER_AUTH_URL`, `CORS_ORIGINS`,
        `CORS_ORIGIN_REGEX`, `DATABASE_DRIVER`, `DATABASE_URL`, `HOST`, `NODE_ENV`,
        `PORT`, and `TRUSTED_ORIGINS` are managed by dedicated module options and must
        not be set here.
      '';
    };

    stateDir = mkOption {
      type = types.str;
      default = defaultStateDir;
      example = "/srv/thunderbolt";
      description = ''
        Directory for mutable Thunderbolt state.

        With the default embedded PGlite database, this directory stores the local
        database files.
      '';
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Address on which the Thunderbolt backend listens.

        Keep the default when using the built-in nginx reverse proxy.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = "Backend listen port used by the Thunderbolt API service.";
    };

    publicUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://thunderbolt.example.com";
      description = ''
        Canonical public URL used for auth callbacks, backend origin checks, and the
        generated frontend configuration.

        If unset, a URL is derived from `services.thunderbolt.nginx.serverName` and
        the nginx TLS configuration.
      '';
    };

    corsOrigins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "https://alt.example.com" ];
      description = "Additional exact origins appended to `CORS_ORIGINS`.";
    };

    trustedOrigins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "https://alt.example.com" ];
      description = "Additional origins appended to `TRUSTED_ORIGINS`.";
    };

    corsOriginRegex = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "^https://preview-[0-9]+\\.example\\.com$";
      description = ''
        Optional regex assigned to `CORS_ORIGIN_REGEX`.

        Leave this as `null` to disable regex-based CORS origins and rely only on the
        explicit origins managed by the module.
      '';
    };

    database = {
      driver = mkOption {
        type = types.enum [
          "pglite"
          "postgres"
        ];
        default = "pglite";
        description = ''
          Database driver used by Thunderbolt.

          `pglite` uses an embedded database inside `services.thunderbolt.stateDir`.
          `postgres` expects `services.thunderbolt.database.url` to point at an
          external PostgreSQL server.
        '';
      };

      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "postgresql://thunderbolt:secret@127.0.0.1:5432/thunderbolt";
        defaultText = literalExpression ''"${config.services.thunderbolt.stateDir}/db"'';
        description = ''
          Database URL passed to Thunderbolt.

          When unset and `services.thunderbolt.database.driver = "pglite"`, the module
          uses `${defaultStateDir}/db` relative to the configured `stateDir`.
        '';
      };
    };

    webRoot = mkOption {
      type = types.path;
      readOnly = true;
      description = "Generated Thunderbolt frontend document root for external web servers.";
    };

    user = mkOption {
      type = types.str;
      default = "thunderbolt";
      description = "User account under which the Thunderbolt backend runs.";
    };

    group = mkOption {
      type = types.str;
      default = "thunderbolt";
      description = "Group account under which the Thunderbolt backend runs.";
    };

    nginx = mkOption {
      type = types.nullOr (
        types.submodule (
          lib.recursiveUpdate nginxModule {
            options = {
              serverName = {
                default = publicUrlHost;
                defaultText = literalExpression ''<host extracted from config.services.thunderbolt.publicUrl>'';
              };

              openFirewall = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to open the nginx listen ports in the firewall.";
              };
            };
          }
        )
      );
      default = { };
      example = literalExpression ''
        {
          serverName = "thunderbolt.example.com";
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = ''
        With this option, you can customize the nginx virtualHost settings used to
        serve the Thunderbolt frontend and proxy `/v1` to the backend.

        The module manages the vhost `root` and the core `/`, `/assets/`, and `/v1/`
        locations itself.

        Set this to `{}` to enable the default nginx integration or `null` to disable
        nginx and use an external web server.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = invalidEnvironmentKeys == [ ];
          message = "services.thunderbolt.environment must not set managed keys: ${lib.concatStringsSep ", " invalidEnvironmentKeys}";
        }
        {
          assertion = publicUrl != null || derivedNginxOrigins != [ ];
          message = "services.thunderbolt requires services.thunderbolt.publicUrl or services.thunderbolt.nginx.serverName so callback URLs and allowed origins can be derived.";
        }
        {
          assertion = !(nginxEnabled && cfg.nginx.serverName == null);
          message = "services.thunderbolt.nginx.serverName must be set when nginx integration is enabled and services.thunderbolt.publicUrl does not provide a hostname to derive from.";
        }
        {
          assertion = !(cfg.database.driver == "postgres" && cfg.database.url == null);
          message = "services.thunderbolt.database.url must be set when services.thunderbolt.database.driver = \"postgres\".";
        }
        {
          assertion = lib.hasPrefix "/" cfg.stateDir;
          message = "services.thunderbolt.stateDir must be an absolute path.";
        }
        {
          assertion = !(nginxEnabled && cfg.nginx.enableACME && cfg.nginx.useACMEHost != null);
          message = "services.thunderbolt.nginx.enableACME and services.thunderbolt.nginx.useACMEHost are mutually exclusive.";
        }
        {
          assertion = !(nginxEnabled && length (filter lib.id [ cfg.nginx.forceSSL cfg.nginx.addSSL cfg.nginx.onlySSL ]) > 1);
          message = "services.thunderbolt.nginx.addSSL, services.thunderbolt.nginx.onlySSL, and services.thunderbolt.nginx.forceSSL are mutually exclusive.";
        }
      ];

      warnings = optionals (cfg.authMode == "consumer") [
        ''
          services.thunderbolt.authMode = "consumer" expects upstream email OTP or OAuth
          credentials to be supplied through services.thunderbolt.environment or
          services.thunderbolt.environmentFile.
        ''
      ] ++ optionals (sensitiveEnvironmentKeys != [ ]) [
        ''
          services.thunderbolt.environment contains keys that look like secrets:
          ${lib.concatStringsSep ", " sensitiveEnvironmentKeys}

          Values from services.thunderbolt.environment are written to the Nix store.
          Move these keys to services.thunderbolt.environmentFile instead.
        ''
      ] ++ optionals publicUrlLooksLikeBackend [
        ''
          services.thunderbolt.publicUrl appears to point at the backend listen port
          (${cfg.publicUrl}) while nginx integration is enabled.

          Set publicUrl to the frontend origin served by nginx instead (for example
          http://127.0.0.1 rather than http://127.0.0.1:${toString cfg.port}).
        ''
      ];

      services.thunderbolt.webRoot = "${cfg.package}/share/thunderbolt/frontend";

      systemd.services.thunderbolt = {
        description = "Thunderbolt backend service";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [
          cfg.package
          cfg.environmentFile
          generatedEnvironmentFile
        ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.stateDir;
          ExecStart = "${cfg.package}/bin/thunderbolt-backend";
          Restart = "on-failure";
          RestartSec = "5s";
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
          RestrictNamespaces = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          SystemCallArchitectures = "native";
          ReadWritePaths = [ cfg.stateDir ];
          UMask = "0077";
        };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group} -"
      ];

      users.users = optionalAttrs (cfg.user == "thunderbolt") {
        thunderbolt = {
          description = "Thunderbolt service user";
          group = cfg.group;
          home = cfg.stateDir;
          isSystemUser = true;
        };
      };

      users.groups = optionalAttrs (cfg.group == "thunderbolt") {
        thunderbolt = { };
      };
    }
    (mkIf nginxEnabled {
      services.nginx = {
        enable = true;
        recommendedTlsSettings = mkDefault true;
        recommendedGzipSettings = mkDefault true;
        recommendedOptimisation = mkDefault true;
        virtualHosts.${cfg.nginx.serverName} = mkMerge [
          nginxVhostConfig
          {
            root = cfg.webRoot;
            locations = nginxExtraLocations // {
              "/" = {
                tryFiles = "$uri $uri/ /index.html";
                extraConfig = ''
                  add_header Cross-Origin-Embedder-Policy "require-corp" always;
                  add_header Cross-Origin-Opener-Policy "same-origin" always;
                '';
              };

              "/assets/".extraConfig = ''
                expires 1y;
                add_header Cache-Control "public, immutable";
                add_header Cross-Origin-Embedder-Policy "require-corp" always;
                add_header Cross-Origin-Opener-Policy "same-origin" always;
              '';

              "~* \\.map$".return = "404";

              "^~ /v1/".extraConfig = ''
                proxy_pass ${backendUrl}/v1/;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
              '';
            };
          }
        ];
      };
    })
    (mkIf (firewallPorts != [ ]) {
      networking.firewall.allowedTCPPorts = firewallPorts;
    })
  ]);
}
