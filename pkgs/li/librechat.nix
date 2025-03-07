{ lib
, stdenv
, fetchFromGitHub
, fetchYarnDeps
, nodejs
, yarn
, makeBinaryWrapper
, jq
}:

let
  src = fetchFromGitHub {
    owner = "danny-avila";
    repo = "LibreChat";
    rev = "v0.7.6";
    sha256 = "sha256-pyAF7FQcOoSO1a7XXGXdyahS1MUcc+LA0MetJv4ApqU=";
  };

  # Now we can use src
  yarnDeps = fetchYarnDeps {
    yarnLock = ./yarn.lock;
    hash = "sha256-VcUANDxyv/b1YC8GKkhGVl7sWNNf4l3jpBfZQv1pdGs=";
  };
in
stdenv.mkDerivation rec {
  pname = "librechat";
  version = "0.7.6";

  inherit src;  # Use the src we defined above

  nativeBuildInputs = [
    nodejs
    yarn
    makeBinaryWrapper
    jq
  ];

  patchPhase = ''
    # Add "private": true to package.json
    cat package.json | jq '. + {"private":true}' > package.json.new
    mv package.json.new package.json
    
    # Remove package-lock.json to avoid yarn warnings
    rm -f package-lock.json
  '';

  configurePhase = ''
    runHook preConfigure

    export HOME=$(mktemp -d)
    export YARN_CACHE_FOLDER="$HOME/.yarn"
    
    # Link the offline cache
    yarn config set yarn-offline-mirror ${yarnDeps}
    
    # Install dependencies in offline mode
    yarn install --offline --frozen-lockfile --ignore-scripts

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    export NODE_ENV=production
    yarn build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/librechat,share/librechat}
    
    cp -r api/dist/* $out/lib/librechat/
    cp -r node_modules $out/lib/librechat/
    cp package.json $out/lib/librechat/
    
    cp -r client/dist/* $out/share/librechat/

    makeWrapper ${nodejs}/bin/node $out/bin/librechat \
      --add-flags "$out/lib/librechat/server.js" \
      --set NODE_ENV production \
      --chdir $out/lib/librechat

    runHook postInstall
  '';

  meta = with lib; {
    description = "Enhanced ChatGPT Clone with multiple AI model support and advanced features";
    homepage = "https://www.librechat.ai";
    license = licenses.mit;
    maintainers = [ maintainers."74k1" ];
    platforms = platforms.all;
    mainProgram = "librechat";
  };
}
