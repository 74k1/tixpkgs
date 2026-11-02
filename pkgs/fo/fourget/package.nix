{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-11-01";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "c0324d7d6159c901ea8c98fe303c39a4f7001fd8";
    hash = "sha256-TsCF9XzHATzoOCWU7keHbu0G3LA6Rp9WQr7VdePCkFY=";
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
