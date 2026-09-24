{ module, pkgs, ... }:
{
  name = "multi-scrobbler-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [
      pkgs.curl
      pkgs.jq
    ];

    virtualisation.memorySize = 2048;

    services.multi-scrobbler = {
      enable = true;

      # Ingress-only source with optional data: exercises managed config files
      # without any outbound connections.
      configFiles.webscrobbler = {
        name = "webscrobbler_test_source";
      };
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("multi-scrobbler.service")
    machine.wait_for_open_port(9078)

    # App migrations must complete or the service exits during startup.
    machine.succeed("journalctl -u multi-scrobbler.service | grep -q 'App migrations applied'")

    # The UI is served through the managed dist symlink in stateDir.
    machine.succeed(
        "curl --fail --show-error http://127.0.0.1:9078/ "
        "| grep --quiet '__MS_RUNTIME__'"
    )

    # File-based configs get `id = name` injected before they reach CONFIG_DIR.
    machine.succeed(
        "jq --exit-status '.[0].id == .[0].name' "
        "/var/lib/multi-scrobbler/webscrobbler.json"
    )
    machine.succeed("grep -q webscrobbler_test_source /var/lib/multi-scrobbler/webscrobbler.json")
  '';
}
