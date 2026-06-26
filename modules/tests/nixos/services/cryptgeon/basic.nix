{ module, pkgs, ... }:
{
  name = "cryptgeon-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [
      pkgs.curl
    ];

    virtualisation.memorySize = 2048;

    services.cryptgeon = {
      enable = true;
      settings.verbosity = "debug";
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("redis-cryptgeon.service")
    machine.wait_for_unit("cryptgeon.service")
    machine.wait_for_open_port(8000)

    # Health endpoint returns 200
    machine.succeed("curl --fail --show-error http://127.0.0.1:8000/api/live")

    # API status endpoint
    machine.succeed("curl --fail --show-error http://127.0.0.1:8000/api/status")

    # UI is served (static HTML)
    machine.succeed(
        "curl --fail --show-error http://127.0.0.1:8000/ "
        + "| grep --quiet '<html'"
    )

    # Verify service unit wiring
    machine.succeed("systemctl cat cryptgeon.service | grep -F 'User=cryptgeon'")
    machine.succeed("systemctl cat cryptgeon.service | grep -F 'Group=cryptgeon'")
    machine.succeed("id -u cryptgeon")
    machine.succeed("getent group cryptgeon")
  '';
}
