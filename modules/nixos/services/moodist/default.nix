{ tixpkgs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.moodist;

  inherit (lib)
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    optional
    types
    ;

  nginxVhostOptions =
    import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix"
      {
        inherit config lib;
      };

  nginxEnabled = cfg.nginx != null;

  spaTryFiles = "$uri $uri/ /index.html";
in
{
  meta.maintainers = with lib.maintainers; [ _74k1 ];

  options.services.moodist = {
    enable = mkEnableOption "Moodist, an ambient sounds web app";

    package = mkPackageOption tixpkgs "moodist" { };

    hostname = mkOption {
      type = types.str;
      default = "localhost";
      example = "moodist.example.com";
      description = ''
        Hostname for the nginx virtual host that serves the Moodist site.

        With a public domain, set this together with the nginx option to get a
        TLS-served site via ACME. With the default `localhost`, the site is
        served over plain HTTP on port 80.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the HTTP/HTTPS ports (80/443) in the firewall.";
    };

    nginx = mkOption {
      type = types.nullOr (types.submodule (lib.recursiveUpdate nginxVhostOptions { }));
      default = null;
      example = literalExpression ''
        {
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = ''
        nginx virtual host configuration for Moodist, e.g. TLS / ACME options.
        Set to a non-null value to enable automatic HTTPS.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = mkDefault true;
      recommendedProxySettings = mkDefault true;
      recommendedGzipSettings = mkDefault true;
      recommendedOptimisation = mkDefault true;
      recommendedTlsSettings = mkDefault true;

      virtualHosts.${cfg.hostname} = mkMerge [
        (if cfg.nginx != null then cfg.nginx else { })
        {
          root = cfg.package;
          locations."/" = {
            tryFiles = spaTryFiles;
          };
        }
      ];
    };

    networking.firewall.allowedTCPPorts =
      optional cfg.openFirewall 80
      ++ optional (nginxEnabled && (cfg.nginx.forceSSL or false || cfg.nginx.enableACME or false)) 443;
  };
}
