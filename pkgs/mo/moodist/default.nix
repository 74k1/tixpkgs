{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_11,
  nodejs_24,
  pnpmConfigHook,
  pnpmBuildHook,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "moodist";
  version = "2.6.1";

  src = fetchFromGitHub {
    owner = "remvze";
    repo = "moodist";
    rev = "31d958ed013e3b640afb23fc394d8cc6680fb6e3";
    hash = "sha256-GVBJFV3/BCSxEs78Ae/dEFgIgVeexoqtB39ws0i6Ijo=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-gCMgUFeDCR852bVivZln89/S6EGL8AErTFrGyPgtGaY=";
  };

  nativeBuildInputs = [
    pnpm_11
    nodejs_24
    pnpmConfigHook
    pnpmBuildHook
  ];

  env.CI = "1";

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r dist/* $out/

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Ambient sounds for focus and calm";
    homepage = "https://moodist.mvze.net/";
    changelog = "https://github.com/remvze/moodist/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.all;
  };
})
