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
  pname = "pdfcraft";
  version = "0.15.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "pdfcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9XgS4feVsc+2c6aMi9WbG1NI/SjVhjU3otMU9bmQez0=";
  };

  buildInputs = [ stdenv.cc.cc.lib ];

  nativeBuildInputs = [ autoPatchelfHook ];

  postPatch = ''
    sed -i '/^egui_demo_lib = /d; /^egui_inspection = /d; /^egui_system_font_provider = /d' Cargo.toml
  '';

  cargoHash = "sha256-n2hA1QOPUVG65EMCpEWu8kUEHoVV3nTCNq9sja3cNqQ=";

  prePatch = ''
    substituteInPlace "$cargoDepsCopy/source-registry-0/rten-gemm-0.26.0/src/i8dot.rs" \
      --replace-fail \
        '            if let Some(isa) = x86_64::Avx512VnniIsa::new() {' \
        '            #[cfg(any())]
            if let Some(isa) = x86_64::Avx512VnniIsa::new() {'
  '';

  cargoBuildFlags = [
    "-p"
    "pdfcraft"
    "-p"
    "pdfcraft-cli"
  ];

  doCheck = false;

  runtimeDependencies = [
    dbus.lib
    libxkbcommon
    vulkan-loader
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.pdfcraft.desktop \
      $out/share/applications/ai.storyteller.pdfcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.pdfcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.pdfcraft.png
    done
  '';

  meta = {
    description = "Open-source, native PDF reader, organizer and protector";
    homepage = "https://github.com/storytold/pdfcraft";
    changelog = "https://github.com/storytold/pdfcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "pdfcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
