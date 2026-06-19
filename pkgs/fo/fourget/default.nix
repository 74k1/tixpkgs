{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-06-14";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "5a7cecef11d4b728ba202e1a80f5a77b7aee88fe";
    hash = "sha256-QnzNE3zNVKs0+JggnhNymRmZIUcyKbUGXtj0L5CY7s0=";
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
    maintainers = [ "74k1" ];
  };
}
