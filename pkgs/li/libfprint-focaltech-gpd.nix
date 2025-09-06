{
  stdenv,
  lib,
  fetchurl,
  rpm,
  dpkg,
  cpio,
  glib,
  gusb,
  pixman,
  libgudev,
  nss,
  libfprint,
  cairo,
  pkg-config,
  autoPatchelfHook,
  makePkgconfigItem,
  copyPkgconfigItems,
}: let
  libso = "libfprint-2.so.2.0.0";
in stdenv.mkDerivation rec {
  pname = "libprint-focaltech-gpd";
  version = "20250714";

  src = fetchurl {
    url = "https://github.com/ftfpteams/focaltech-linux-fingerprint-driver/raw/refs/heads/main/Ubuntu_Debian/x86/libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_amd64_20250714.deb";
    hash = "sha256-ftcaGzguf59qUEyTPgzP4OWpM2VJVU3EJBA2cxKC/do=";
  };

  nativeBuildInputs = [
    dpkg
    rpm
    cpio
    pkg-config
    autoPatchelfHook
    copyPkgconfigItems
  ];

  buildInputs = [
    stdenv.cc.cc
    glib
    gusb
    pixman
    nss
    libgudev
    libfprint
    cairo
  ];

  unpackPhase = ''
    runHook preUnpack

    dpkg -x $src .

    runHook postUnpack
  '';

  # custom pkg-config based on libfprint's pkg-config
  pkgconfigItems = [
    (makePkgconfigItem rec {
      name = "libfprint-2";
      inherit version;
      inherit (meta) description;
      cflags = [ "-I${variables.includedir}/libfprint-2" ];
      libs = [
        "-L${variables.libdir}"
        "-lfprint-2"
      ];
      variables = rec {
        prefix = "${placeholder "out"}";
        includedir = "${prefix}/include";
        libdir = "${prefix}/lib";
      };
    })
  ];

  installPhase = ''
    runHook preInstall

    install -Dm444 usr/lib/x86_64-linux-gnu/${libso} -t $out/lib

    # create this symlink as it was there in libfprint
    ln -s -T $out/lib/${libso} $out/lib/libfprint-2.so
    ln -s -T $out/lib/${libso} $out/lib/libfprint-2.so.2

    # get files from libfprint required to build the package
    cp -r ${libfprint}/lib/girepository-1.0 $out/lib
    cp -r ${libfprint}/include $out

    runHook postInstall
  '';

  meta = with lib; {
    description = "The newer fingerprint driver from focaltech for the GPD Pocket 4";
    homepage = "https://github.com/ftfpteams/focaltech-linux-fingerprint-driver/";
    maintainers = [maintainers."74k1"];
    platforms = ["x86_64-linux"];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    # broken = true; # needs older version of fprintd (v1.94.4)
  };
}
