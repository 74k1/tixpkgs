{
  pkgs,
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonPackage rec {
  pyproject = true;
  pname = "mtkclient";
  version = "5794aba";

  buildInputs = with pkgs; [
    pkgs.keystone
  ];

  propagatedBuildInputs = with python3.pkgs; [
    hatchling
    capstone
    colorama
    flake8
    fusepy
    keystone-engine
    pycryptodome
    pycryptodomex
    pyserial
    pyside6
    pyusb
    setuptools
    shiboken6
    unicorn
  ];

  src = fetchFromGitHub {
    owner = "bkerler";
    repo = "mtkclient";
    rev = "5794aba14a8753cd8186cd0ec2ce5ae73e3ea2f2";
    hash = "sha256-M16posU6FGobiFbXvFBE5C0otACD2SPRLubwA+STKxs=";
  };

  postFixup = ''
    mkdir -p $out/opt/mtkclient
    mv * $out/opt/mtkclient

    rm -rf $out/opt/mtkclient/mtkclient/Windows

    mkdir -p $out/lib/udev/rules.d
    if [ -e $out/opt/mtkclient/mtkclient/Setup/Linux/51-edl.rules ]; then
      cp $out/opt/mtkclient/mtkclient/Setup/Linux/51-edl.rules $out/lib/udev/rules.d/52-edl.rules
    else
      cp $out/opt/mtkclient/Setup/Linux/51-edl.rules $out/lib/udev/rules.d/52-edl.rules
    fi
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "MTK reverse engineering and flash tool";
    homepage = "https://github.com/bkerler/mtkclient";
    license = lib.licenses.gpl3Only;
  };
}
