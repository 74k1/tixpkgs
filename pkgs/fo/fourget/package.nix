{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-11-13";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "4536cef88ff5b5436c2182250ece92f7d3fa4cc5";
    hash = "sha256-gQ4mJ+QowbTjNInZQBtW82ieC4TQHtouE4PENqUVQZg=";
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
