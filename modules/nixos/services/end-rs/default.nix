{tixpkgs}:
# check out my module :)
# rest is provided by user nixos config, we cant control their params
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.services.end-rs;
in {
  meta.maintainers = ["74k1"];

  options = {
    services.end-rs = {
      enable = lib.mkEnableOption ''
        end-rs, the eww notification daemon (in Rust).
      '';

      package = mkOption {
        type = types.package;
        default = tixpkgs.end-rs;
        defaultText = lib.literalExpression "tixpkgs.end-rs";
        description = "The end package to use.";
      };

      systemd.target = mkOption {
        type = types.str;
        default = "graphical-session.target";
        example = "sway-session.target";
        description = ''
          The systemd target that will automatically start the end-rs service.
          When setting this value to `"sway-session.target"`,
          make sure to also enable {option}`wayland.windowManager.sway.systemd.enable`,
          otherwise the service may never be started.
        '';
      };

      config = mkOption {
        default = {};
        type = types.submodule {
          options = {
            icon_pkgs = mkOption {
              type = types.listOf types.package;
              default = [pkgs.adwaita-icon-theme];
              description = "Icon packages to use.";
            };
            icon_theme = mkOption {
              type = types.str;
              default = "Adwaita";
              description = "The theme to use for the icons";
            };
            eww = mkOption {
              default = {};
              type = types.submodule {
                options = {
                  package = mkOption {
                    type = types.package;
                    default = pkgs.eww;
                    description = "The eww package to use.";
                  };

                  notification = mkOption {
                    default = {};
                    type = types.submodule {
                      options = {
                        window = mkOption {
                          type = types.str;
                          default = "notification-frame";
                          description = "Can be a single string or a vector of strings(for multi-monitor support)";
                        };

                        widget = mkOption {
                          type = types.str;
                          default = "end-notification";
                          description = "The default notification widget";
                        };

                        var = mkOption {
                          type = types.str;
                          default = "end-notifications";
                          description = "The variable which contains the literal for the notifications";
                        };
                      };
                    };
                  };

                  history = mkOption {
                    default = {};
                    type = types.submodule {
                      options = {
                        window = mkOption {
                          type = types.str;
                          default = "history-frame";
                          description = "The default history window";
                        };

                        widget = mkOption {
                          type = types.str;
                          default = "end-history";
                          description = "The default history widget";
                        };

                        var = mkOption {
                          type = types.str;
                          default = "end-histories";
                          description = "The variable which contains the literal for the history";
                        };
                      };
                    };
                  };

                  reply = mkOption {
                    default = {};
                    type = types.submodule {
                      options = {
                        window = mkOption {
                          type = types.str;
                          default = "reply-frame";
                          description = "The default reply window";
                        };

                        widget = mkOption {
                          type = types.str;
                          default = "end-reply";
                          description = "The default reply widget";
                        };

                        var = mkOption {
                          type = types.str;
                          default = "end-replies";
                          description = "The variable which contains the literal for the replies";
                        };

                        text = mkOption {
                          type = types.str;
                          default = "end-reply-text";
                          description = "The variable which contains content for the reply text";
                        };
                      };
                    };
                  };
                };
              };
            };

            max_notifications = mkOption {
              type = types.int;
              default = 10;
              description = "Max notifications to be preserved in history. In case of 0, all notifications will be preserved.";
            };

            notification_orientation = mkOption {
              type = types.str;
              default = "v";
              description = "The orientation of the notifications. Can be either 'v' or 'h' or 'vertical' or 'horizontal' (Basically the eww orientation value)";
            };

            update_history = mkOption {
              type = types.bool;
              default = false;
              description = "Update history when a new notification is added";
            };

            timeout = mkOption {
              default = {};
              description = "The timeouts for different types of notifications in seconds. A value of 0 means that the notification will never timeout";
              type = types.submodule {
                options = {
                  low = mkOption {
                    type = types.int;
                    default = 5;
                  };
                  normal = mkOption {
                    type = types.int;
                    default = 10;
                  };
                  critical = mkOption {
                    type = types.int;
                    default = 0;
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # Include package in PATH by default
      cfg.package
    ];

    xdg.configFile."end-rs/config.toml" = let
      iconDirs = lib.flatten (map (p: "${p}/share/icons") cfg.config.icon_pkgs);

      configOptions = {
        eww_binary_path = lib.getExe cfg.config.eww.package;
        icon_dirs = iconDirs;
        icon_theme = cfg.config.icon_theme;
        eww_notification_window = cfg.config.eww.notification.window;
        eww_notification_widget = cfg.config.eww.notification.widget;
        eww_notification_var = cfg.config.eww.notification.var;
        eww_history_window = cfg.config.eww.history.window;
        eww_history_widget = cfg.config.eww.history.widget;
        eww_history_var = cfg.config.eww.history.var;
        eww_reply_window = cfg.config.eww.reply.window;
        eww_reply_widget = cfg.config.eww.reply.widget;
        eww_reply_var = cfg.config.eww.reply.var;
        eww_reply_text = cfg.config.eww.reply.text;
        max_notifications = cfg.config.max_notifications;
        notification_orientation = cfg.config.notification_orientation;
        update_history = cfg.config.update_history;
        timeout = cfg.config.timeout;
      };

      generatedToml = (pkgs.formats.toml {}).generate "config.toml" configOptions;
    in {
      onChange = "${lib.getExe' pkgs.systemd "systemctl"} --user restart end-rs.service";
      source = generatedToml;
    };

    systemd.user.services.end-rs = {
      Unit = {
        Description = "eww notification daemon service";
        Documentation = "https://github.com/Dr-42/end-rs";
        After = [cfg.systemd.target];
        PartOf = [cfg.systemd.target];
      };

      Service = {
        ExecStart = "${lib.getExe cfg.package} daemon";
      };

      Install = {WantedBy = [cfg.systemd.target];};
    };
  };
}
