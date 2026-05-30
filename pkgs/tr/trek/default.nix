{
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  nodejs_22,
  node-gyp,
  perl,
  python3,
  writableTmpDirAsHomeHook,
}:

let
  version = "3.0.22";

  src = fetchFromGitHub {
    owner = "mauriceboe";
    repo = "TREK";
    rev = "v${version}";
    hash = "sha256-1Rf9KHbYP/yBY2/9/JA0dgrG/84cNWCP7q2ad26ElD8=";
  };

  # Build the React + Vite client frontend in a fixed-output derivation.
  # The client package-lock.json omits some transitive peer deps that npm v10
  # tries to auto-install; using a FOD with network access sidesteps this while
  # remaining reproducible via the content hash below.
  trekClient = stdenv.mkDerivation {
    pname = "trek-client";
    inherit version src;
    sourceRoot = "source/client";

    nativeBuildInputs = [
      nodejs_22
      writableTmpDirAsHomeHook
    ];

    # npm_config_cache points npm at a writable directory inside the sandbox.
    # --prefer-offline tries the cache first to speed up repeated builds.
    buildPhase = ''
      runHook preBuild
      export npm_config_cache="$TMPDIR/npm-cache"
      npm ci --legacy-peer-deps
      patchShebangs node_modules
      npm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';

    outputHash = "sha256-PyeCNmOgt2UGnJFSe+z77mka3u48sp6YmAfk1uvHMaE=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  # Fetch server production node_modules in a fixed-output derivation.
  # --ignore-scripts skips better-sqlite3's native addon compilation so the
  # FOD output contains no store-path references (a FOD requirement).
  # The native addon is compiled in the main (non-FOD) derivation below.
  # --legacy-peer-deps avoids installing peer-dep placeholders that appear in
  # the lockfile without resolved/integrity fields (e.g. zod-to-json-schema).
  trekServerModules = stdenv.mkDerivation {
    pname = "trek-server-modules";
    inherit version src;
    sourceRoot = "source/server";

    nativeBuildInputs = [
      nodejs_22
      writableTmpDirAsHomeHook
    ];

    buildPhase = ''
      runHook preBuild
      export npm_config_cache="$TMPDIR/npm-cache"
      npm ci --legacy-peer-deps --ignore-scripts --omit=dev
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r node_modules $out
      runHook postInstall
    '';

    # fixupPhase would run patchShebangs and introduce Nix store paths into
    # the FOD output (e.g. better-sqlite3/deps/download.sh), which is forbidden.
    dontFixup = true;

    outputHash = "sha256-aXRN/vhntnI9KKqbk7GofT6Ed5c0ONcCP2HiYcuTnDA=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

in
stdenv.mkDerivation {
  pname = "trek";
  inherit version src;
  sourceRoot = "source/server";

  nativeBuildInputs = [
    nodejs_22
    node-gyp
    perl
    python3
    writableTmpDirAsHomeHook
  ];

  # The server resolves data/ and uploads/ via __dirname across 20+ source files
  # at varying subdirectory depths. Since the Nix store is read-only, redirect
  # all occurrences through env vars so the NixOS module can point them at a
  # writable state directory.
  #
  # Patterns handled (N = 1..3 repetitions of ../):
  #   path.{join,resolve}(__dirname, 'N/data')            → TREK_DATA_DIR
  #   path.{join,resolve}(__dirname, 'N/data/SUB')        → path.join(TREK_DATA_DIR, 'SUB')
  #   path.{join,resolve}(__dirname, 'N/uploads')         → TREK_UPLOADS_DIR
  #   path.{join,resolve}(__dirname, 'N/uploads/SUB')     → path.join(TREK_UPLOADS_DIR, 'SUB')
  #   path.join(__dirname, 'N/uploads', VAR)              → path.join(TREK_UPLOADS_DIR, VAR)
  #   path.join(__dirname, 'N/uploads/SUB', VAR)          → path.join(TREK_UPLOADS_DIR, 'SUB', VAR)
  postPatch = ''
    cat > path-redirect.pl << 'PERLEOF'
    # Order: most-specific (sub-path + var) before least-specific
    s{path\.join\(__dirname,\s*'(?:\.\.\/)+uploads\/([^']+)',\s*([^)]+)\)}{path.join(process.env.TREK_UPLOADS_DIR, '$1', $2)}g;
    s{path\.join\(__dirname,\s*'(?:\.\.\/)+uploads',\s*([^)]+)\)}{path.join(process.env.TREK_UPLOADS_DIR, $1)}g;
    s{path\.(?:join|resolve)\(__dirname,\s*'(?:\.\.\/)+uploads\/([^']+)'\)}{path.join(process.env.TREK_UPLOADS_DIR, '$1')}g;
    s{path\.(?:join|resolve)\(__dirname,\s*'(?:\.\.\/)+uploads'\)}{process.env.TREK_UPLOADS_DIR}g;
    s{path\.(?:join|resolve)\(__dirname,\s*'(?:\.\.\/)+data\/([^']+)'\)}{path.join(process.env.TREK_DATA_DIR, '$1')}g;
    s{path\.(?:join|resolve)\(__dirname,\s*'(?:\.\.\/)+data'\)}{process.env.TREK_DATA_DIR}g;
    PERLEOF

    find src -name "*.ts" | xargs perl -0777 -i -p path-redirect.pl
  '';

  buildPhase = ''
    runHook preBuild

    cp -r ${trekServerModules} node_modules
    chmod -R u+w node_modules
    patchShebangs node_modules

    # Compile better-sqlite3's native addon now that we're outside the FOD
    # and node-gyp can reference Nix store paths.
    # npm_config_nodedir tells node-gyp to use the Nix-provided headers
    # instead of downloading them from nodejs.org.
    export npm_config_nodedir="${nodejs_22}"
    npm rebuild better-sqlite3

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/trek $out/bin

    # Copy server source + production node_modules.
    # public/ (the compiled React frontend) is placed adjacent to src/ so
    # that Express's static middleware (path.join(__dirname, '../public'))
    # resolves to the correct store path at runtime.
    cp -r src node_modules package.json $out/libexec/trek/
    cp -r ${trekClient} $out/libexec/trek/public

    cat > $out/bin/trek <<EOF
#!${stdenvNoCC.shell}
set -e
export NODE_PATH=$out/libexec/trek/node_modules\''${NODE_PATH:+:\$NODE_PATH}
exec ${nodejs_22}/bin/node --import=$out/libexec/trek/node_modules/tsx/dist/loader.mjs $out/libexec/trek/src/index.ts "\$@"
EOF
    chmod +x $out/bin/trek

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/bin/trek
    test -f $out/libexec/trek/src/index.ts
    test -d $out/libexec/trek/public
    test -d $out/libexec/trek/node_modules
    runHook postInstallCheck
  '';

  passthru = {
    trek-client = trekClient;
    trek-server-modules = trekServerModules;
    updateScript = ./update.sh;
  };

  meta = {
    description = "Self-hosted real-time collaborative travel planner with maps, budgets, packing lists, and AI";
    homepage = "https://github.com/mauriceboe/TREK";
    changelog = "https://github.com/mauriceboe/TREK/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    maintainers = [ "74k1" ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "trek";
  };
}
