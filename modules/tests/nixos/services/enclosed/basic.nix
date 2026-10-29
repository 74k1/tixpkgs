{
  module,
  pkgs,
  ...
}:
{
  name = "enclosed-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [ pkgs.curl ];

    virtualisation.memorySize = 2048;

    # Secret files are read by systemd, not by the service user.
    environment.etc."enclosed/jwt-secret".text = "test-jwt-secret";
    environment.etc."enclosed/users".text = "admin@example.test:$2a$10$0123456789012345678901";
    environment.etc."enclosed/env".text = ''
      PUBLIC_DEFAULT_NOTE_TTL_SECONDS=86400
    '';

    services.enclosed = {
      enable = true;
      authenticationRequired = true;
      jwtSecretFile = "/etc/enclosed/jwt-secret";
      usersFile = "/etc/enclosed/users";
      environmentFile = "/etc/enclosed/env";
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("enclosed.service")
    machine.wait_for_open_port(8787)

    # The client build is served from the package share directory.
    machine.succeed("curl --fail --show-error http://127.0.0.1:8787/ | grep --quiet 'Enclosed - Send private and secure notes'")

    # The API answers and reports the configured public settings.
    machine.succeed("curl --fail --show-error http://127.0.0.1:8787/api/ping | grep --quiet '\"status\":\"ok\"'")
    machine.succeed("curl --fail --show-error http://127.0.0.1:8787/api/config | grep --quiet '\"isAuthenticationRequired\":true'")

    # The environment file reaches the process through systemd.
    machine.succeed("curl --fail --show-error http://127.0.0.1:8787/api/config | grep --quiet '\"defaultNoteTtlSeconds\":86400'")

    # Credential files reach the process through LoadCredential.
    machine.succeed("tr '\\0' '\\n' < /proc/$(systemctl show --property=MainPID --value enclosed.service)/environ | grep --quiet '^AUTHENTICATION_JWT_SECRET=test-jwt-secret$'")
    machine.succeed("tr '\\0' '\\n' < /proc/$(systemctl show --property=MainPID --value enclosed.service)/environ | grep --quiet '^AUTHENTICATION_USERS=admin@example.test:'")

    # State lives in the configured data directory, not in the package.
    machine.succeed("test -d /var/lib/enclosed/data")
    machine.succeed("systemctl show --property=WorkingDirectory --value enclosed.service | grep --quiet 'share/enclosed'")
  '';
}
