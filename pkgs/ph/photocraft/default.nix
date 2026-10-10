{
  lib,
  rustPlatform,
  autoPatchelfHook,
  stdenv,
  dbus,
  fetchFromGitHub,
  libglvnd,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "photocraft";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "photocraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-jjQXjLLAg1hfp9Ikw/f8TmmG7hWOa/zaxA5u2oVB+dQ=";
  };

  buildInputs = [ stdenv.cc.cc.lib ];

  nativeBuildInputs = [ autoPatchelfHook ];

  cargoHash = "sha256-X5AB6CkTqlwpBSjFqNwMBvUZmYGzeFLVMlqGUscztNI=";

  cargoBuildFlags = [
    "-p"
    "photocraft"
    "-p"
    "photocraft-cli"
  ];

  doCheck = false;

  runtimeDependencies = [
    libglvnd
    dbus.lib
    libxkbcommon
    vulkan-loader
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.photocraft.desktop \
      $out/share/applications/ai.storyteller.photocraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.photocraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.photocraft.png
    done
  '';

  meta = {
    description = "Open-source, clean-room reimplementation of Adobe Photoshop in pure Rust";
    homepage = "https://github.com/storytold/photocraft";
    changelog = "https://github.com/storytold/photocraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "photocraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
