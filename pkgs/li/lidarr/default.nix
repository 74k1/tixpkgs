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
  version = "2.13.2.4686";

  src = fetchurl {
    url = "https://dev.azure.com/Lidarr/Lidarr/_apis/build/builds/4641/artifacts?artifactName=Packages&fileId=C17A20351165094D192AA2B3CCB902BFB106340C6F1EB91DDBD050B95232AA8002&fileName=Lidarr.merge.${version}.linux-core-x64.tar.gz&api-version=5.1";
    name = "Lidarr.merge.${version}.linux-core-x64.tar.gz";
    hash = "sha256-fC590SlA2KCIJNxTP5uYaXfMBi0GvLohaNUDVKLejfI=";
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
