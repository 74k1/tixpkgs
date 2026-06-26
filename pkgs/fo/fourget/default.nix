{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-06-25";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "f037ad1d7fb70811b9d67d221fc879ef8bfd136a";
    hash = "sha256-RTsGQFpu7n5MpZ+rfCBtKvb+Zf7aXw3glo1el9OIxLw=";
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
    maintainers = [ "74k1" ];
  };
}
