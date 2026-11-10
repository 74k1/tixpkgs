{ module, pkgs, ... }:
{
  name = "thunderbolt-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [
      pkgs.curl
      pkgs.jq
    ];

    virtualisation.memorySize = 4096;

    networking.hosts."127.0.0.1" = [ "thunderbolt.example.test" ];

    services.thunderbolt = {
      enable = true;

      # `consumer` lets the backend boot with only a `BETTER_AUTH_SECRET`;
      # `oidc` would additionally need a reachable OIDC issuer.
      authMode = "consumer";

      publicUrl = "http://thunderbolt.example.test";

      environmentFile = pkgs.writeText "thunderbolt-test-env" ''
        BETTER_AUTH_SECRET=test-secret-not-for-production-0123456789
      '';
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("thunderbolt.service")
    machine.wait_for_open_port(8000)

    # Unauthenticated backend health endpoint.
    machine.succeed(
        "curl --fail --silent --show-error http://127.0.0.1:8000/v1/health "
        "| jq --exit-status '.status == \"ok\"'"
    )

    # Public deployment config endpoint.
    machine.succeed(
        "curl --fail --silent --show-error http://127.0.0.1:8000/v1/config "
        "| jq --exit-status 'has(\"e2eeEnabled\")'"
    )

    # The default nginx integration serves the generated frontend.
    machine.wait_for_unit("nginx.service")
    machine.succeed(
        "curl --fail --silent --show-error http://thunderbolt.example.test/ "
        "| grep --quiet --ignore-case '<html'"
    )

    # The nginx vhost proxies /v1/ to the backend.
    machine.succeed(
        "curl --fail --silent --show-error http://thunderbolt.example.test/v1/health "
        "| jq --exit-status '.status == \"ok\"'"
    )

    # Endpoints behind the auth macro reject anonymous requests.
    machine.fail(
        "curl --fail --silent --show-error "
        "'http://127.0.0.1:8000/v1/units?country=US'"
    )

    # The embedded PGlite database was initialized inside the state dir.
    machine.succeed("test -d /var/lib/thunderbolt/db")
  '';
}
