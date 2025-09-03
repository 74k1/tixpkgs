{
  lib,
  dpkg,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation rec {
    pname = "libfprint-focaltech";
  version = "20250714";

  src = fetchurl {
    url = "https://github.com/ftfpteams/focaltech-linux-fingerprint-driver/raw/refs/heads/main/Ubuntu_Debian/x86/libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_amd64_${version}.deb";
    name = "libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_amd64_${version}.deb";
    hash = "sha256-ftcaGzguf59qUEyTPgzP4OWpM2VJVU3EJBA2cxKC/do=";
  };

  nativeBuildInputs = [dpkg];

  unpackPhase = ''
    dpkg-deb -x $src $out
  '';

  meta = with lib; {
    description = "The newer fingerprint driver from focaltech for the GPD Pocket 4";
    homepage = "https://github.com/ftfpteams/focaltech-linux-fingerprint-driver/";
    maintainers = [maintainers."74k1"];
    platforms = ["x86_64-linux"];
  };
}
