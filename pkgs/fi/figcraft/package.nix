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
  pname = "figcraft";
  version = "0.13.1";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "figcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3Kjonr/fgC+XHWCglOVeEHIL2LnaQjB9ed9kzH4WOMU=";
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
    sed -i '/^egui_demo_lib = /d; /^egui_inspection = /d; /^egui_kittest = /d; /^egui_system_font_provider = /d' Cargo.toml
  '';

  cargoHash = "sha256-qWwOCtyd39k5YIIEEYfEb1X+SUuxZIEDwZ6qwoctTww=";

  cargoBuildFlags = [
    "-p"
    "figcraft"
    "-p"
    "figcraft-cli"
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
    install -Dm644 packaging/linux/ai.storyteller.figcraft.desktop \
      $out/share/applications/ai.storyteller.figcraft.desktop
    for size in 16 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.figcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.figcraft.png
    done
  '';

  meta = {
    description = "Open-source, native interface design and prototyping tool";
    homepage = "https://github.com/storytold/figcraft";
    changelog = "https://github.com/storytold/figcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "figcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
