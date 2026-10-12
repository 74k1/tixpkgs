{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-11";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "a837c0c248fbec26d72e831af565f595b43ebcda";
    hash = "sha256-P5X35ByEA24uNCO5bMWjaSCCaSYGJcLqTRpkf1UI0+I=";
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
