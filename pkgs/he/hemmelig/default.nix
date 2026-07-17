{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_24,
  prisma-engines,
}:

buildNpmPackage (finalAttrs: {
  pname = "hemmelig";
  version = "7.4.8";

  src = fetchFromGitHub {
    owner = "HemmeligOrg";
    repo = "Hemmelig.app";
    tag = "v${finalAttrs.version}";
    hash = "sha256-AMLwJLnsmuWzU8sBuimbFtDEPVTMtafOQ9w6adp3f9c=";
  };

  npmDepsHash = "sha256-zxi/DLq5A4MmjZ1JrjxIapvJsTbfsNkyVmi2dgBJYUU=";

  nodejs = nodejs_24;

  # prisma generate normally downloads engine binaries from the network.
  # Point it at nixpkgs' pre-built engines instead (same major version, 7.x,
  # so the schema engine is compatible with the npm prisma 7.4.1 CLI).
  nativeBuildInputs = [ prisma-engines ];

  PRISMA_SCHEMA_ENGINE_BINARY = "${lib.getExe' prisma-engines "schema-engine"}";

  # The server references ./dist relative to CWD for static file serving.
  # Rewrite to an absolute path so the app can run from a writable state
  # directory (for uploads / database) while still serving the built frontend
  # from the read-only Nix store.
  postPatch = ''
    distPath="$out/libexec/hemmelig/dist"
    substituteInPlace server.ts \
      --replace-fail "./dist" "$distPath"
  '';

  preBuild = ''
    export DATABASE_URL="file:./dummy.db"
    npx prisma generate --schema=prisma/schema.prisma --generator client
  '';

  dontNpmInstall = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/hemmelig $out/bin

    # Frontend static files (built by vite)
    cp -r dist $out/libexec/hemmelig/dist

    # Backend source (run via tsx at runtime)
    cp server.ts $out/libexec/hemmelig/
    cp -r api $out/libexec/hemmelig/api

    # Prisma schema, migrations, generated client
    cp -r prisma $out/libexec/hemmelig/prisma
    cp prisma.config.ts $out/libexec/hemmelig/

    # Static assets
    cp -r public $out/libexec/hemmelig/public

    # Runtime dependencies (tsx + all modules).
    # We ship the full node_modules because tsx is a devDependency
    # and the backend runs TypeScript directly without pre-compilation.
    # npm prune would strip tsx, so we skip pruning.
    cp -r node_modules $out/libexec/hemmelig/node_modules
    cp package.json $out/libexec/hemmelig/

    cat > $out/bin/hemmelig <<EOF
    #!${stdenv.shell}
    set -eu
    exec ${lib.getExe nodejs_24} \\
      "$out/libexec/hemmelig/node_modules/.bin/tsx" \\
      "$out/libexec/hemmelig/server.ts"
    EOF
    chmod +x $out/bin/hemmelig

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/bin/hemmelig
    test -f $out/libexec/hemmelig/server.ts
    test -d $out/libexec/hemmelig/dist
    test -d $out/libexec/hemmelig/prisma/migrations
    test -f $out/libexec/hemmelig/node_modules/.bin/tsx
    test -d $out/libexec/hemmelig/node_modules/better-sqlite3
    runHook postInstallCheck
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Self-hosted encrypted secret sharing with client-side AES-256-GCM encryption and self-destructing messages";
    homepage = "https://github.com/HemmeligOrg/Hemmelig.app";
    changelog = "https://github.com/HemmeligOrg/Hemmelig.app/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "hemmelig";
  };
})
