{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_12,
  nodejs_26,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "enclosed";
  version = "1.16.1";

  src = fetchFromGitHub {
    owner = "CorentinTh";
    repo = "enclosed";
    tag = "v${finalAttrs.version}";
    hash = "sha256-sBkFRs+DE0LqU5VA1OZ20IKeL4qAIYSLScMfkKVJ6Cs=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_12;
    fetcherVersion = 5;
    hash = "sha256-yNYVwJZwN6QVOXWD5B2o70Tqa9K2yIrF7iezRLbtfpw=";
  };

  nativeBuildInputs = [
    nodejs_26
    pnpm_12
    pnpmConfigHook
    makeWrapper
  ];

  env = {
    # Dependencies are installed by pnpmConfigHook. Do not let pnpm re-resolve
    # them, or fetch the package manager version pinned in package.json.
    PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN = "false";
    PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
  };

  buildPhase = ''
    runHook preBuild

    # The server bundle embeds the built crypto and lib workspace packages.
    pnpm --filter @enclosed/crypto run build
    pnpm --filter @enclosed/lib run build
    pnpm --filter @enclosed/app-client run build
    pnpm --filter @enclosed/app-server run build:node

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # The server resolves `public/` relative to the working directory, so the
    # client build has to live next to the server bundle.
    mkdir -p $out/share/enclosed
    cp -r packages/app-client/dist $out/share/enclosed/public
    install -Dm644 packages/app-server/dist-node/index.cjs $out/share/enclosed/index.cjs

    makeWrapper ${lib.getExe nodejs_26} $out/bin/enclosed \
      --chdir $out/share/enclosed \
      --set-default NODE_ENV production \
      --run 'export STORAGE_DRIVER_FS_LITE_PATH="''${STORAGE_DRIVER_FS_LITE_PATH:-''${XDG_STATE_HOME:-$HOME/.local/state}/enclosed}"' \
      --add-flags $out/share/enclosed/index.cjs

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Minimalistic web application for sending end-to-end encrypted notes";
    homepage = "https://github.com/CorentinTh/enclosed";
    changelog = "https://github.com/CorentinTh/enclosed/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "enclosed";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
