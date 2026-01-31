{
  lib,
  stdenv,
  fetchurl,
  mono,
  libmediainfo,
  sqlite,
  curl,
  chromaprint,
  makeWrapper,
  icu,
  dotnet-runtime,
  openssl,
  nixosTests,
  zlib,
}:
stdenv.mkDerivation rec {
  pname = "lidarr";
  version = "3.1.2.4902";

  src = fetchurl {
    url = "https://github.com/Lidarr/Lidarr/releases/download/v${version}/Lidarr.develop.${version}.linux-core-x64.tar.gz";
    name = "Lidarr.develop.${version}.linux-core-x64.tar.gz";
    hash = "sha256-1oSFJtQ9/ICACFBFgp2kPzfP0dKitMg7vqAN7iT0KTA=";
  };

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/${pname}-${version}}
    cp -r * $out/share/${pname}-${version}/.
    makeWrapper "${dotnet-runtime}/bin/dotnet" $out/bin/Lidarr \
      --add-flags "$out/share/${pname}-${version}/Lidarr.dll" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
      curl
      sqlite
      libmediainfo
      icu
      openssl
      zlib
    ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Usenet/BitTorrent music downloader";
    homepage = "https://lidarr.audio/";
    license = licenses.gpl3;
    maintainers = [maintainers."74k1"];
    mainProgram = "Lidarr";
    platforms = ["x86_64-linux"];
  };
}
