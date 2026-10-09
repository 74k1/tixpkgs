{
  buildGo127Module,
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
  version = "15.0.0";

  src = fetchFromGitHub {
    owner = "jhaals";
    repo = "yopass";
    rev = version;
    hash = "sha256-rsAl8sHMpdjpofMKbo+49gBkTYk8+C9DWFqEd/ji2Nk=";
  };

  website = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "yopass-website";
    inherit version;

    src = src + "/website";

    yarnOfflineCache = fetchYarnDeps {
      yarnLock = "${finalAttrs.src}/yarn.lock";
      hash = "sha256-AbOO+BXGfqNMVnxvqzPqxK8XgrFCgOuImlJxDbci2wY=";
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
buildGo127Module (finalAttrs: {
  inherit version src;
  pname = "yopass";

  vendorHash = "sha256-1En0Qqua5u/coVj+c7yyjbJpDoC14LeDJar/0Png8SU=";

  # Upstream ships a go.work since 14.10; vendor the module, not the workspace.
  env.GOWORK = "off";

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
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "yopass";
    platforms = lib.platforms.unix;
  };

  passthru.updateScript = ./update.sh;
})
