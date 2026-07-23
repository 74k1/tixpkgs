{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-07-22";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "e57538a296201e73981f80f83887224996d2224d";
    hash = "sha256-8tUy6MAHWQkyoZf6qd2CV+E+EZvvsZn1LRH73R0UYSA=";
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
