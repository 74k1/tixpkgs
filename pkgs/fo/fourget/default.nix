{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-09-01";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "28ba8422b2532e01edde6305e2baaf72a51c8850";
    hash = "sha256-wXPuzdhKnt0B5610c8GmCdRjKvs0zF6KDzw/MdFMjlc=";
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
