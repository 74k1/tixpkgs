{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-09-19";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "47b4788809a467b09918008d20751b361c3de994";
    hash = "sha256-rJd/BHZmvrpsMPlumNbcJA3FlmgiTizNVGA4MU3Kbi0=";
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
