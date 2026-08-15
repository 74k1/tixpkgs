{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-08-14";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "51b45ba53bb4bfee7b3d5583362d358d3862a4f5";
    hash = "sha256-fkyrpKRrvEhDAF070SVlgkrihpHPOGAjQz6o2j9kIGs=";
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
