{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-11-17";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "9f637443a7465d9de8b9d87ff9e4d4cfd43b40f2";
    hash = "sha256-EmMr9WxRDZOJpHGxA9fDJ+dWRJrLH3zYydZFJT62CoQ=";
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
