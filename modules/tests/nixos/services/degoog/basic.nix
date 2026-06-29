{ module, pkgs, ... }:
{
  name = "degoog-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [
      pkgs.curl
    ];

    virtualisation.memorySize = 2048;

    services.degoog = {
      enable = true;
      environment.LOG_LEVEL = "debug";
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("degoog.service")
    machine.wait_for_open_port(4444)

    # Ready endpoint
    machine.succeed("curl --fail --show-error http://127.0.0.1:4444/readyz")

    # UI is served and returns valid HTML
    machine.succeed("curl -sSf http://127.0.0.1:4444/ -o /tmp/degoog-ui.html")
    machine.succeed("grep --quiet '<html' /tmp/degoog-ui.html")

    # Service unit wiring checks
    machine.succeed("systemctl cat degoog.service | grep -F 'User=degoog'")
    machine.succeed("systemctl cat degoog.service | grep -F 'Group=degoog'")
    machine.succeed("systemctl cat degoog.service | grep 'bin/degoog'")
    machine.succeed("id -u degoog")
    machine.succeed("getent group degoog")
  '';
}
