{
  lib,
  alsa-lib,
  libxkbcommon,
  autoPatchelfHook,
  stdenv,
  pkg-config,
  rustPlatform,
  dbus,
  fetchFromGitHub,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "filmcraft";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "filmcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-qM8o8rSiiGBif0UePQpn6aAEzqbjIMx3ZRoE3wA1yFI=";
  };

  cargoHash = "sha256-uzDeo+94RAK/flnYgTic167BeYfk2zqwwf/ODbwnok0=";


  nativeBuildInputs = [ autoPatchelfHook pkg-config ];
  buildInputs = [ alsa-lib stdenv.cc.cc.lib ];

  cargoBuildFlags = [
    "-p"
    "filmcraft"
    "-p"
    "filmcraft-cli"
  ];

  doCheck = false;

  runtimeDependencies = [
    dbus.lib
    libxkbcommon
    vulkan-loader
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.filmcraft.desktop \
      $out/share/applications/ai.storyteller.filmcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.filmcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.filmcraft.png
    done
  '';

  meta = {
    description = "Open-source, native video editor with color and sound";
    homepage = "https://github.com/storytold/filmcraft";
    changelog = "https://github.com/storytold/filmcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "filmcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
