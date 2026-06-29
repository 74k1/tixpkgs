{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "multi-scrobbler";
  version = "0.14.1";

  src = fetchFromGitHub {
    owner = "FoxxMD";
    repo = "multi-scrobbler";
    rev = version;
    hash = "sha256-WrNheETW6snvtitL2IOcOQWBZgfLOIPO/x5Y8Q6lmTc=";
  };

  npmDepsHash = "sha256-K6zKmkjoBcshZ9mWeM1BiBFtM8/ekf9A1S1xwJ/p7PA=";

  npmBuildScript = "build:backend";

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
