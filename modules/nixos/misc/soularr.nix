{ config, lib, pkgs, ... }:

let
  cfg = config.services.soularr;

  # For generating the configuration file
  format = pkgs.formats.ini { };
  configObject = {
    Lidarr = {
      api_key = if cfg.settings.lidarr.apiKeyFile != null 
                then "$(cat ${cfg.settings.lidarr.apiKeyFile})"
                else cfg.settings.lidarr.apiKey;
      host_url = cfg.settings.lidarr.hostUrl;
      download_dir = cfg.settings.lidarr.downloadDir;
    };

    Slskd = {
      api_key = if cfg.settings.slskd.apiKeyFile != null 
                then "$(cat ${cfg.settings.slskd.apiKeyFile})"
                else cfg.settings.slskd.apiKey;
      host_url = cfg.settings.slskd.hostUrl;
      download_dir = cfg.settings.slskd.downloadDir;
      delete_searches = cfg.settings.slskd.deleteSearches;
      stalled_timeout = cfg.settings.slskd.stalledTimeout;
    };

    "Release Settings" = {
      use_most_common_tracknum = cfg.settings.release.useMostCommonTrackNum;
      allow_multi_disc = cfg.settings.release.allowMultiDisc;
      accepted_countries = lib.concatStringsSep "," cfg.settings.release.acceptedCountries;
      accepted_formats = lib.concatStringsSep "," cfg.settings.release.acceptedFormats;
    };

    "Search Settings" = {
      search_timeout = cfg.settings.search.timeout;
      maximum_peer_queue = cfg.settings.search.maximumPeerQueue;
      minimum_peer_upload_speed = cfg.settings.search.minimumPeerUploadSpeed;
      allowed_filetypes = lib.concatStringsSep "," cfg.settings.search.allowedFiletypes;
      ignored_users = lib.concatStringsSep "," cfg.settings.search.ignoredUsers;
      search_for_tracks = cfg.settings.search.searchForTracks;
      album_prepend_artist = cfg.settings.search.albumPrependArtist;
      track_prepend_artist = cfg.settings.search.trackPrependArtist;
      search_type = cfg.settings.search.searchType;
      number_of_albums_to_grab = cfg.settings.search.numberOfAlbumsToGrab;
      remove_wanted_on_failure = cfg.settings.search.removeWantedOnFailure;
      title_blacklist = lib.concatStringsSep "," cfg.settings.search.titleBlacklist;
    };

    Logging = {
      level = cfg.settings.logging.level;
      format = cfg.settings.logging.format;
      datefmt = cfg.settings.logging.datefmt;
    };
  };
  configFile = format.generate "soularr-config.ini" configObject;

