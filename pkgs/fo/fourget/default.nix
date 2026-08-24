{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-23";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "2785f23a54aa5faf07e0926ee058472be8a61146";
    hash = "sha256-PxbgUgEHXTvEf3ZXt/QooLDn+0KRZbEfq4cyR305L1k=";
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
