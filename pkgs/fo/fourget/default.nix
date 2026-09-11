{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-09-08";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "734926240d2e40abd9bbde072a741b1cfc682432";
    hash = "sha256-ZAu7bkmD2Ap7EiPyp0Xv81MQOTLIdevPRtrwPJiUEZw=";
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
