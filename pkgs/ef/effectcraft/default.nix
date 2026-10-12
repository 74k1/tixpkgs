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
  version = "0.9.2";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "effectcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Ra2oQ+ynFhcRS/X6xpiYXC60vNjOKvrDS3J2f8HipeE=";
  };

  cargoHash = "sha256-1GFQnsEw7vEHrSXAJgyGqkanVhGWPBDyE5rpTWicTAQ=";


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
