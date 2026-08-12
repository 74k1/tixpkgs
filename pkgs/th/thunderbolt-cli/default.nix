{
  lib,
  stdenvNoCC,
  bun,
  fetchFromGitHub,
  writableTmpDirAsHomeHook,
}:

let
  version = "0.1.107";
  src = fetchFromGitHub {
    owner = "thunderbird";
    repo = "thunderbolt";
    tag = "v${version}";
    hash = "sha256-CBt8vGUO2w9SlU0lwTVrg+mKekN8D4Dd7JJQUEzGQjQ=";
  };
in

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "thunderbolt-cli";
  inherit version;

  inherit src;

  cliNodeModules = stdenvNoCC.mkDerivation {
    pname = "thunderbolt-cli-node-modules";
    inherit version;
    src = src;
    sourceRoot = "${src.name}/cli";

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;
    dontFixup = true;
    dontPatchShebangs = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install --frozen-lockfile --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cp -R node_modules $out

      runHook postInstall
    '';

    outputHash = "sha256-lTSKqrUEt3EzW8dzuLjK2Y7+J4viWtvp98HEk0XTcXA=";
    outputHashMode = "recursive";
  };

  sourceRoot = "${src.name}/cli";

  nativeBuildInputs = [
    bun
    writableTmpDirAsHomeHook
  ];

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.cliNodeModules} node_modules
    chmod -R u+rwX node_modules

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    bun build --compile --minify --sourcemap src/index.ts --outfile dist/thunderbolt

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp dist/thunderbolt $out/bin/thunderbolt
    chmod +x $out/bin/thunderbolt

    runHook postInstall
  '';

  meta = {
    description = "Thunderbolt CLI — a portable, single-binary terminal coding agent";
    homepage = "https://thunderbolt.io";
    license = lib.licenses.mpl20;
    mainProgram = "thunderbolt";
    platforms = lib.platforms.linux;
  };
})