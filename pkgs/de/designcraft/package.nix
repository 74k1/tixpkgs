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
  pname = "designcraft";
  version = "0.15.2";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "designcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-NGydGM7FpiWgULp9d1ZUnhCa0VjV9oN6WFNrQxsUGtw=";
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

  cargoHash = "sha256-298+L5lripexk/gB5BOTZWGiD8JyShofN+Zd43HXMWQ=";

  cargoBuildFlags = [
    "-p"
    "designcraft"
    "-p"
    "designcraft-cli"
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
    install -Dm644 packaging/linux/ai.storyteller.designcraft.desktop \
      $out/share/applications/ai.storyteller.designcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.designcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.designcraft.png
    done
  '';

  meta = {
    description = "Open-source, native page layout and publishing app";
    homepage = "https://github.com/storytold/designcraft";
    changelog = "https://github.com/storytold/designcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "designcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
