{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "multi-scrobbler";
  version = "0.14.2";

  src = fetchFromGitHub {
    owner = "FoxxMD";
    repo = "multi-scrobbler";
    rev = version;
    hash = "sha256-FHpHVQ3M/n8/LcMvl2LGakTjS6u2IebhGZRrO4GAZf8=";
  };

  npmDepsHash = "sha256-b8BYqJVOSOInW1H2DpxBN9ETcVHA8/f/yHJ8b72zvsk=";

  npmBuildScript = "schema:app";

  npmRebuildFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  env = {
    npm_config_nodedir = nodejs_24;
  };

  postBuild = ''
    npm run build:frontend
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
      --add-flags ./node_modules/.bin/tsx \
      --add-flags ./src/backend/index.ts

    makeWrapper ${lib.getExe nodejs_24} $out/bin/${pname}-service \
      --set NODE_ENV production \
      --add-flags $out/share/${pname}/node_modules/.bin/tsx \
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
