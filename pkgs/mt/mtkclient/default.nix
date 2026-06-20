{
  pkgs,
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonPackage rec {
  pyproject = true;
  pname = "mtkclient";
  version = "2c9f4d7";

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
    rev = "2c9f4d78601e2b223cacfed773a5c4cbb1808189";
    hash = "sha256-isQKurmKQavxGH/LnD2pXn+zbXUK+5KwMXwkT9TprPM=";
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
    maintainers = [ "74k1" ];
  };
}
