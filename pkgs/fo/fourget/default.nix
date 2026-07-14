{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-07-10";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "3e4c7c16262406bb8f7f7d4c550bd2efb58d2a8f";
    hash = "sha256-bF7XsRnVF8ab8vUQNQz16Pic6e8V5JKxhgTGauarDX4=";
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
