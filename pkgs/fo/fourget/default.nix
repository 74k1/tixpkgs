{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-06-21";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "347300cc26390917cbd3a0c1a1c8954e2e305ae6";
    hash = "sha256-bh9yv/o8piyaTJCQvFnIiDMixMhsBb2rNhMrGYOB3To=";
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
