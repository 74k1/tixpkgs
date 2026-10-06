{
  lib,
  rustPlatform,
  fetchFromGitHub,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "vectorcraft";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "vectorcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-whn2OTG9xMVH2s6Q/YCaHKaIs/QLu69Uq8rS1OPLeLg=";
  };

  cargoHash = "sha256-UyP3ZvZ/PxH2thA+kKXv2emNwrzKDpTFQkiGMRdnGiU=";

  cargoBuildFlags = [
    "-p"
    "vectorcraft"
    "-p"
    "vectorcraft-cli"
  ];

  doCheck = false;

  runtimeDependencies = [
    libxkbcommon
    vulkan-loader
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.vectorcraft.desktop \
      $out/share/applications/ai.storyteller.vectorcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.vectorcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.vectorcraft.png
    done
  '';

  meta = {
    description = "Open-source, native vector illustration app";
    homepage = "https://github.com/storytold/vectorcraft";
    changelog = "https://github.com/storytold/vectorcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "vectorcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
