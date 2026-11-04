{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_24,
}:

buildNpmPackage (finalAttrs: {
  pname = "cli-microsoft365";
  version = "12.0.0";

  src = fetchFromGitHub {
    owner = "pnp";
    repo = "cli-microsoft365";
    tag = "v${finalAttrs.version}";
    hash = "sha256-gfXHbB4NN/ZLR+bOn8LDY7ezS9PWTjTi/kLCSDB0FeM=";
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-it7IZAjsfHbbAiOIa2D/01bA+pOS8nZs4bPEzHNGGHY=";

  # Upstream ships npm-shrinkwrap.json with 354 entries that have no `resolved`
  # URLs (npm omits them for registry packages in some CI setups), so npm ci
  # cannot resolve them offline. Use the normalized lockfile in this directory
  # instead; it pins the same versions and adds the missing URLs.
  postPatch = ''
    rm npm-shrinkwrap.json
    cp ${./package-lock.json} package-lock.json
  '';

  # keytar (pulled in by the optional @azure/msal-node-extensions) has no
  # prebuilt binary for NixOS and its install script requires network access.
  # On Linux the CLI catches the failed import and falls back to its plaintext
  # file cache.
  npmRebuildFlags = [ "--ignore-scripts" ];

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Manage Microsoft 365 and SharePoint Framework projects on any platform";
    homepage = "https://pnp.github.io/cli-microsoft365/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "m365";
  };
})
