{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  nodejs_22,
  makeWrapper,
  writableTmpDirAsHomeHook,
}:

let
  version = "2.10.1";

  src = fetchFromGitHub {
    owner = "ridafkih";
    repo = "keeper.sh";
    rev = "v${version}";
    hash = "sha256-fCUYZezjHtjwRHSVHV7iqOoMryWSSaIahMjamaIic74=";
  };

  # Fixed-output derivation that runs `bun install` with network access and
  # produces a hoisted node_modules tree. Relative workspace symlinks
  # (e.g. node_modules/@keeper.sh/database → ../../packages/database) are
  # preserved; they resolve correctly once the tree is planted alongside the
  # source packages/ directory in the main derivation's $out.
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "keeper-sh-node-modules";
    inherit version src;

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    buildPhase = ''
      runHook preBuild
      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --frozen-lockfile \
        --ignore-scripts \
        --linker=hoisted \
        --no-progress
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r ./node_modules $out
      runHook postInstall
    '';

    outputHash = "sha256-MYecnckk7JOrSSdpubjfTGIUBn9LNslhK37QV9jl2sQ=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";

    # Workspace symlinks (e.g. @keeper.sh/database → ../../packages/database)
    # dangle here because packages/ is not in this FOD; they resolve correctly
    # once node_modules/ is placed alongside packages/ in the main derivation.
    dontFixup = true;
  };

in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "keeper-sh";
  inherit version src;

  nativeBuildInputs = [
    bun
    nodejs_22
    makeWrapper
    writableTmpDirAsHomeHook
  ];

  env = {
    NODE_ENV = "production";
    TURBO_TELEMETRY_DISABLED = "1";
    # Build-time Vite vars — keep empty so the web bundle uses relative
    # paths and works correctly behind any nginx reverse-proxy.
    VITE_API_URL = "";
    VITE_MCP_URL = "";
    VITE_COMMERCIAL_MODE = "false";
  };

  configurePhase = ''
    runHook preConfigure
    cp -R ${nodeModules} node_modules
    # Nix store files are read-only (0444) so make them writable for the
    # build.  patchShebangs only finds -type f; .bin symlinks resolve to
    # real files elsewhere in the tree which get patched normally.
    chmod -R u+w node_modules
    patchShebangs node_modules
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    export TURBO_CACHE_DIR="$TMPDIR/turbo-cache"
    export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
    mkdir -p "$TURBO_CACHE_DIR"
    node_modules/.bin/turbo run build --no-daemon
    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall
        mkdir -p $out/libexec/keeper-sh $out/bin

        # Copy the full monorepo tree (source + built dist/ dirs + node_modules).
        # node_modules contains relative workspace symlinks that resolve correctly
        # because packages/ is installed at the same level.
        cp -r services applications packages node_modules $out/libexec/keeper-sh/
        cp package.json bun.lock turbo.json $out/libexec/keeper-sh/
        [ -f bunfig.toml ] && cp bunfig.toml $out/libexec/keeper-sh/ || true

        # The web server resolves client assets via process.cwd()/dist/client, but
        # Vite builds them to applications/web/dist/client. Symlink the web dist
        # at the monorepo root so both paths resolve to the same tree.
        ln -s $out/libexec/keeper-sh/applications/web/dist $out/libexec/keeper-sh/dist

        # --- service wrappers ---
        # All services cd to the monorepo root so bun can find node_modules.

        for service in api cron worker; do
          cat > $out/bin/keeper-sh-$service <<EOF
    #!${stdenvNoCC.shell}
    set -eo pipefail
    cd $out/libexec/keeper-sh
    exec ${bun}/bin/bun services/$service/dist/index.js
    EOF
          chmod +x $out/bin/keeper-sh-$service
        done

        cat > $out/bin/keeper-sh-mcp <<EOF
    #!${stdenvNoCC.shell}
    set -eo pipefail
    cd $out/libexec/keeper-sh
    exec ${bun}/bin/bun services/mcp/dist/index.js
    EOF
        chmod +x $out/bin/keeper-sh-mcp

        cat > $out/bin/keeper-sh-web <<EOF
    #!${stdenvNoCC.shell}
    set -eo pipefail
    cd $out/libexec/keeper-sh
    if [ -z "\$PORT" ]; then export PORT=3000; fi
    exec ${bun}/bin/bun applications/web/dist/server-entry/index.js
    EOF
        chmod +x $out/bin/keeper-sh-web

        # Migration runner — bun handles TypeScript natively; drizzle migration
        # files live under packages/database/drizzle/ which is included in $out.
        cat > $out/bin/keeper-sh-migrate <<EOF
    #!${stdenvNoCC.shell}
    set -eo pipefail
    cd $out/libexec/keeper-sh
    exec ${bun}/bin/bun packages/database/scripts/migrate.ts
    EOF
        chmod +x $out/bin/keeper-sh-migrate

        runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/bin/keeper-sh-api
    test -x $out/bin/keeper-sh-cron
    test -x $out/bin/keeper-sh-worker
    test -x $out/bin/keeper-sh-web
    test -x $out/bin/keeper-sh-mcp
    test -x $out/bin/keeper-sh-migrate
    test -f $out/libexec/keeper-sh/services/api/dist/index.js
    test -f $out/libexec/keeper-sh/services/cron/dist/index.js
    test -f $out/libexec/keeper-sh/services/worker/dist/index.js
    test -f $out/libexec/keeper-sh/services/mcp/dist/index.js
    test -d $out/libexec/keeper-sh/applications/web/dist
    runHook postInstallCheck
  '';

  passthru = {
    updateScript = ./update.sh;
  };

  meta = {
    description = "Calendar synchronization platform with MCP support";
    homepage = "https://keeper.sh";
    changelog = "https://github.com/ridafkih/keeper.sh/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    maintainers = [ "74k1" ];
    platforms = lib.platforms.linux;
  };
})
