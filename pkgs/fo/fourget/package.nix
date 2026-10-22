{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-21";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "7eb4ac14c89cbbf06a36f39f49574d69007b79a0";
    hash = "sha256-8JEVP5fgfW+eICRmFt6JZ4IJDVyi5UynQfK/LgdyHrE=";
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
