{
  lib,
  stdenvNoCC,
  fetchurl,
  bun,
  cacert,
  curl,
  git,
  makeWrapper,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "degoog";
  version = "0.22.0";

  src = fetchurl {
    url = "https://github.com/degoog-org/degoog/releases/download/${finalAttrs.version}/degoog_${finalAttrs.version}_prebuild.tar.gz";
    hash = "sha256-gjkHRNeCJqzeT361v+01H3Ke86iFomLCSN1qD9V+P2M=";
  };

  sourceRoot = "degoog";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/degoog
    cp -r . $out/share/degoog/

    makeWrapper ${lib.getExe bun} $out/bin/degoog \
      --add-flags "run" \
      --add-flags "src/server/index.ts" \
      --chdir "$out/share/degoog" \
      --prefix PATH : ${lib.makeBinPath [ curl git ]} \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt"

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Search engine aggregator with a comprehensive plugin/extension system";
    homepage = "https://github.com/degoog-org/degoog";
    changelog = "https://github.com/degoog-org/degoog/releases/tag/${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "degoog";
    maintainers = [ "74k1" ];
    platforms = lib.platforms.unix;
  };
})
