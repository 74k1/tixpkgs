{
  lib,
  stdenv,
  fetchurl,
  dotnet-runtime,
  icu,
  libmediainfo,
  sqlite,
  curl,
  makeWrapper,
  chromaprint,
  openssl,
  zlib,
}:
stdenv.mkDerivation rec {
  pname = "lidarr";
  version = "3.1.3.4968";

  src = fetchurl {
    url = "https://github.com/Lidarr/Lidarr/releases/download/v${version}/Lidarr.develop.${version}.linux-core-x64.tar.gz";
    hash = "sha256-jhTloumon3y3ooFDSnSE0bljL8UvLMBrsDpRAnFN3dE=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/${pname}-${version}}
    cp -r * $out/share/${pname}-${version}/.
    makeWrapper "${dotnet-runtime}/bin/dotnet" $out/bin/Lidarr \
      --add-flags "$out/share/${pname}-${version}/Lidarr.dll" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          curl
          sqlite
          libmediainfo
          icu
          openssl
          zlib
        ]
      }

    runHook postInstall
  '';

  passthru = {
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "Usenet and torrent music downloader";
    homepage = "https://lidarr.audio/";
    license = licenses.gpl3Only;
    maintainers = [ "74k1" ];
    mainProgram = "Lidarr";
    platforms = [ "x86_64-linux" ];
  };
}
