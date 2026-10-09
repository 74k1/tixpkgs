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
  pname = "cadcraft";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "cadcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-VFw6np9BSOdBQrKlIiNnQ0kKKNfGnYMctbceBpmE778=";
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

  cargoHash = "sha256-R0nr3XMPU8nL9qV05bHDqW0YGa3pk3mu4kXIF31pm2U=";

  cargoBuildFlags = [
    "-p"
    "cadcraft"
    "-p"
    "cadcraft-cli"
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
    install -Dm644 packaging/linux/ai.storyteller.cadcraft.desktop \
      $out/share/applications/ai.storyteller.cadcraft.desktop
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.cadcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.cadcraft.png
    done
  '';

  meta = {
    description = "Computer-aided design and drafting, a clean-room AutoCAD-style app in pure Rust";
    homepage = "https://github.com/storytold/cadcraft";
    changelog = "https://github.com/storytold/cadcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "cadcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
