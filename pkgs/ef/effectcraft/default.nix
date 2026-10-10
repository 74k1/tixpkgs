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
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "effectcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4Yv2dcN8DSLzF2QTmz3FCW3Hr7yFMemjxEgCW7jTGeU=";
  };

  cargoHash = "sha256-BqmywAtIP6yuNV+qKxZD7eEiMA5g7wDglKYi9/wtUwU=";


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
