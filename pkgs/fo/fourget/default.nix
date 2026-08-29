{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-28";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "2d8e5838cdc5f9dcc57faa3f92d6b560f889e381";
    hash = "sha256-KL93EJX+zZoq2TFj1PUrk3T1otJad3sTL9yxdiVTbTw=";
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
