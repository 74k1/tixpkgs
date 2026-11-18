{ module, pkgs, ... }:
{
  name = "rsshub-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [ pkgs.curl ];

    virtualisation.memorySize = 2048;

    services.rsshub = {
      enable = true;
      settings.caching.enable = true;
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("redis-rsshub.service")
    machine.wait_for_unit("rsshub.service")
    machine.wait_for_open_port(1200)

    machine.succeed("curl --fail --show-error http://127.0.0.1:1200/healthz | grep ok > /dev/null")

    machine.succeed("systemctl show rsshub.service --property=User | grep -Fx 'User=rsshub'")
    machine.succeed("test \"$(stat -c %U:%G /var/lib/rsshub)\" = rsshub:rsshub")
  '';
}
