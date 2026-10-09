{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  makeWrapper,
  writableTmpDirAsHomeHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "degoog-mcp";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "degoog-org";
    repo = "mcp";
    tag = finalAttrs.version;
    hash = "sha256-P99iylJBt+OdO8CXifb0cu1oYWlB6fyoGnTO1sn+fdo=";
  };

  # Fixed-output `bun install`. --production skips devDependencies
  # (typescript 7 ships per-platform native binaries, which would make this
  # hash platform-specific); `bun build` does not need them.
  node_modules = stdenvNoCC.mkDerivation {
    pname = "degoog-mcp-node-modules";
    inherit (finalAttrs) version src;

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --frozen-lockfile \
        --production \
        --ignore-scripts \
        --no-progress
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r ./node_modules $out
      runHook postInstall
    '';

    dontFixup = true;

    outputHash = "sha256-Cz5Bb766Qx/POFsbbvpoHg4VDQ32DagkR5cUR+4kw88=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  configurePhase = ''
    runHook preConfigure
    cp -R ${finalAttrs.node_modules} node_modules
    chmod -R u+w node_modules
    runHook postConfigure
  '';

  # Same as upstream's Dockerfile: bundle everything into a single file.
  buildPhase = ''
    runHook preBuild
    bun build src/main.ts --target=bun --outdir=dist --minify
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 dist/main.js $out/share/degoog-mcp/main.js
    makeWrapper ${lib.getExe bun} $out/bin/degoog-mcp \
      --add-flags "run $out/share/degoog-mcp/main.js"
    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "MCP server sidecar for the Degoog search aggregator";
    homepage = "https://github.com/degoog-org/mcp";
    changelog = "https://github.com/degoog-org/mcp/releases/tag/${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "degoog-mcp";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
