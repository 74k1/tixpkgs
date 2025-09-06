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
    dpkg-deb -x $src .
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 -t $out/lib/libfprint-2/tod-1/
    runHook postInstall
  '';

  passthru.driverPath = "/lib/libfprint-2/tod-1";

  meta = with lib; {
    description = "The newer fingerprint driver from focaltech for the GPD Pocket 4";
    homepage = "https://github.com/ftfpteams/focaltech-linux-fingerprint-driver/";
    maintainers = [maintainers."74k1"];
    platforms = ["x86_64-linux"];
  };
}
