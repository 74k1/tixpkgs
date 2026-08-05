{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-05";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "60014ebe4dd36875714b0ef64131ca6c75d9528d";
    hash = "sha256-WFdq7SZxCxMTV6wX6WvOSHplPk/CbPq+yMdmDna7sE0=";
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
