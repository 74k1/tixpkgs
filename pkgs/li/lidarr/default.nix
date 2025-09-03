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
  version = "2.14.1.4723";

  src = fetchurl {
    url = "https://dev.azure.com/Lidarr/Lidarr/_apis/build/builds/4678/artifacts?artifactName=Packages&fileId=5D8BE7B51576B9B33BD39E4B257F39082E8B2516FAB88A941A3CC78351F2779402&fileName=Lidarr.merge.${version}.linux-core-x64.tar.gz&api-version=5.1";
    name = "Lidarr.merge.${version}.linux-core-x64.tar.gz";
    hash = "sha256-V/HZl3OXjEVLzzWOmW3gIhgMm4AVbjTUfMmGeJKMQUQ=";
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
