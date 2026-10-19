{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-18";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "77d636a44b109d949dac730513eaaace4bb1245a";
    hash = "sha256-Spnt14Ytq6SfRsMcptb1KV1ITGiCVAAgU5HdDQuqHwY=";
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
