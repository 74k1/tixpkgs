{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-09-18";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "a847ffec1134b86a05c7764bd9234a4c2c446e69";
    hash = "sha256-XWgShwqRRXf/khjdB5kNtU2eQX7KfiyIO4ss7sIyONs=";
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
