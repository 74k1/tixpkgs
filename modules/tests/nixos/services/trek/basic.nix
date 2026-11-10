{ module, pkgs, ... }:
{
  name = "trek-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [ pkgs.curl ];

    virtualisation.memorySize = 2048;

    services.trek = {
      enable = true;
      domain = "trek.example.test";
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("trek.service")
    machine.wait_for_open_port(3000)
    machine.succeed("test -d /var/lib/trek/data/tmp")
    machine.succeed("test -d /var/lib/trek/uploads")

    machine.succeed("curl --fail --show-error http://127.0.0.1:3000/ | grep '<html' > /dev/null")
  '';
}
