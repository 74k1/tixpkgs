{
  fetchYarnDeps,
  nodejs,
  src,
  stdenvNoCC,
  version,
  yarnBuildHook,
  yarnConfigHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "yopass-website";
  inherit version;

  src = src + "/website";

  yarnOfflineCache = fetchYarnDeps {
    yarnLock = "${finalAttrs.src}/yarn.lock";
    hash = "sha256-81Z2xxWkEUgMCYAHK6RCsl0AjqehCTRLLSZAPWTtMD8=";
  };

  nativeBuildInputs = [
    nodejs
    yarnBuildHook
    yarnConfigHook
  ];

  installPhase = ''
    runHook preInstall

    mv dist $out

    runHook postInstall
  '';
})