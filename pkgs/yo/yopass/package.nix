{
  nix-update-script,
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
  version = "16.3.0";

  src = fetchFromGitHub {
    owner = "jhaals";
    repo = "yopass";
    rev = version;
    hash = "sha256-TtYgXophCs4pj9qfntwe/jiVSCaRCIPwrX2G3WC6OvU=";
  };

  website = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "yopass-website";
    inherit version;

    src = src + "/website";

    yarnOfflineCache = fetchYarnDeps {
      yarnLock = "${finalAttrs.src}/yarn.lock";
      hash = "sha256-kNeHzjafZbgToxtIH+wRJy9iVZQiSM9+MPFj/Q0P/5c=";
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

  vendorHash = "sha256-RA6NxehvddXV5cs5Cht1KPHMdCXkUZwZaId/ZDopA1E=";

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

  passthru = {
    inherit website;
    updateScript = nix-update-script { extraArgs = [ "--subpackage=website" ]; };
  };
})
