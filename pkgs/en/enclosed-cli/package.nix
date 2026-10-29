{
  lib,
  stdenv,
  pnpmConfigHook,
  pnpm_12,
  nodejs_26,
  esbuild,
  makeWrapper,
  enclosed,
}:

# The CLI ships from the same repository and lockfile as the web app, so it
# reuses the app's source and dependency store instead of pinning its own.
# The version is inherited, so the `enclosed` update script keeps it current
# and this package needs no update script of its own.
stdenv.mkDerivation (finalAttrs: {
  pname = "enclosed-cli";
  inherit (enclosed) version src;

  pnpmDeps = enclosed.pnpmDeps;

  nativeBuildInputs = [
    nodejs_26
    pnpm_12
    pnpmConfigHook
    esbuild
    makeWrapper
  ];

  env = {
    PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN = "false";
    PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
  };

  buildPhase = ''
    runHook preBuild

    # The CLI imports the workspace lib, which imports the crypto package.
    pnpm --filter @enclosed/crypto run build
    pnpm --filter @enclosed/lib run build

    # unbuild keeps every declared dependency external, which would need the
    # whole pnpm store at runtime. Bundle the CLI into one file instead.
    esbuild packages/cli/src/cli.ts \
      --bundle \
      --platform=node \
      --format=esm \
      --target=node22 \
      --banner:js="import{createRequire as __nixRequire}from'node:module';const require=__nixRequire(import.meta.url);" \
      --outfile=packages/cli/dist/cli.mjs

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/enclosed-cli/bin
    cp -r packages/cli/dist $out/lib/enclosed-cli/dist
    # bin/enclosed.mjs imports ../dist/cli.mjs, so the layout is preserved.
    install -Dm644 packages/cli/bin/enclosed.mjs $out/lib/enclosed-cli/bin/enclosed.mjs

    makeWrapper ${lib.getExe nodejs_26} $out/bin/enclosed \
      --add-flags $out/lib/enclosed-cli/bin/enclosed.mjs

    runHook postInstall
  '';

  meta = {
    description = "Command-line client for creating and viewing Enclosed notes";
    homepage = "https://github.com/CorentinTh/enclosed";
    changelog = "https://github.com/CorentinTh/enclosed/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "enclosed";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
