{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-07-04";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "8328d93b17de34c255673c2b98be7eb0f828f6c5";
    hash = "sha256-AnvqaIhi8JJYCmzBK8KVEAMW5G7MSy+aMuXw/jCn0oE=";
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
