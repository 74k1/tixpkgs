{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-11-25";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "03df7d30b341f52c6cae5ff5efaf2015edf3f632";
    hash = "sha256-X9wy5PczQG+3qztPQinXqYCn3l5wBl3MX4dRJ2PoXHU=";
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
