{ module, pkgs, ... }:
{
  name = "yopass-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [
      pkgs.curl
      pkgs.jq
    ];

    virtualisation.memorySize = 2048;

    services.yopass = {
      enable = true;
      settings.logLevel = "debug";
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("memcached.service")
    machine.wait_for_unit("yopass.service")
    machine.wait_for_open_port(1337)

    # Health endpoint
    machine.succeed(
      "curl --fail --show-error http://127.0.0.1:1337/health "
      + "| jq --exit-status '.status == \"healthy\"'"
    )

    # Ready endpoint
    machine.succeed(
      "curl --fail --show-error http://127.0.0.1:1337/ready "
      + "| jq --exit-status '.status == \"ready\"'"
    )

    # Version endpoint returns version info
    machine.succeed(
      "curl --fail --show-error http://127.0.0.1:1337/version "
      + "| jq --exit-status '.version != null'"
    )

    # Config endpoint returns settings
    machine.succeed(
      "curl --fail --show-error http://127.0.0.1:1337/config "
      + "| jq --exit-status '.FORCE_ONETIME_SECRETS == false'"
    )

    # UI is served
    machine.succeed(
      "curl --fail --show-error http://127.0.0.1:1337/ "
      + "| grep --quiet '<html'"
    )

    # Service unit wiring checks
    machine.succeed("systemctl cat yopass.service | grep -F 'User=yopass'")
    machine.succeed("systemctl cat yopass.service | grep -F 'Group=yopass'")
    machine.succeed("systemctl cat yopass.service | grep -F 'yopass-server'")
    machine.succeed("id -u yopass")
    machine.succeed("getent group yopass")
  '';
}
