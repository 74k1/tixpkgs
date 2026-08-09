{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-09";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "ba7ee6e47782dd60a1a17394f6a512b467e9b190";
    hash = "sha256-QWYEfG/TcudDfGGgyGrtrqIAJxqZAFOuDmsssAskbd0=";
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
