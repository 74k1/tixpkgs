{
  lib,
  rustPlatform,
  autoPatchelfHook,
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
  pname = "wordcraft";
  version = "0.13.2";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "wordcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Y+lVmOeuZHovomHqi1z/15v9GGxaOs6HxD8PmRzBOY4=";
  };

  buildInputs = [
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    libxrandr
    stdenv.cc.cc.lib
  ];

  nativeBuildInputs = [ autoPatchelfHook ];

  postPatch = ''
    sed -i '/^egui_demo_lib = /d; /^egui_extras = /d; /^egui_inspection = /d; /^egui_system_font_provider = /d' Cargo.toml
  '';

  cargoHash = "sha256-nPgPlmWlzTAExqGue06uAmeanMNssPlFCzH9W41dceI=";

  cargoBuildFlags = [
    "-p"
    "wordcraft"
    "-p"
    "wordcraft-cli"
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
    install -Dm644 packaging/linux/ai.storyteller.wordcraft.desktop \
      $out/share/applications/ai.storyteller.wordcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.wordcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.wordcraft.png
    done
  '';

  meta = {
    description = "Open-source, clean-room reimplementation of Microsoft Word in pure Rust";
    homepage = "https://github.com/storytold/wordcraft";
    changelog = "https://github.com/storytold/wordcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "wordcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
