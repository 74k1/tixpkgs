{
  lib,
  rustPlatform,
  autoPatchelfHook,
  stdenv,
  dbus,
  fetchFromGitHub,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "vectorcraft";
  version = "0.12.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "vectorcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-8wlih5NQtcDBRBv7wJ+AQP3M5yHSAYpT+5xDEFiS4yY=";
  };

  buildInputs = [ stdenv.cc.cc.lib ];

  nativeBuildInputs = [ autoPatchelfHook ];

  cargoHash = "sha256-yf5+kbSb7381SoD8fAl4rsPGruTyqwHiVIUcolSFHAc=";

  cargoBuildFlags = [
    "-p"
    "vectorcraft"
    "-p"
    "vectorcraft-cli"
  ];

  doCheck = false;

  runtimeDependencies = [
    dbus.lib
    libxkbcommon
    vulkan-loader
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.vectorcraft.desktop \
      $out/share/applications/ai.storyteller.vectorcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.vectorcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.vectorcraft.png
    done
  '';

  meta = {
    description = "Open-source, native vector illustration app";
    homepage = "https://github.com/storytold/vectorcraft";
    changelog = "https://github.com/storytold/vectorcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "vectorcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
