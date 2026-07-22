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
    rev = "5fc80a36727b460b45baaf70e1af25f8521ed44e";
    hash = "sha256-YXjf61eCSTFG8w/0erMIwVbzDlVhtyJlabsQpDULSq0=";
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
