{ module, pkgs, ... }:
{
  name = "hemmelig-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [ pkgs.curl ];

    virtualisation.memorySize = 2048;

    services.hemmelig = {
      enable = true;
      domain = "hemmelig.example.test";
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("hemmelig.service")
    machine.wait_for_open_port(3000)

    machine.succeed("curl --fail --show-error http://127.0.0.1:3000/ | grep --quiet '<html'")
  '';
}
