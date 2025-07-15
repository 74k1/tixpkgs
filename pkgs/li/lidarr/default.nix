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
  version = "2.13.1.4676";

  src = fetchurl {
    url = "https://dev.azure.com/Lidarr/Lidarr/_apis/build/builds/4631/artifacts?artifactName=Packages&fileId=3DB2FE7F623B89D8617B110DAF711601F99D68E7C173A0D91CD76E071A9359D502&fileName=Lidarr.merge.${version}.linux-core-x64.tar.gz&api-version=5.1";
    name = "Lidarr.merge.${version}.linux-core-x64.tar.gz";
    hash = "sha256-WJtJbxZG1cNcHVUvu0Vt6bvyVqClkL9hIR1fUwVj3cY=";
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
