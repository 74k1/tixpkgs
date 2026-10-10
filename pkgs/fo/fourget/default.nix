{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-10";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "836521b8d741ed22070310a2bf9218dde1daaec8";
    hash = "sha256-wqO2qxK9iQ3tV3luyPkmlCluCYQMW30/G9dUY+KaxXY=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    cp -r . $out/share/4get

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "4get: a proxy search engine that doesn't suck";
    homepage = "https://git.lolcat.ca/lolcat/4get";
    license = licenses.agpl3Plus;
    mainProgram = "index.php";
    platforms = platforms.unix;
    maintainers = with lib.maintainers; [ _74k1 ];
  };
}
