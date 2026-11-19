{ module, pkgs, ... }:
{
  nodes.machine = {
    imports = [ module ];
    services.gpt-load = {
      enable = true;
      port = 3101;
    };
    environment.systemPackages = [ pkgs.curl ];
  };

  testScript = ''
    machine.wait_for_unit("gpt-load.service")
    machine.wait_until_succeeds("curl -fsS http://127.0.0.1:3101/health", timeout=60)
    machine.succeed("ss -Hltn 'sport = :3101' | grep -F 127.0.0.1:3101")
    machine.succeed("cd /var/lib/gpt-load && test -s gpt-load.db && test -s auth.key && test -s encryption.key")
    machine.succeed("test $(stat -Lc %a /var/lib/gpt-load) = 700")
    machine.succeed("cd /var/lib/gpt-load && sha256sum auth.key encryption.key > /tmp/gpt-load-keys")
    machine.succeed("systemctl restart gpt-load.service")
    machine.wait_until_succeeds("curl -fsS http://127.0.0.1:3101/health")
    machine.succeed("cd /var/lib/gpt-load && sha256sum -c /tmp/gpt-load-keys")
  '';
}
