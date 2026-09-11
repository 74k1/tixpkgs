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
    rev = "31a9ef4e1380f32507d9e51d3fdb01f72395e30f";
    hash = "sha256-Z0JTHInmblKBmkL+8EcVbzlKJIqnMNw7WXglYGReglo=";
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
