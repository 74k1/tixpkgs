{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-09-22";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "047e400c7ff44d03c4e3530654cbd35d645d4d1d";
    hash = "sha256-IxCprHrr3iWaivS6Wa04o4wkr6xKXNh7jo7JCbxAjjI=";
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
