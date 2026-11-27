{
  module,
  pkgs,
  tixpkgs,
  ...
}:
let
  # Test values only. HolyArrs checks both formats strictly.
  apiKey = "hak_ofH6fvMT0nbn6VMJYHrZX3EDa_tJLLn25q9aYLhn5bY";
in
{
  name = "holyarrs-nixos";

  nodes.machine = {
    imports = [ module ];

    environment.systemPackages = [ pkgs.curl ];

    # Secret files are read by systemd, not by the service user.
    environment.etc."holyarrs/owner-password".text = "correct horse battery staple";
    environment.etc."holyarrs/api-key".text = apiKey;
    environment.etc."holyarrs/master-key".text = "Mnp3OL+J/BlijWAaTTUJq7XTCrpFDiOYXe/Um9mYf2c=";

    systemd.tmpfiles.rules = [ "d /srv/media 0770 holyarrs holyarrs - -" ];

    services.holyarrs = {
      enable = true;
      ownerName = "admin";
      ownerPasswordFile = "/etc/holyarrs/owner-password";
      apiKeyFile = "/etc/holyarrs/api-key";
      masterKeyFile = "/etc/holyarrs/master-key";
      mediaDirs = [ "/srv/media" ];
      updateCheck = false;
    };
  };

  testScript = ''
    import json

    start_all()

    machine.wait_for_unit("holyarrs.service")
    machine.wait_for_open_port(6262)
    machine.wait_until_succeeds("curl --fail --silent http://127.0.0.1:6262/readyz | grep --quiet ready", timeout=120)

    # The embedded web app is served.
    machine.succeed("curl --fail --show-error http://127.0.0.1:6262/login | grep '<title>HolyArrs</title>' > /dev/null")

    # The owner and the API key come from the credentials, so the API refuses
    # anonymous calls and accepts the key.
    machine.succeed("journalctl -u holyarrs.service | grep --quiet 'made the owner \"admin\" from HOLYARRS_OWNER_NAME'")
    machine.fail("curl --fail --silent http://127.0.0.1:6262/api/v1/health")
    health = json.loads(machine.succeed("curl --fail --show-error --header 'X-Api-Key: ${apiKey}' http://127.0.0.1:6262/api/v1/health"))
    assert health["ok"], health
    assert health["version"] == "${tixpkgs.holyarrs.version}", health

    # The master key comes from its credential, so none is made in the config folder.
    machine.succeed("test -f /var/lib/holyarrs/holyarrs.db")
    machine.fail("test -e /var/lib/holyarrs/holyarrs.key")

    # The systemd sandbox leaves room for the plugin sandbox (Landlock and seccomp).
    plugins = json.loads(machine.succeed("curl --fail --show-error --header 'X-Api-Key: ${apiKey}' http://127.0.0.1:6262/api/v1/plugins"))
    assert not plugins["no_file_lock"], plugins
    assert not plugins["no_net_lock"], plugins

    # In the service's view, the media folder is writable and its parent is not.
    machine.succeed("nsenter --target $(systemctl show --property=MainPID --value holyarrs.service) --mount -- touch /srv/media/from-service")
    machine.fail("nsenter --target $(systemctl show --property=MainPID --value holyarrs.service) --mount -- touch /srv/outside")

    # systemd starts HolyArrs again after a failure.
    machine.succeed("systemctl kill --signal=SIGKILL holyarrs.service")
    machine.wait_until_succeeds("curl --fail --silent http://127.0.0.1:6262/readyz | grep --quiet ready", timeout=120)
  '';
}
