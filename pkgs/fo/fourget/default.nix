{ lib
, stdenvNoCC
, fetchgit
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-05-24";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "1e3f3d82fdca5ced58db35910afb682d2b4ea995";
    hash = "sha256-pgmAL1m7zARG2q5cEB5BSZ3DFSCoFx/HwvQrneA00A0=";
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
  };
}
