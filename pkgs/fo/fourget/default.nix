{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-30";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "a285a50e3b00b46a8c0e40825557a436b7973e18";
    hash = "sha256-HSPCZB3enkfQF5UXduS4ycYB7gAx9fOKc1yLT+6J3jc=";
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
