{
  lib,
  module,
  pkgs,
  ...
}:
let
  fakePackage = pkgs.runCommand "brscan-skey" { meta.mainProgram = "brscan-skey"; } ''
    mkdir -p $out/bin $out/lib/brscan-skey/script

    cat > $out/bin/brscan-skey <<'EOF'
    #!${pkgs.runtimeShell}
    exit 0
    EOF
    chmod +x $out/bin/brscan-skey

    for script in scantoimage.sh scantoocr.sh scantoemail.sh scantofile.sh; do
      cat > "$out/lib/brscan-skey/script/$script" <<'EOF'
    #!${pkgs.runtimeShell}
    exit 0
    EOF
      chmod +x "$out/lib/brscan-skey/script/$script"
    done
  '';
in
{
  name = "brscan-skey-nixos";

  nodes.machine = {
    imports = [ module ];

    services.brscan-skey = {
      enable = true;
      package = fakePackage;
    };

    # This test checks module wiring. The real daemon needs scanner hardware, so
    # do not start it automatically in the VM.
    systemd.services.brscan-skey.wantedBy = lib.mkForce [ ];
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("multi-user.target")

    machine.succeed("id -u brscan-skey")
    machine.succeed("getent group brscan-skey")

    machine.succeed("grep -Fx 'IMAGE=bash  ${fakePackage}/lib/brscan-skey/script/scantoimage.sh' /etc/brscan-skey/brscan-skey.config")
    machine.succeed("grep -Fx 'OCR=bash  ${fakePackage}/lib/brscan-skey/script/scantoocr.sh' /etc/brscan-skey/brscan-skey.config")
    machine.succeed("grep -Fx 'EMAIL=bash  ${fakePackage}/lib/brscan-skey/script/scantoemail.sh' /etc/brscan-skey/brscan-skey.config")
    machine.succeed("grep -Fx 'FILE=bash  ${fakePackage}/lib/brscan-skey/script/scantofile.sh' /etc/brscan-skey/brscan-skey.config")

    machine.succeed("systemctl cat brscan-skey.service | grep -F 'User=brscan-skey'")
    machine.succeed("systemctl cat brscan-skey.service | grep -F 'Group=brscan-skey'")
    machine.succeed("systemctl cat brscan-skey.service | grep -F 'ExecStart=${fakePackage}/bin/brscan-skey -f'")
    machine.succeed("systemctl cat brscan-skey.service | grep -F 'ExecStop=${fakePackage}/bin/brscan-skey --terminate'")
    machine.succeed("systemctl cat brscan-skey.service | grep -F 'StateDirectory=brscan-skey'")
  '';
}
