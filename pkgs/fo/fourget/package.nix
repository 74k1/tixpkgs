{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-18";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "ee0cecc32be2d16a61f9bbb8b991b2ad4fda1b26";
    hash = "sha256-OHB15nFjpysdTPBGr7CUQK6eCMyh/Tw0Q2tQwO9Yk7M=";
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
