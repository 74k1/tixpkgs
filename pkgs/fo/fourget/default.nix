{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-18";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "89b8be514727b37bda3c7b2acb527335b9bdbfbf";
    hash = "sha256-kIrBThW42PwZK+8AqOqy5xmVQRAwCZHx7EIiOsgFE5M=";
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
