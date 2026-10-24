{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-24";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "9db95c79d27f35b4a0677119e0f5ceef00fc64ea";
    hash = "sha256-3II5dLNUNV9TjrQBhfLcwuxrHd5ky9Gc/PaAAG7oYHE=";
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
