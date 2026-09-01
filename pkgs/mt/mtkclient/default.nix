{
  pkgs,
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonPackage rec {
  pyproject = true;
  pname = "mtkclient";
  version = "60e07f3";

  buildInputs = with pkgs; [
    pkgs.keystone
  ];

  propagatedBuildInputs = with python3.pkgs; [
    capstone
    colorama
    flake8
    fusepy
    hatchling
    keystone-engine
    mfusepy
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
    rev = "60e07f3b343a4469389f15967626d63e049968d4";
    hash = "sha256-N8ex1qdhaTvujjhIGg4GUw6ALXPHhvWrvTwWFkXPlBw=";
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
    maintainers = with lib.maintainers; [ _74k1 ];
  };
}
