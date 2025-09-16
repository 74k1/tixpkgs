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
  version = "2.14.2.4786";

  src = fetchurl {
    url = "https://dev.azure.com/Lidarr/Lidarr/_apis/build/builds/4741/artifacts?artifactName=Packages&fileId=F14038BF13F9C5AB85AB0609346F71512B42F8A1B9E8CA13F6FB925FE0112D1A02&fileName=Lidarr.merge.${version}.linux-core-x64.tar.gz&api-version=5.1";
    name = "Lidarr.merge.${version}.linux-core-x64.tar.gz";
    hash = "sha256-aPlDykGLfeaJRNKCh90LlSrC/FCu169NG4Wf4+tF/nk=";
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
