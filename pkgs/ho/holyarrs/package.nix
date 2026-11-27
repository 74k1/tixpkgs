{
  lib,
  buildGo127Module,
  buildNpmPackage,
  fetchFromGitHub,
  nix-update-script,
  nodejs_24,
}:
let
  version = "1.3.6";

  src = fetchFromGitHub {
    owner = "HolyArrs";
    repo = "HolyArrs";
    tag = version;
    hash = "sha256-ZVdc5sNFpR0WbLV2yEi7zbge2aVYSulyunYKpn0ms0c=";
  };

  web = buildNpmPackage {
    pname = "holyarrs-web";
    inherit version src;

    # The build reads ../../VERSION, so the whole tree has to be unpacked.
    sourceRoot = "${src.name}/app/frontend";

    nodejs = nodejs_24;
    npmDepsHash = "sha256-ZdbW1QF97fpXNklG8ah9qf3dvHYxgAKWjSyKtakGckg=";
    # Upstream installs with `npm ci --ignore-scripts`.
    npmRebuildFlags = [ "--ignore-scripts" ];

    # Without it, the build name falls back to the build time.
    env.HOLYARRS_BUILD_ID = version;

    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
buildGo127Module (finalAttrs: {
  pname = "holyarrs";
  inherit version src;

  vendorHash = "sha256-AknXESCgU3b6YeWoWxwAYCT9f2oK5B7y/m02v/ftl8U=";

  # nixpkgs can trail upstream by a Go patch release. Any 1.27 toolchain builds it.
  postPatch = ''
    sed -i 's/^go 1\.27\.[0-9]*$/go 1.27/' go.mod
  '';

  env.CGO_ENABLED = 0;
  subPackages = [ "app/backend/cmd/holyarrs" ];
  # Nix owns updates, so the app never installs a version itself.
  tags = [ "noupdater" ];
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  # The program embeds the built pages from app/frontend/dist.
  preBuild = ''
    rm -rf app/frontend/dist
    cp -r ${web} app/frontend/dist
  '';

  # The suite runs for more than 25 minutes and starts local stand-in servers.
  doCheck = false;

  passthru = {
    inherit web;
    updateScript = nix-update-script { extraArgs = [ "--subpackage=web" ]; };
  };

  meta = {
    description = "Self-hosted manager for shows, movies, music, subtitles and requests in one app";
    homepage = "https://holyarrs.com";
    changelog = "https://github.com/HolyArrs/HolyArrs/releases/tag/${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "holyarrs";
    platforms = lib.platforms.linux;
  };
})
