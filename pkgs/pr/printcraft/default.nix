{
  lib,
  rustPlatform,
  fetchFromGitHub,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "printcraft";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "printcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-XRjNp87xei9tfU0KNLnf6Us90yGxQs3nfN0b/qGDld4=";
  };

  cargoHash = "sha256-Azzns+xa2bx6jn9XkL8RxvJ6PEXihWKtdASVtz1QblI=";

  prePatch = ''
    substituteInPlace "$cargoDepsCopy/source-registry-0/rten-gemm-0.26.0/src/i8dot.rs" \
      --replace-fail \
        '            if let Some(isa) = x86_64::Avx512VnniIsa::new() {' \
        '            #[cfg(any())]
            if let Some(isa) = x86_64::Avx512VnniIsa::new() {'
  '';

  cargoBuildFlags = [
    "-p"
    "printcraft"
    "-p"
    "printcraft-cli"
  ];

  doCheck = false;

  runtimeDependencies = [
    libxkbcommon
    vulkan-loader
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.printcraft.desktop \
      $out/share/applications/ai.storyteller.printcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.printcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.printcraft.png
    done
  '';

  meta = {
    description = "Open-source, native PDF reader, organizer and protector";
    homepage = "https://github.com/storytold/printcraft";
    changelog = "https://github.com/storytold/printcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "printcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
