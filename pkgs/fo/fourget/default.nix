{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-16";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "fba304fb8c1e9e68ff7dcde727deacc596661e5a";
    hash = "sha256-em9FE1GNWLtyFVPCLrXWdxfIdsHctdqZEzUmmjCt+eM=";
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
