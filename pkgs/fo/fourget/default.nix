{ lib
, stdenvNoCC
, fetchgit
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-03-05";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "2386dd707e4198f5e267944c19d14e7d05f78480";
    hash = "sha256-eiYo67xhoOqu0mU07Zreb/Ars58L+ZdFX/OMmkcDgm0=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    cp -r . $out/share/4get

    runHook postInstall
  '';

  meta = with lib; {
    description = "4get: a proxy search engine that doesn't suck";
    homepage = "https://git.lolcat.ca/lolcat/4get";
    license = licenses.agpl3Plus;
    mainProgram = "index.php";
    platforms = platforms.unix;
  };
}
