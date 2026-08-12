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
  version = "0.1.107";

  # The frontend recognizes SSO UI mode only as VITE_AUTH_MODE=sso; the backend
  # uses AUTH_MODE=oidc. Map oidc -> sso for the web UI build.
  frontendAuthMode = if authMode == "oidc" then "sso" else authMode;
in
{
  inherit pname version;

  src = fetchFromGitHub {
    owner = "thunderbird";
    repo = "thunderbolt";
    tag = "v${version}";
    hash = "sha256-CBt8vGUO2w9SlU0lwTVrg+mKekN8D4Dd7JJQUEzGQjQ=";
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

    outputHash = "sha256-52k5WXgmoR7MeV1HozLklTIXyxMjvdhaZO13gSULc8M=";
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
      # bun >= 1.4 refuses --production when the lockfile needs refreshing
      # (upstream's bun.lock trips the overrides check under 1.4), so run a
      # full install first to bring the lockfile in sync, then prune to a
      # production-only tree.
      bun install --ignore-scripts --no-progress
      bun install --production --ignore-scripts --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cp -R node_modules $out

      runHook postInstall
    '';

    outputHash = "sha256-HU5e/dQbrtI4eCNUeLtQQtXOWtrcsxOILySFB6JIgUY=";
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
    export VITE_AUTH_MODE=${lib.escapeShellArg frontendAuthMode}
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
