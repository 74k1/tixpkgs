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
    rev = "89051f0129845d61d2d1ca53ba9da2d63fee5ba4";
    hash = "sha256-S/CZKb2pKddJmvwWwoMYxZmSNogsgzs+AxHtZlshzZ8=";
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
