{
  config,
  lib,
  pkgs,
  inputs ? null,
  ...
}:
let
  inherit (lib)
    concatLines
    literalExpression
    mapAttrs
    mapAttrsToList
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    optional
    optionalAttrs
    optionalString
    types
    ;

  cfg = config.services.fourget;
  nginxCfg = cfg.nginx;
  poolName = "fourget";
  fpm = config.services.phpfpm.pools.${poolName};
  servesHttps =
    if nginxCfg != null then nginxCfg.forceSSL || nginxCfg.addSSL || nginxCfg.onlySSL else false;

  publicUrl =
    if cfg.publicUrl != null then
      cfg.publicUrl
    else
      let
        scheme = if servesHttps then "https" else "http";
        defaultPort = if scheme == "https" then 443 else 80;
        actualPort = defaultPort;
        portSuffix = optionalString (actualPort != defaultPort) ":${toString actualPort}";
      in
      "${scheme}://${cfg.hostname}${portSuffix}";

  phpLiteral =
    value:
    if value == null then
      "null"
    else if builtins.isBool value then
      if value then "true" else "false"
    else if builtins.isInt value || builtins.isFloat value then
      toString value
    else if builtins.isString value then
      "'${lib.replaceStrings [ "\\" "'" ] [ "\\\\" "\\'" ] value}'"
    else if builtins.isList value then
      "[ ${lib.concatMapStringsSep ", " phpLiteral value} ]"
    else if builtins.isAttrs value then
      "[ ${
        lib.concatStringsSep ", " (
          mapAttrsToList (name: nestedValue: "${phpLiteral name} => ${phpLiteral nestedValue}") value
        )
      } ]"
    else
      throw "services.fourget.settings contains an unsupported value type";

  defaultSettings = {
    VERSION = 8;
    SERVER_NAME = "4get";
    SERVER_SHORT_DESCRIPTION = "4get is a proxy search engine that doesn't suck.";
    SERVER_LONG_DESCRIPTION = null;
    DEFAULT_THEME = "Dark";
    API_ENABLED = true;
    BOT_PROTECTION = 0;
    CAPTCHA_DATASET = [ ];
    HEADER_REGEX = "/bot|wget|curl|python-requests|scrapy|go-http-client|ruby|yahoo|spider|qwant|meta/i";
    FILTERED_HEADER_KEYS = [ ];
    DISALLOWED_SSL = [ ];
    MAX_SEARCHES = 100;
    ALT_ADDRESSES = [ ];
    INSTANCES = optional (publicUrl != null) publicUrl;
    USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0";
    PROXY_DDG = false;
    PROXY_YAHOO = false;
    PROXY_YAHOO_JAPAN = false;
    PROXY_BRAVE = false;
    PROXY_FB = false;
    PROXY_GOOGLE = false;
    PROXY_GOOGLE_API = false;
    PROXY_GOOGLE_CSE = false;
    PROXY_MULLVAD_GOOGLE = false;
    PROXY_MULLVAD_BRAVE = false;
    PROXY_STARTPAGE = false;
    PROXY_QWANT = false;
    PROXY_BAIDU = false;
    PROXY_COCCOC = false;
    PROXY_GHOSTERY = false;
    PROXY_MARGINALIA = false;
    PROXY_MOJEEK = false;
    PROXY_SC = false;
    PROXY_SWISSCOWS = false;
    PROXY_SPOTIFY = false;
    PROXY_SOLOFIELD = false;
    PROXY_WIBY = false;
    PROXY_CURLIE = false;
    PROXY_YT = false;
    PROXY_ARCHIVEORG = false;
    PROXY_SEPIASEARCH = false;
    PROXY_ODYSEE = false;
    PROXY_VIMEO = false;
    PROXY_YEP = false;
    PROXY_PINTEREST = false;
    PROXY_SANKAKUCOMPLEX = false;
    PROXY_FLICKR = false;
    PROXY_FIVEHPX = false;
    PROXY_VSCO = false;
    PROXY_SEZNAM = false;
    PROXY_NAVER = false;
    PROXY_GREPPR = false;
    PROXY_CROWDVIEW = false;
    PROXY_MWMBL = false;
    PROXY_FTM = false;
    PROXY_IMGUR = false;
    PROXY_CARA = false;
    PROXY_YANDEX_W = false;
    PROXY_YANDEX_I = false;
    PROXY_YANDEX_V = false;
    GOOGLE_CX_ENDPOINT = "d4e68b99b876541f0";
    MARGINALIA_API_KEY = null;
  };

  renderedConfig = pkgs.writeText "fourget-config.php" ''
    <?php
    class config{
    ${concatLines (
      mapAttrsToList (name: value: "  const ${name} = ${phpLiteral value};") (
        defaultSettings // cfg.settings
      )
    )}
    }
  '';

  renderedRobots = pkgs.writeText "fourget-robots.txt" ''
    User-agent: *
    Disallow:
    Host: ${cfg.hostname}
    Sitemap: ${if publicUrl != null then "${publicUrl}/sitemap" else "http://localhost/sitemap"}
  '';

  webRoot = pkgs.runCommand "fourget-web-root" { } ''
    mkdir -p "$out/share"
    cp -r ${cfg.package}/share/4get "$out/share/4get"
    chmod -R u+w "$out/share/4get"

    rm -f "$out/share/4get/data/config.php" "$out/share/4get/robots.txt"
    rm -rf "$out/share/4get/icons" "$out/share/4get/data/proxies" "$out/share/4get/data/api_keys"

    ln -s ${renderedConfig} "$out/share/4get/data/config.php"
    ln -s ${renderedRobots} "$out/share/4get/robots.txt"
    ln -s "${cfg.stateDir}/icons" "$out/share/4get/icons"
    ln -s "${cfg.stateDir}/proxies" "$out/share/4get/data/proxies"
    ln -s "${cfg.stateDir}/api_keys" "$out/share/4get/data/api_keys"
  '';

  fourgetPhp = cfg.phpPackage.buildEnv {
    extensions =
      { enabled, all }:
      enabled
      ++ (with all; [
        apcu
        curl
        imagick
        mbstring
        sodium
      ]);
  };

  niksPath =
    if inputs != null then
      "${inputs.nixpkgs}/nixos/modules/services/web-servers/nginx/vhost-options.nix"
    else
      "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix";
