{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-27";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "d7bb0755cb26dbceb5fb934c27c09e2135732cf3";
    hash = "sha256-mRkBEl0tKM8jykNTZT6zm0+wz1yE3q1/WmwK4q3R4Xw=";
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
