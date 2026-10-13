{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "4get";
  version = "unstable-2026-10-13";

  src = fetchgit {
    url = "https://git.lolcat.ca/lolcat/4get.git";
    rev = "90eccc386c204c7399fe099a8ab8aad779e6b48f";
    hash = "sha256-XXHODpWlAVX9aruzREhZRq6wkfmLFBSTn9xnBJFDX+o=";
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
