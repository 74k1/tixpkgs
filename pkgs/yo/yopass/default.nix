{
  buildGoModule,
  fetchFromGitHub,
  fetchYarnDeps,
  lib,
  makeBinaryWrapper,
  nodejs,
  stdenvNoCC,
  yarnBuildHook,
  yarnConfigHook,
}:
let
  version = "14.0.0";

  src = fetchFromGitHub {
    owner = "jhaals";
    repo = "yopass";
    rev = version;
    hash = "sha256-AbYmjdd5GyX3vOfsml8fptnRhwTcQZTr+PiHtdqbJfI=";
  };

  website = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "yopass-website";
    inherit version;

    src = src + "/website";

    yarnOfflineCache = fetchYarnDeps {
      yarnLock = "${finalAttrs.src}/yarn.lock";
      hash = "sha256-81Z2xxWkEUgMCYAHK6RCsl0AjqehCTRLLSZAPWTtMD8=";
    };

    nativeBuildInputs = [
      nodejs
      yarnBuildHook
      yarnConfigHook
    ];

    installPhase = ''
      runHook preInstall

      mv dist $out

      runHook postInstall
    '';
  });
in
buildGoModule (finalAttrs: {
  inherit version src;
  pname = "yopass";

  vendorHash = "sha256-4gQOXYDA0aN5CdTP6IPv7LuJNdIKKST8qD8fPvo8ZS4=";

  nativeBuildInputs = [ makeBinaryWrapper ];

  subPackages = [
    "cmd/yopass"
    "cmd/yopass-server"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  checkFlags = [
    # Disable tests that require network access
    "-skip=TestSecretNotFoundError|TestNewServer"
  ];

  postInstall = ''
    wrapProgram $out/bin/yopass-server \
      --add-flags "--asset-path ${website}"
  '';

  meta = {
    description = "Secure sharing of secrets, passwords and files";
    homepage = "https://github.com/jhaals/yopass";
    changelog = "https://github.com/jhaals/yopass/releases/tag/${finalAttrs.src.rev}";
    license = lib.licenses.asl20;
    maintainers = [ "74k1" ];
    mainProgram = "yopass";
    platforms = lib.platforms.unix;
  };

  passthru.updateScript = ./update.sh;
})