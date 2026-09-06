{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-09-05";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "462c5e17293a103bd33bf7d5cb0de19f1d82ac71";
    hash = "sha256-yiIjcXfSsiS9mQ/8idtDdS4XKAb7b59/nt+FsNnurpg=";
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
