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
  pname = "figcraft";
  version = "0.11.2";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "figcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-m/esZA+zHBEEsJxtorMF00NhlCkrFj7p6sFWOJt4JAY=";
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

  cargoHash = "sha256-EB/qkhEhZil1YxItkg+OAWl9KxXAD7W5y1+dxRKuUG4=";

  cargoBuildFlags = [
    "-p"
    "figcraft"
    "-p"
    "figcraft-cli"
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
    install -Dm644 packaging/linux/ai.storyteller.figcraft.desktop \
      $out/share/applications/ai.storyteller.figcraft.desktop
    for size in 16 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.figcraft.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.figcraft.png
    done
  '';

  meta = {
    description = "Open-source, native interface design and prototyping tool";
    homepage = "https://github.com/storytold/figcraft";
    changelog = "https://github.com/storytold/figcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "figcraft";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
