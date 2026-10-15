{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-15";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "5419d8afa5ee9e4a583c4d795e4a5e40baf0fdb6";
    hash = "sha256-wdmmv7NX9ROW5kScxZLDJKaFc+fBxeWNqbUlbzaxcPM=";
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
