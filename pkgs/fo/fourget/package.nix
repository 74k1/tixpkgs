{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-11-15";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "4c7c4ea0723cf3db83d43ff4dc2aaa23144cf2a4";
    hash = "sha256-tpfxavFMJlUShTSayNJn2v8JFTqyU0cJt6dlJlcTeZo=";
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
