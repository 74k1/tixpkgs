{ module, pkgs, ... }:
{
  name = "moodist-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [
      pkgs.curl
    ];

    services.moodist.enable = true;
    services.moodist.hostname = "localhost";
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("network.target")
    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(80)

    # The SPA shell (client-side routing) is served for the root path.
    machine.succeed("curl --fail --show-error --silent -o /tmp/moodist.html http://127.0.0.1/")
    machine.succeed("grep -qi moodist /tmp/moodist.html")

    # Unknown routes fall back to /index.html.
    machine.succeed("curl --fail --show-error --silent -o /dev/null http://127.0.0.1/some/mix/route")

    # Static assets are reachable (PWA manifest).
    machine.succeed("curl --fail --show-error --silent -o /dev/null http://127.0.0.1/manifest.webmanifest")
  '';
}