in
{
  meta.maintainers = [ "74k1" ];

  options.services.fourget = {
    enable = mkEnableOption "4get";

    package = mkPackageOption pkgs "fourget" { };

    hostname = mkOption {
      type = types.str;
      default = "localhost";
      example = "search.example.com";
      description = "Hostname to serve 4get on. Used for generating the base URL and robots.txt.";
    };

    phpPackage = mkOption {
      type = types.package;
      default = pkgs.php;
      defaultText = literalExpression "pkgs.php";
      description = "Base PHP package used to build the fourget PHP-FPM environment.";
    };

    nginx = mkOption {
      type = types.nullOr (
        types.submodule (lib.recursiveUpdate (import niksPath { inherit config lib; }).options { })
      );
      default = null;
      example = literalExpression ''
        {
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = ''
        nginx virtual host configuration for 4get.
        Set to a non-null value to enable the nginx reverse proxy.
        See `services.nginx.virtualHosts` for available options.
      '';
    };

    publicUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://search.example.com";
      description = ''
        Canonical public URL used for generated defaults such as `robots.txt` and `INSTANCES`.
        Defaults to `http''${s}://''${services.fourget.hostname}` when unset.
      '';
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/fourget";
      description = "Directory for mutable fourget state such as icons, proxies, and API key files.";
    };

    webRoot = mkOption {
      type = types.path;
      readOnly = true;
      description = "Generated fourget document root for use with an external web server.";
    };

    socket = mkOption {
      type = types.str;
      readOnly = true;
      description = "PHP-FPM socket path for use with an external web server.";
    };

    user = mkOption {
      type = types.str;
      default = "fourget";
      description = "User account under which the fourget PHP-FPM pool runs.";
    };

    group = mkOption {
      type = types.str;
      default = "fourget";
      description = "Group account under which the fourget PHP-FPM pool runs.";
    };

    poolSettings = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.int
          types.bool
        ]
      );
      default = { };
      description = "Additional PHP-FPM pool directives for fourget. Merged on top of the module defaults.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        LD_PRELOAD = "/usr/local/lib/libcurl-impersonate-ff.so";
        CURL_IMPERSONATE = "firefox117";
      };
      description = "Environment variables passed to the fourget PHP-FPM pool.";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      example = {
        SERVER_NAME = "Example 4get";
        SERVER_LONG_DESCRIPTION = "Private instance";
        API_ENABLED = false;
      };
      description = ''
        Upstream `data/config.php` constants to override.
        Attribute names must match the upstream constant names exactly.
        Values defined here are written into the Nix store, so secrets should not be placed here.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.fourget.webRoot = "${webRoot}/share/4get";
      services.fourget.socket = fpm.socket;

      services.phpfpm.pools.${poolName} = {
        user = cfg.user;
        group = cfg.group;
        phpPackage = fourgetPhp;
        phpEnv = cfg.environment;
        settings =
          (mapAttrs (_: mkDefault) {
            "chdir" = "${webRoot}/share/4get";
            "listen.owner" = if nginxCfg != null then config.services.nginx.user else cfg.user;
            "listen.group" = if nginxCfg != null then config.services.nginx.group else cfg.group;
            "listen.mode" = "0660";
            "catch_workers_output" = true;
            "php_admin_flag[log_errors]" = true;
            "php_admin_value[error_log]" = "stderr";
            "pm" = "dynamic";
            "pm.max_children" = 16;
            "pm.start_servers" = 2;
            "pm.min_spare_servers" = 1;
            "pm.max_spare_servers" = 4;
          })
          // cfg.poolSettings;
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/icons 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/proxies 0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/api_keys 0750 ${cfg.user} ${cfg.group} -"
      ];

      users.users = optionalAttrs (cfg.user == "fourget") {
        fourget = {
          description = "fourget service user";
          group = cfg.group;
          home = cfg.stateDir;
          isSystemUser = true;
        };
      };

      users.groups = optionalAttrs (cfg.group == "fourget") {
        fourget = { };
      };
    }
    (mkIf (nginxCfg != null) {
      services.nginx = {
        enable = true;
        recommendedTlsSettings = mkDefault true;
        recommendedGzipSettings = mkDefault true;
        recommendedOptimisation = mkDefault true;
        virtualHosts.${cfg.hostname} = mkMerge [
          nginxCfg
          {
            root = cfg.webRoot;
            locations = {
              "/" = {
                index = "index.php";
                tryFiles = "$uri $uri/ @fourget_php";
              };
              "@fourget_php".extraConfig = ''
                rewrite ^/$ /index.php last;
                rewrite ^/(.*)$ /$1.php last;
              '';
              "~ \\.php$".extraConfig = ''
                try_files $uri =404;
                fastcgi_pass unix:${cfg.socket};
                fastcgi_index index.php;
                include ${config.services.nginx.package}/conf/fastcgi.conf;
                fastcgi_intercept_errors on;
              '';
              "^~ /data/".return = "403";
            };
          }
        ];
      };
    })
  ]);
}
