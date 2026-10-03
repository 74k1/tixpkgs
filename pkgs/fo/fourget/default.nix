{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-03";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "03ba5d7b5ed3dc91b3e7d8b6278d8f52818a99ae";
    hash = "sha256-FF5mryPKc9BuVWF/zwq4vrQ57oSyjiRPWYdu9c5ajTg=";
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
