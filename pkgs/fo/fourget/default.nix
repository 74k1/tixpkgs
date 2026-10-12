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
    rev = "6602df4fa9cd8aa4a1e1065ee3ef8344830915bf";
    hash = "sha256-vpl5pFqU8VGxrpbAXoiY0g0GeQ1lbq+aSHyHGGnBkZA=";
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
