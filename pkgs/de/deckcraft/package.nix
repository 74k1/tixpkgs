{
  lib,
  rustPlatform,
  alsa-lib,
  autoPatchelfHook,
  pkg-config,
  stdenv,
  dbus,
  fetchFromGitHub,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrandr,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "deckcraft";
  version = "0.12.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "deckcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BWRINVloBo8oCobZ3eW0G5dcWrQ6jYZhuKMHvKUpcWA=";
  };

  buildInputs = [
    alsa-lib
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    libxrandr
    stdenv.cc.cc.lib
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    pkg-config
  ];

  postPatch = ''
    sed -i '/^egui_demo_lib = /d; /^egui_extras = /d; /^egui_inspection = /d; /^egui_system_font_provider = /d' Cargo.toml
  '';

  cargoHash = "sha256-befhMAAiQ1OZXfHXakmt9gU00/EEYaANLGEr9s1mKHM=";

  cargoBuildFlags = [
    "-p"
    "deckcraft"
    "-p"
    "deckcraft-cli"
  ];

  doCheck = false;

  runtimeDependencies = [
    libx11
    libxcb
    libxcursor
    libxi
    dbus.lib
    libxkbcommon
    libxrandr
    vulkan-loader
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.deckcraft.desktop \
      $out/share/applications/ai.storyteller.deckcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.deckcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.deckcraft.png
    done
  '';

  meta = {
    description = "Presentations and slide shows, a clean-room reimplementation of Microsoft PowerPoint in pure Rust";
    homepage = "https://github.com/storytold/deckcraft";
    changelog = "https://github.com/storytold/deckcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "deckcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
