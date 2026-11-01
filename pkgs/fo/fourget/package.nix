{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-31";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "be91ec1806012f25e1d7928ce1b20ea1de17b3ca";
    hash = "sha256-jfygvcymMnSIiRYx9eqS8lh/nvaV0iCHw4Bq0M16CKI=";
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
