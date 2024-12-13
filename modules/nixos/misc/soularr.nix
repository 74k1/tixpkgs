{ inputs
, outputs
, config
, lib
, pkgs
, ...
}:

let
  cfg = config.services.soularr;
in {
  options.services.soularr = {
    enable = lib.mkEnableOption "Soularr service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage "${inputs.self}/pkgs/soularr.nix" { inherit pkgs; };
      description = "Soularr package to use.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "soularr";
      description = "User account under which soularr runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "soularr";
      description = "Group under which soularr runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/soularr";
      description = "Directory where soularr stores its data files.";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        options = {
          lidarr = lib.mkOption {
            type = lib.types.submodule {
              options = {
                apiKey = lib.mkOption {
                  type = lib.types.str;
                  description = "Lidarr API key";
                };
                hostUrl = lib.mkOption {
                  type = lib.types.str;
                  default = "http://localhost:8686";
                  description = "Lidarr host URL";
                };
                downloadDir = lib.mkOption {
                  type = lib.types.path;
                  description = "Lidarr download directory";
                };
              };
            };
          };

          slskd = lib.mkOption {
            type = lib.types.submodule {
              options = {
                apiKey = lib.mkOption {
                  type = lib.types.str;
                  description = "Slskd API key";
                };
                hostUrl = lib.mkOption {
                  type = lib.types.str;
                  default = "http://localhost:5030";
                  description = "Slskd host URL";
                };
                downloadDir = lib.mkOption {
                  type = lib.types.path;
                  description = "Slskd download directory";
                };
              };
            };
          };
        };
      };
      description = "Soularr configuration options.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
    };
    
    users.groups.${cfg.group} = {};

    systemd.services.soularr = {
      description = "Soularr Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStartPre = let
          configFile = pkgs.writeText "soularr-config.ini" ''
            [Lidarr]
            api_key = ${cfg.settings.lidarr.apiKey}
            host_url = ${cfg.settings.lidarr.hostUrl}
            download_dir = ${cfg.settings.lidarr.downloadDir}

            [Slskd]
            api_key = ${cfg.settings.slskd.apiKey}
            host_url = ${cfg.settings.slskd.hostUrl}
            download_dir = ${cfg.settings.slskd.downloadDir}
            delete_searches = False
            stalled_timeout = 3600

            [Release Settings]
            use_most_common_tracknum = True
            allow_multi_disc = True
            accepted_countries = Europe,Japan,United Kingdom,United States,[Worldwide],Australia,Canada
            accepted_formats = CD,Digital Media,Vinyl

            [Search Settings]
            search_timeout = 5000
            maximum_peer_queue = 50
            minimum_peer_upload_speed = 0
            allowed_filetypes = flac,mp3
            search_for_tracks = True
            album_prepend_artist = False
            track_prepend_artist = True
            search_type = incrementing_page
            number_of_albums_to_grab = 10
            remove_wanted_on_failure = False

            [Logging]
            level = INFO
            format = [%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s
            datefmt = %Y-%m-%dT%H:%M:%S%z
          '';
        in
          pkgs.writeScript "soularr-setup" ''
            #!${pkgs.bash}/bin/bash
            mkdir -p ${cfg.dataDir}
            cp ${configFile} ${cfg.dataDir}/config.ini
            chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
          '';
        ExecStart = "${cfg.package}/bin/soularr";
        WorkingDirectory = cfg.dataDir;
        Restart = "always";
        RestartSec = "300";
      };
    };
  };
}
