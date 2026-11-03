{
  nix-update-script,
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "server-mono";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "internet-development";
    repo = "www-server-mono";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4whLEYNIwtfRs+0YNRPbrK5mxn7MWDukTOxiGWBoNck=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 public/fonts/*.otf -t $out/share/fonts/opentype

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Monospace typeface inspired by typewriters, San Francisco Mono, ASCII art, and command-line interfaces";
    homepage = "https://servermono.com";
    changelog = "https://github.com/internet-development/www-server-mono/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.ofl;
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.all;
  };
})
