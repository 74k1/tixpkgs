{
  lib,
  stdenv,
  nodejs,
  pnpm,
  pnpmConfigHook,
  fetchFromGitHub,
  fetchPnpmDeps,
  makeWrapper,
}:

# PowerSync service — syncs Postgres changes out to PowerSync clients.
#
# Source-available (FSL-1.1-ALv2), NOT FOSS. Backend required by the
# Thunderbolt web frontend's PowerSync sync client.
#
# fetchPnpmDeps uses `fetcherVersion = 4` (SQLite-dump store layout); the
# pnpmConfigHook handles store unpacking, sqlite index reconstruction, and
# the offline `pnpm install`.
stdenv.mkDerivation (finalAttrs:
let
  pname = "powersync-service";
  version = "1.23.3";
in
{
  inherit pname version;

  src = fetchFromGitHub {
    owner = "powersync-ja";
    repo = "powersync-service";
    rev = "v${version}";
    hash = "sha256-msEO9yO+fu811JD8MUm7hVyO9doxw2f1OYtfcjfGsK4=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname src;
    fetcherVersion = 4;
    hash = "sha256-H+ffjAx+FKqQyLiIctdKPBHYC4/fEVlwNYMjAHMJu4U=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild

    # Only build the service and its workspace dependencies. The upstream
    # `pnpm build:production` also builds unused packages such as test-client.
    NODE_ENV=production pnpm run -r --filter ...@powersync/service-image build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    packageRoot="$out/share/${pname}"
    mkdir -p "$out/bin" "$packageRoot"

    # pnpm's virtual store symlinks workspace packages (packages/, libs/, modules/,
    # service/) back into the source tree, so the whole build tree must go along.
    cp -r . "$packageRoot"

    makeWrapper ${lib.getExe nodejs} "$out/bin/${pname}" \
      --chdir "$packageRoot" \
      --set NODE_ENV production \
      --add-flags ./service/lib/entry.js

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Self-hosted PowerSync sync service backend";
    homepage = "https://www.powersync.com";
    license = lib.licenses.fsl11Asl20;
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "powersync-service";
    platforms = lib.platforms.linux;
  };
})