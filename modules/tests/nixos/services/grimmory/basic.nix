{ module, pkgs, ... }:
{
  name = "grimmory-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [
      pkgs.curl
      pkgs.jq
    ];

    services.grimmory.enable = true;
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("mysql.service")
    machine.wait_for_unit("grimmory.service")
    machine.wait_for_open_port(6060)

    machine.succeed(
        "curl --fail --show-error http://127.0.0.1:6060/api/v1/setup/status "
        "| jq --exit-status '.status == 200 and .data == false'"
    )

    machine.succeed(
        "curl --fail --show-error "
        "--header 'Content-Type: application/json' "
        "--request POST "
        "--data '{\"username\":\"admin\",\"email\":\"admin@example.test\",\"name\":\"Admin\",\"password\":\"correct horse battery staple\"}' "
        "http://127.0.0.1:6060/api/v1/setup "
        "| jq --exit-status '.status == 200'"
    )

    machine.succeed(
        "curl --fail --show-error http://127.0.0.1:6060/api/v1/setup/status "
        "| jq --exit-status '.status == 200 and .data == true'"
    )
  '';
}
