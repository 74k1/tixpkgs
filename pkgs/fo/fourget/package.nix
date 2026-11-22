{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-11-21";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "568f8f26bf5411c7c1b30ba61aefb8eac7d6319d";
    hash = "sha256-5XFO2qm6JMH4UhOjhdt7C6HHEK0KWaDJErJrDgAcs48=";
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
