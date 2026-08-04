{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-03";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "4de2712567f2aac79a4d29a602d615ffa01b0842";
    hash = "sha256-tCxaNKlMilf9Whpla8IGglKMS2O4DR2SVZx0UHvJR0E=";
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
