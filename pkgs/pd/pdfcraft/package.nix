{
  lib,
  rustPlatform,
  autoPatchelfHook,
  aws-lc,
  stdenv,
  dbus,
  fetchFromGitHub,
  libxkbcommon,
  pkg-config,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "pdfcraft";
  version = "0.21.1";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "pdfcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-2X2ixtr7mxHRpfhcGghKUO7ib0SFBruBmQPIlTFZ8Ds=";
  };

  buildInputs = [
    aws-lc
    stdenv.cc.cc.lib
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    pkg-config
  ];

  postPatch = ''
    sed -i '/^egui_demo_lib = /d; /^egui_inspection = /d; /^egui_system_font_provider = /d' Cargo.toml
  '';

  cargoHash = "sha256-sjnRF9WVDRPrgEgwZEyVIEk3qq3Erkv9cBtlkgb52lc=";

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
