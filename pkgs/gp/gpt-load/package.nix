{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  fetchPnpmDeps,
  nix-update-script,
  nodejs_24,
  pnpm_11,
  pnpmConfigHook,
  stdenvNoCC,
}:
let
  version = "2.0.0-rc.65";
  src = fetchFromGitHub {
    owner = "tbphp";
    repo = "gpt-load";
    tag = "v${version}";
    hash = "sha256-UQA4+XyBIzO1pKViOFP9Ti9Th+UiaXKC0aTrelT5dTk=";
  };

  website = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "gpt-load-website";
    inherit version;
    src = src + "/web";

    postPatch = ''
      substituteInPlace package.json --replace-fail '"pnpm": "11.17.0"' '"pnpm": "11"'
    '';

    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs)
        pname
        version
        src
        postPatch
        ;
      pnpm = pnpm_11;
      fetcherVersion = 5;
      hash = "sha256-CkQWf3yYny0+w6pvqpsmSiXUy2y8neFneNiQcqgOHNg=";
    };

    nativeBuildInputs = [
      nodejs_24
      pnpm_11
      pnpmConfigHook
    ];
    env.PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";

    buildPhase = ''
      runHook preBuild
      mkdir -p ../internal/webui
      cp ${src}/internal/webui/*page_routes.json ../internal/webui/
      pnpm run build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      cp -r ../internal/webui/dist $out
      runHook postInstall
    '';
  });
in
buildGo127Module (finalAttrs: {
  pname = "gpt-load";
  inherit version src;

  vendorHash = "sha256-mi9yuWaRP9Juyc8OTBjUUtc7qevz754yqOtjqhGEGN8=";
  env.CGO_ENABLED = 0;
  subPackages = [ "." ];
  # The build sandbox returns EINVAL instead of EPERM for an unmapped group.
  checkFlags = [ "-skip=^TestPreserveExecutableOwnerFailsWhenGroupCannotBeKept$" ];
  ldflags = [
    "-s"
    "-w"
    "-X gpt-load/internal/platform/version.Version=${version}"
  ];

  preBuild = ''
    mkdir -p internal/webui/dist
    cp -r ${website}/. internal/webui/dist/
  '';

  passthru = {
    inherit website;
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage=website"
        "--version-regex=^v(2\\.[0-9]+\\.[0-9]+(?:-rc\\.[0-9]+)?)$"
      ];
    };
  };

  meta = {
    description = "Self-hosted AI gateway with credential scheduling and failover";
    homepage = "https://github.com/tbphp/gpt-load";
    changelog = "https://github.com/tbphp/gpt-load/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "gpt-load";
    platforms = lib.platforms.unix;
  };
})
