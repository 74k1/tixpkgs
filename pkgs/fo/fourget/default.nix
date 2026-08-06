{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-06";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "d39b8ab875149635ed8262b65fd3164063cc4fc9";
    hash = "sha256-9zHoTQluBtOPDn+Y7hFTEYsrriB+bOkJn4SkkAZlYP4=";
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
