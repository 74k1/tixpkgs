{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-07-25";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "8e7fe8377485ac35e5d1b4d8c4ab1c936ae728ad";
    hash = "sha256-/JAyHLwA/iCwNBgN2CQkQwA6SPzOuE1NM0eyJgDXZEg=";
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
