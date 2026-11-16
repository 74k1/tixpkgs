{ module, pkgs, ... }:
let
  # Expired example tokens from the upstream wiki. Shitter does not start
  # without a sessions file, and it handles rejected tokens without a failure.
  sessionsFile = pkgs.writeText "sessions.jsonl" ''
    {"oauth_token":"1719213587296620928-BsXY2RIJEw7fjxoNwbBemgjJhueK0m","oauth_token_secret":"N0WB0xhL4ng6WTN44aZO82SUJjz7ssI3hHez2CUhTiYqy"}
  '';
in
{
  name = "shitter-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [
      pkgs.curl
      pkgs.redis
    ];

    services.shitter = {
      enable = true;
      inherit sessionsFile;
      settings.Server = {
        hostname = "shitter.example.test";
        title = "tixpkgs test";
      };
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("redis-shitter.service")
    machine.wait_for_unit("shitter.service")
    machine.wait_for_open_port(8080)

    machine.succeed("curl --fail --show-error http://127.0.0.1:8080/ | grep 'tixpkgs test' > /dev/null")
    machine.succeed("curl --fail --show-error http://127.0.0.1:8080/about | grep 'codeberg.org/shitter/shitter/commit/' > /dev/null")
    machine.succeed("curl --fail --show-error http://127.0.0.1:8080/css/style.css > /dev/null")

    # Redis is reached through its Unix socket and listens on no TCP port.
    machine.succeed("grep --quiet 'redisHost = \"/run/redis-shitter/redis.sock\"' /var/lib/shitter/shitter.conf")
    machine.fail("ss --tcp --listening --numeric --no-header | grep ':6379 '")
    machine.wait_until_succeeds("redis-cli -s /run/redis-shitter/redis.sock client list | grep -c 'addr=' | grep -v '^1$'")

    # The generated key replaces the placeholder and stays private.
    machine.succeed("test \"$(wc -c < /var/lib/shitter/hmac)\" -eq 64")
    machine.succeed("grep --quiet \"hmacKey = \\\"$(cat /var/lib/shitter/hmac)\\\"\" /var/lib/shitter/shitter.conf")
    machine.succeed("test \"$(stat -c %a /var/lib/shitter/shitter.conf)\" = 600")
  '';
}
