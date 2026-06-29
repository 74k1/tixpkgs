{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-06-27";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "abdb041a640e6560bdc57fac17c9931f95a974fa";
    hash = "sha256-KJbxZrKUcvCxJBfogMXLl5s0OZo/+a2n3RFYKwCOBIs=";
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
