{
  lib,
  autoPatchelfHook,
  pkg-config,
  rustPlatform,
  stdenv,
  dbus,
  fetchFromGitHub,
  alsa-lib,
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
  pname = "soundcraft";
  version = "0.12.1";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "soundcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-KiNJ/iVR8QHW6z6BBTS3n1TCGsFsWkY2N+OMyywjND0=";
  };

  cargoHash = "sha256-JHI2cqHfGYMn9e8QmRDt16sKc5mdIbjo/ajSnGMGpLA=";

  nativeBuildInputs = [
    autoPatchelfHook
    pkg-config
  ];

  buildInputs = [
    alsa-lib
    stdenv.cc.cc.lib
  ];

  cargoBuildFlags = [
    "-p"
    "soundcraft"
    "-p"
    "soundcraft-cli"
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
    install -Dm644 packaging/linux/ai.storyteller.soundcraft.desktop \
      $out/share/applications/ai.storyteller.soundcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.soundcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.soundcraft.png
    done
  '';

  meta = {
    description = "Open-source, clean-room reimplementation of Avid Pro Tools in pure Rust";
    homepage = "https://github.com/storytold/soundcraft";
    changelog = "https://github.com/storytold/soundcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "soundcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
