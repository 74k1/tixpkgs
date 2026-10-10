{
  lib,
  rustPlatform,
  autoPatchelfHook,
  stdenv,
  dbus,
  fetchFromGitHub,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "lightcraft";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "lightcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-N/V/MIf+8u9zCytsWLIr4muXjmrqfc+o78PFUFhlQS8=";
  };

  buildInputs = [ stdenv.cc.cc.lib ];

  nativeBuildInputs = [ autoPatchelfHook ];

  cargoHash = "sha256-IAhOBq6dnMmbmZFVv4UQh2wmt2hNKYmWJ1PhTFI4dsU=";

  cargoBuildFlags = [
    "-p"
    "lightcraft"
    "-p"
    "lightcraft-cli"
  ];

  doCheck = false;

  runtimeDependencies = [
    dbus.lib
    libxkbcommon
    vulkan-loader
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.lightcraft.desktop \
      $out/share/applications/ai.storyteller.lightcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.lightcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.lightcraft.png
    done
  '';

  meta = {
    description = "Open-source, native photo library and raw developer";
    homepage = "https://github.com/storytold/lightcraft";
    changelog = "https://github.com/storytold/lightcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "lightcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
