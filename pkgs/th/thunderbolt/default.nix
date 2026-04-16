{
  lib,
  stdenvNoCC,
  bun,
  nodejs,
  fetchFromGitHub,
  makeWrapper,
  writableTmpDirAsHomeHook,
  cloudUrl ? "/v1",
  authMode ? "consumer",
  showAppDownloads ? false,
  bypassWaitlist ? false,
  skipOnboarding ? false,
}:

stdenvNoCC.mkDerivation (finalAttrs:
let
  pname = "thunderbolt";
  version = "0.1.96";
in
{
  inherit pname version;

  src = fetchFromGitHub {
    owner = "thunderbird";
    repo = "thunderbolt";
    tag = "v${version}";
    hash = "sha256-ViZaMr+7eoeEaXntA+g4t3eY85o3rPQ5w7cRWvJOuUg=";
  };

  frontendNodeModules = stdenvNoCC.mkDerivation {
    pname = "${pname}-frontend-node-modules";
    inherit version;
    src = finalAttrs.src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;
    dontFixup = true;
    dontPatchShebangs = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install --frozen-lockfile --no-progress --ignore-scripts

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cp -R node_modules $out

      runHook postInstall
    '';

    outputHash = "sha256-AcogO4mQsM9HBjfhZdv3NcqRkrDL+iJrfnKjuy1g+Fk=";
    outputHashMode = "recursive";
  };

  backendNodeModules = stdenvNoCC.mkDerivation {
    pname = "${pname}-backend-node-modules";
    inherit version;
    src = finalAttrs.src;
    sourceRoot = "${finalAttrs.src.name}/backend";

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;
    dontFixup = true;
    dontPatchShebangs = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install --frozen-lockfile --production --no-progress --ignore-scripts

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cp -R node_modules $out

      runHook postInstall
    '';

    outputHash = "sha256-r8fcbgrs2S2VNPi8w8L/hAEedA7PH5IpBtl1HpJQRGQ=";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    makeWrapper
    nodejs
    writableTmpDirAsHomeHook
  ];

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.frontendNodeModules} node_modules
    chmod -R u+rwX node_modules

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    export VITE_THUNDERBOLT_CLOUD_URL=${lib.escapeShellArg cloudUrl}
    export VITE_AUTH_MODE=${lib.escapeShellArg authMode}
    export VITE_SHOW_APP_DOWNLOADS=${lib.boolToString showAppDownloads}
    export VITE_BYPASS_WAITLIST=${lib.boolToString bypassWaitlist}
    export VITE_SKIP_ONBOARDING=${lib.boolToString skipOnboarding}

    substituteInPlace vite.config.ts \
      --replace-fail "execSync('powersync-web copy-assets --output public', { stdio: 'inherit' })" \
                     "execSync('${lib.getExe nodejs} node_modules/@powersync/web/bin/powersync.cjs copy-assets --output public', { stdio: 'inherit' })"

    ${lib.getExe nodejs} node_modules/vite/bin/vite.js build
    find dist -type f -name '*.map' -delete

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    packageRoot="$out/share/${pname}"
    frontendRoot="$packageRoot/frontend"
    backendRoot="$packageRoot/backend"

    mkdir -p "$out/bin" "$frontendRoot" "$backendRoot"

    cp -R dist/. "$frontendRoot"
    cp -R backend/src "$backendRoot/"
    cp -R backend/drizzle "$backendRoot/"
    cp -R shared "$packageRoot/"
    cp backend/bunfig.toml "$backendRoot/"
    cp backend/bun.lock "$backendRoot/"
    cp backend/package.json "$backendRoot/"
    cp backend/tsconfig.json "$backendRoot/"

    cp -R ${finalAttrs.backendNodeModules} "$backendRoot/node_modules"

    makeWrapper ${lib.getExe bun} "$out/bin/thunderbolt-backend" \
      --chdir "$backendRoot" \
      --set NODE_ENV production \
      --add-flags ./src/index.ts

    runHook postInstall
  '';

  meta = {
    description = "Self-hosted Thunderbolt frontend and backend bundle";
    homepage = "https://thunderbolt.io";
    license = lib.licenses.mpl20;
    mainProgram = "thunderbolt-backend";
    platforms = lib.platforms.linux;
  };
})