in {
  options.services.soularr = {
    enable = lib.mkEnableOption (lib.mdDoc "Soularr service");

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.soularr; # TODO: ASK if this works
      defaultText = lib.literalExpression "pkgs.soularr";
      description = lib.mdDoc "Soularr package to use.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "5m";
      example = "1h";
      description = lib.mdDoc ''
        How often to run Soularr.
        Systemd time interval format, e.g. "5m" for 5 minutes, "1h" for hourly, "1d" for daily.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "soularr";
      description = lib.mdDoc "User account under which soularr runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "soularr";
      description = lib.mdDoc "Group under which soularr runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/soularr";
      description = lib.mdDoc "Directory where soularr stores its data.";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        options = {
          lidarr = lib.mkOption {
            type = lib.types.submodule {
              options = {
                apiKeyFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = lib.mdDoc ''
                    The full path to a file that contains the Lidarr API key.
                    Must be readable by the soularr user.
                  '';
                };
                apiKey = lib.mkOption {
                  type = lib.types.str;
                  description = lib.mdDoc ''
                    Lidarr API key. Not recommended to use directly - use apiKeyFile instead.
                  '';
                };
                hostUrl = lib.mkOption {
                  type = lib.types.str;
                  default = "http://localhost:8686";
                  description = lib.mdDoc "Lidarr host URL.";
                };
                downloadDir = lib.mkOption {
                  type = lib.types.path;
                  description = lib.mdDoc "Path mounted in Lidarr that points to Slskd download directory.";
                };
              };
            };
          };

          slskd = lib.mkOption {
            type = lib.types.submodule {
              options = {
                apiKeyFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = lib.mdDoc ''
                    The full path to a file that contains the Slskd API key.
                    Must be readable by the soularr user.
                  '';
                };
                apiKey = lib.mkOption {
                  type = lib.types.str;
                  description = lib.mdDoc ''
                    Slskd API key. Not recommended to use directly - use apiKeyFile instead.
                  '';
                };
                hostUrl = lib.mkOption {
                  type = lib.types.str;
                  default = "http://localhost:5030";
                  description = lib.mdDoc "Slskd host URL.";
                };
                downloadDir = lib.mkOption {
                  type = lib.types.path;
                  description = lib.mdDoc "Slskd download directory.";
                };
                deleteSearches = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = lib.mdDoc "Remove searches from Slskd after completion.";
                };
                stalledTimeout = lib.mkOption {
                  type = lib.types.int;
                  default = 3600;
                  description = lib.mdDoc "Maximum time in seconds to wait for downloads.";
                };
              };
            };
          };

          release = lib.mkOption {
            type = lib.types.submodule {
              options = {
                useMostCommonTrackNum = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = lib.mdDoc "Select release with most common track count.";
                };
                allowMultiDisc = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = lib.mdDoc "Allow multi-disc releases.";
                };
                acceptedCountries = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ "Europe" "Japan" "United Kingdom" "United States" "[Worldwide]" "Australia" "Canada" ];
                  description = lib.mdDoc "List of accepted countries.";
                };
                acceptedFormats = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ "CD" "Digital Media" "Vinyl" ];
                  description = lib.mdDoc "List of accepted formats.";
                };
              };
            };
          };

          search = lib.mkOption {
            type = lib.types.submodule {
              options = {
                timeout = lib.mkOption {
                  type = lib.types.int;
                  default = 5000;
                  description = lib.mdDoc "Search timeout.";
                };
                maximumPeerQueue = lib.mkOption {
                  type = lib.types.int;
                  default = 50;
                  description = lib.mdDoc "Maximum peer queue size.";
                };
                minimumPeerUploadSpeed = lib.mkOption {
                  type = lib.types.int;
                  default = 0;
                  description = lib.mdDoc "Minimum peer upload speed in bit/s.";
                };
                allowedFiletypes = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ "flac" "mp3" ];
                  description = lib.mdDoc "List of allowed file types.";
                };
                ignoredUsers = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = lib.mdDoc "List of users to ignore.";
                };
                searchForTracks = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = lib.mdDoc "Whether to search for individual tracks.";
                };
                albumPrependArtist = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = lib.mdDoc "Prepend artist name to album searches.";
                };
                trackPrependArtist = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = lib.mdDoc "Prepend artist name to track searches.";
                };
                searchType = lib.mkOption {
                  type = lib.types.enum [ "all" "incrementing_page" "first_page" ];
                  default = "incrementing_page";
                  description = lib.mdDoc "Search type strategy.";
                };
                numberOfAlbumsToGrab = lib.mkOption {
                  type = lib.types.int;
                  default = 10;
                  description = lib.mdDoc "Number of albums to grab per run.";
                };
                removeWantedOnFailure = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = lib.mdDoc "Unmonitor albums that can't be found.";
                };
                titleBlacklist = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = lib.mdDoc "List of blacklisted words in titles.";
                };
              };
            };
          };

          logging = lib.mkOption {
            type = lib.types.submodule {
              options = {
                level = lib.mkOption {
                  type = lib.types.enum [ "DEBUG" "INFO" "WARNING" "ERROR" "CRITICAL" ];
                  default = "INFO";
                  description = lib.mdDoc "Logging level.";
                };
                format = lib.mkOption {
                  type = lib.types.str;
                  default = "[%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s";
                  description = lib.mdDoc "Log message format.";
                };
                datefmt = lib.mkOption {
                  type = lib.types.str;
                  default = "%Y-%m-%dT%H:%M:%S%z";
                  description = lib.mdDoc "Log date format.";
                };
              };
            };
          };
        };
      };
      description = lib.mdDoc "Soularr configuration options.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      group = cfg.group;
      isSystemUser = true;
      createHome = true;
      home = cfg.dataDir;
    };

    users.groups.${cfg.group} = {};

    systemd.timers.soularr = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.interval;
        OnUnitActiveSec = cfg.interval;
        Unit = "soularr.service";
      };
    };

    systemd.services.soularr = {
      description = "Soularr Service";
      after = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStartPre = pkgs.writeScript "soularr-setup" ''
          #!${pkgs.bash}/bin/bash
          mkdir -p ${cfg.dataDir}
          cp ${configFile} ${cfg.dataDir}/config.ini
          chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
        '';
        ExecStart = "${cfg.package}/bin/soularr";
        WorkingDirectory = cfg.dataDir;
        # Basic hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        NoNewPrivileges = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateMounts = true;
        # Allowing network access
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        # Allowing writing to dataDir
        ReadWritePaths = [ cfg.dataDir ];
      };
    };
  };
}
