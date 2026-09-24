{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "multi-scrobbler";
  version = "0.18.1";

  src = fetchFromGitHub {
    owner = "FoxxMD";
    repo = "multi-scrobbler";
    rev = version;
    hash = "sha256-WD36TFbXJ5WXWuA47zH3a3qLMNAw+ZMceDfSazAI0BE=";
  };

  npmDepsHash = "sha256-qnu0+XdvWGviaPgvzxt/XFaodkjivICPdLmeezkAhYI=";

  npmBuildScript = "build:frontend";

  npmRebuildFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  env = {
    npm_config_nodedir = nodejs_24;
  };

  # Upstream applies patches/*.patch from its "postinstall": "patch-package" script, but
  # npmConfigHook runs `npm ci --ignore-scripts`, so they never get applied here.
  # The sqlite-up patch is load bearing: it makes Migrator.apply() pass a context to each
  # migration, which appMigrations/002+ dereference (ctx.logger, ctx.db). Without it the
  # service dies on startup with "Failed to apply migration 002_inputHash.ts".
  preBuild = ''
    if [ -d patches ]; then
      for upstreamPatch in patches/*.patch; do
        [ -e "$upstreamPatch" ] || continue
        echo "Applying upstream patch $upstreamPatch"
        patch -p1 --forward --batch < "$upstreamPatch"
      done
    fi
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/${pname}

    cp package.json package-lock.json $out/share/${pname}/
    cp -r dist public src $out/share/${pname}/
    cp -r node_modules $out/share/${pname}/

    makeWrapper ${lib.getExe nodejs_24} $out/bin/${pname} \
      --chdir $out/share/${pname} \
      --set NODE_ENV production \
      --add-flags ./src/backend/index.ts

    makeWrapper ${lib.getExe nodejs_24} $out/bin/${pname}-service \
      --set NODE_ENV production \
      --add-flags $out/share/${pname}/src/backend/index.ts

    runHook postInstall
  '';

  meta = {
    description = "Scrobble plays from multiple sources to multiple clients";
    homepage = "https://multi-scrobbler.app";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "multi-scrobbler";
  };
}
