{ module, pkgs, ... }:
{
  name = "rybbit-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [ pkgs.curl ];

    virtualisation.memorySize = 4096;

    services.rybbit = {
      enable = true;
      environment.BETTER_AUTH_SECRET = "00000000000000000000000000000000";
      settings.puppeteer.enable = false;
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("clickhouse.service")
    machine.wait_for_unit("rybbit.service")
    machine.wait_for_open_port(3001)
    machine.wait_for_open_port(3002)

    machine.succeed("curl --fail --show-error http://127.0.0.1:3001/api/health | grep --quiet OK")
    machine.succeed("curl --fail --show-error http://127.0.0.1:3002 | grep --quiet '<html'")
  '';
}
