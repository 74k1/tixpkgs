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
  version = "2.11.1.4613";

  src = fetchurl {
    url = "https://dev.azure.com/Lidarr/Lidarr/_apis/build/builds/4525/artifacts?artifactName=Packages&fileId=C95116966FC4CC865EB67DAFD5CE5C1441B4FB6DCAA1FA6518B6A1686766381702&fileName=Lidarr.merge.${version}.linux-core-x64.tar.gz&api-version=5.1";
    name = "Lidarr.merge.${version}.linux-core-x64.tar.gz";
    hash = "sha256-9MDWgAfSDbm0fB4Ha05okeV8rVqn3o0/lefCcWvXFbg=";
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
    maintainers = [ maintainers."74k1" ];
    mainProgram = "Lidarr";
    platforms = ["x86_64-linux"]; 
  };
}
