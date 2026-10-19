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
  pname = "gridcraft";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "gridcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-G0xsNWRoNMtA5lTKSZgLCHP6gcq+zOaOPdcColuFr0A=";
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

  cargoHash = "sha256-EY/41uMNm9hG7LhynI4d/7RSj5tGXsT8/s+Al8mr7pk=";

  cargoBuildFlags = [
    "-p"
    "gridcraft"
    "-p"
    "gridcraft-cli"
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
    install -Dm644 packaging/linux/ai.storyteller.gridcraft.desktop \
      $out/share/applications/ai.storyteller.gridcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.gridcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.gridcraft.png
    done
  '';

  meta = {
    description = "Open-source, clean-room spreadsheet (Microsoft Excel-style) in pure Rust";
    homepage = "https://github.com/storytold/gridcraft";
    changelog = "https://github.com/storytold/gridcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "gridcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
