{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-03";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "f6a369ed48b0db34092fa3a1e69d645fbd6bf43d";
    hash = "sha256-Gbw3L52BSfHdxr6tn0dEdrqgglHZu/u6pfhx8+Y4nF4=";
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
