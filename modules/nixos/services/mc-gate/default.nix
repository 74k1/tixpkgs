{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mc-gate;
  rawYaml = (pkgs.formats.yaml { }).generate "gate-config.yaml" { inherit (cfg) config; };
  fixedYaml = pkgs.runCommand "gate-config-fixed.yaml" { buildInputs = [ pkgs.gnused ]; } ''
    cp ${rawYaml} config.yaml
    # VERY NAIVE: only works for the exact layout produced now
    sed -E -i '
      s/- backend: ([^[:space:]]+)[[:space:]]+host: ([^[:space:]]+)/- host: \2\n  backend: \1/
    ' config.yaml
    cp config.yaml $out
  '';
in
{
  options.services.mc-gate = {
    enable = lib.mkEnableOption "Gate Service";
    config = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Configuration for the gate minecraft proxy service";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.mc-gate = {
      description = "Gate Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.gate}/bin/gate -c ${fixedYaml}";
        Restart = "always";
        User = "root";
      };
    };
  };
}
