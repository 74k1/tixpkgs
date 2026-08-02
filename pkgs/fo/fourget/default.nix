{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-02";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "919714d47274aa953a2e3296fa14e22ba8bf1547";
    hash = "sha256-CZmflkSqS+x4oA4QVFEZSd6LJca/yfE/uhucYC/Bv7M=";
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
