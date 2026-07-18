{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_22,
}:

buildNpmPackage (finalAttrs: {
  pname = "trek";
  version = "3.4.0";

  src = fetchFromGitHub {
    owner = "mauriceboe";
    repo = "TREK";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/W3HSsZE/T3uWcLzBDEXSySXCQRizmSYpZkMULZgNsY=";
  };

  # TREK is an npm workspaces monorepo (client + server + shared) driven by a
  # single root package-lock.json. Fetcher v2 enables packument caching, which
  # is required for workspaces to resolve through `npm ci`.
  npmDepsHash = "sha256-oiVQ+YP/71zdknGME3ksyi5i8u2AbCaI0xK94gJjf3M=";
  npmDepsFetcherVersion = 2;

  nodejs = nodejs_22;

  # The root package.json pins musl prebuilds in optionalDependencies, and
  # npm's libc auto-detection on NixOS does not reliably filter them, so by
  # default `npm ci` installs the musl/darwin/android/arm prebuilds too. They
  # are useless on glibc, bloat the output, and force patchelf over hundreds of
  # foreign ELFs in fixup. Pin the target libc so only the glibc variants are
  # selected from the (already-all-platforms) npmDeps cache. This does not
  # affect npmDepsHash: fetchNpmDeps always fetches every platform.
  env.npm_config_libc = "glibc";

  # A C toolchain (from stdenv) and node headers (set by npmConfigHook) are
  # enough for better-sqlite3's node-gyp build; the sqlite amalgamation is
  # vendored in the package tarball, so the addon compiles fully offline
  # after prebuild-install fails fast in the no-network sandbox.

  # The server writes to __dirname-relative `../uploads` and `../data` from
  # several source files (config.ts, index.ts, scheduler.ts,
  # nest/platform/platform.routes.ts). The Nix store is read-only, so rewrite
  # every `path.{join,resolve}(__dirname, '<N>/data|uploads')` to read
  # TREK_DATA_DIR / TREK_UPLOADS_DIR from the environment. `../public` (the
  # built client) is left untouched — that stays a read-only store path.
  # Applied before `npm run build` compiles the TypeScript, so the compiled
  # dist inherits the redirects. Uses sed (not perl) so the same postPatch
  # also runs inside the fetchNpmDeps fixed-output derivation, which has a
  # minimal stdenv.
  postPatch = ''
    cat > path-redirect.sed << 'SEDEOF'
    s#path\.join\(__dirname, '(\.\./)+uploads/([^']+)', ([^)]*)\)#path.join(process.env.TREK_UPLOADS_DIR, '\2', \3)#g
    s#path\.join\(__dirname, '(\.\./)+uploads', ([^)]*)\)#path.join(process.env.TREK_UPLOADS_DIR, \2)#g
    s#path\.(join|resolve)\(__dirname, '(\.\./)+uploads/([^']+)'\)#path.join(process.env.TREK_UPLOADS_DIR, '\3')#g
    s#path\.(join|resolve)\(__dirname, '(\.\./)+uploads'\)#process.env.TREK_UPLOADS_DIR#g
    s#path\.(join|resolve)\(__dirname, '(\.\./)+data/([^']+)'\)#path.join(process.env.TREK_DATA_DIR, '\3')#g
    s#path\.(join|resolve)\(__dirname, '(\.\./)+data'\)#process.env.TREK_DATA_DIR#g
    SEDEOF
    find server/src -name '*.ts' -print0 | xargs -0 sed -E -i -f path-redirect.sed
  '';

  # The root "build" script orchestrates shared -> server -> client; leave
  # npmBuildScript at its default ("build") and npmWorkspace unset so the root
  # orchestrator runs.
  dontNpmInstall = true;

  installPhase = ''
    runHook preInstall

    # Drop build-only devDependencies (vite, esbuild, rollup, lightningcss,
    # sharp, tsc, tsdown, eslint, ...). These are client/server build tools,
    # never loaded at runtime, and they ship the bulk of the foreign-platform
    # native prebuilds. Pruning shrinks node_modules several-fold and clears
    # the patchelf-over-foreign-ELFs slowness in fixup. Offline-safe: the
    # npmConfigHook already exported npm_config_offline/cache for this build.
    npm prune --omit=dev --no-save

    mkdir -p $out/libexec/trek/server $out/libexec/trek/shared $out/bin

    # Root node_modules carries the @trek/shared workspace symlink (relative,
    # resolves once `shared/` is in place below) and the compiled
    # better-sqlite3 native addon. Copy without dereferencing so the symlink
    # survives.
    cp -r --no-dereference node_modules $out/libexec/trek/node_modules

    # npm symlinks every workspace into node_modules/@trek/*. Only @trek/shared
    # is needed at runtime (the server imports it); @trek/client and @trek/server
    # would dangle because we don't ship those workspace trees whole, so drop
    # them before the noBrokenSymlinks check trips.
    rm -f $out/libexec/trek/node_modules/@trek/client
    rm -f $out/libexec/trek/node_modules/@trek/server

    # The root package.json pins musl prebuilds (sharp, rollup, canvas) in
    # optionalDependencies, and npm's libc filter doesn't drop them on glibc,
    # so they survive `npm prune` as orphaned/dead-weight native binaries. They
    # never load on glibc (a glibc counterpart exists for canvas; sharp/rollup
    # are build-only) and they trip patchelf with "wrong ELF type". Drop them.
    find $out/libexec/trek/node_modules -type d -name '*musl*' -print0 | xargs -0 -r rm -rf

    # @trek/shared resolves via node_modules/@trek/shared -> ../shared, so
    # ship the built shared workspace + its manifest as a sibling of
    # node_modules.
    cp -r shared/dist $out/libexec/trek/shared/dist
    cp shared/package.json $out/libexec/trek/shared/package.json

    # Compiled server (CommonJS dist) + the manifests tsconfig-paths/register
    # and the version lookup (`require('../package.json')`) need at runtime.
    cp -r server/dist $out/libexec/trek/server/dist
    cp server/package.json $out/libexec/trek/server/package.json
    cp server/tsconfig.json $out/libexec/trek/server/tsconfig.json

    # Built client is served as the static `public/` tree (PUBLIC_DIR).
    cp -r client/dist $out/libexec/trek/server/public

    # Static data: airports DB, atlas boundary geojson, wiki cache.
    cp -r server/assets $out/libexec/trek/server/assets

    # Launch from server/ so tsconfig-paths/register finds tsconfig.json; the
    # writable data/uploads dirs come from TREK_DATA_DIR/TREK_UPLOADS_DIR
    # (see the NixOS module), not cwd.
    cat > $out/bin/trek <<EOF
    #!${stdenv.shell}
    set -eu
    cd "$out/libexec/trek/server"
    exec ${lib.getExe nodejs_22} --require tsconfig-paths/register dist/index.js "\$@"
    EOF
    chmod +x $out/bin/trek

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/bin/trek
    test -f $out/libexec/trek/server/dist/index.js
    test -d $out/libexec/trek/server/public
    test -d $out/libexec/trek/node_modules/better-sqlite3
    test -d $out/libexec/trek/shared/dist
    test -f $out/libexec/trek/server/assets/atlas/admin0.geojson.gz
    test -f $out/libexec/trek/server/assets/airports.json
    runHook postInstallCheck
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Self-hosted real-time collaborative travel planner with maps, budgets, packing lists, and AI";
    homepage = "https://github.com/mauriceboe/TREK";
    changelog = "https://github.com/mauriceboe/TREK/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "trek";
  };
})
