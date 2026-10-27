{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-27";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "a27a8ed01a322e0af33d0b260a3234f4d4a105da";
    hash = "sha256-WJHEgy8pibjq1W8mExLQMfzzk1i9P2i4uU1cuGoSmW8=";
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
