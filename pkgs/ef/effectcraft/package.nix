{
  lib,
  autoPatchelfHook,
  stdenv,
  pkg-config,
  rustPlatform,
  dbus,
  fetchFromGitHub,
  alsa-lib,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "effectcraft";
  version = "0.18.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "effectcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-5TDL98KE2j9blT8FeqMOTUznhfdJNOO+exn4LJcth58=";
  };

  postPatch = ''
    sed -i '/^egui_demo_lib = /d; /^egui_extras = /d; /^egui_inspection = /d; /^egui_system_font_provider = /d' Cargo.toml
  '';

  cargoHash = "sha256-PxW3amIo5yA2jlupIUePFTx72tdfcmXcyK0/eC79KTM=";


  nativeBuildInputs = [ autoPatchelfHook pkg-config ];
  buildInputs = [ alsa-lib stdenv.cc.cc.lib ];

  cargoBuildFlags = [
    "-p"
    "effectcraft"
    "-p"
    "effectcraft-cli"
  ];

  doCheck = false;

  runtimeDependencies = [
    dbus.lib
    libxkbcommon
    vulkan-loader
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.effectcraft.desktop \
      $out/share/applications/ai.storyteller.effectcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.effectcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.effectcraft.png
    done
  '';

  meta = {
    description = "Open-source, native motion graphics and visual effects app";
    homepage = "https://github.com/storytold/effectcraft";
    changelog = "https://github.com/storytold/effectcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "effectcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
