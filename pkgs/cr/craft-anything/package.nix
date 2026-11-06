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
  pname = "craft-anything";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "craft-anything";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4SpbjOMX40TC5Vq/HDjOuNAzfW97AoZ33zHJzxBHkVQ=";
  };

  buildInputs = [
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    libxrandr
    vulkan-loader
    wayland
    stdenv.cc.cc.lib
  ];

  nativeBuildInputs = [ autoPatchelfHook ];

  # NixOS cannot run the pinned prebuilt downloads: Temurin, Ghidra and the
  # Android platform-tools are generic-Linux ELFs. The engine lookup already
  # searches PATH, so say so in the messages people read.
  postPatch = ''
    substituteInPlace crates/engine/src/tools/external_disasm_tools.rs \
      --replace-fail 'Install {} and set its path in Settings → Engines.' \
      'Install {} and set its path in Settings → Engines, or put it on your PATH. On NixOS, install it with nix shell nixpkgs#<package>.'
    substituteInPlace crates/engines/src/ghidra/protocol.rs \
      --replace-fail 'Check the Ghidra install and JDK in Settings → Engines.' \
      'Check the Ghidra install and JDK in Settings → Engines. On NixOS, use the nixpkgs ghidra and JDK: the pinned downloads cannot run there.'
    substituteInPlace crates/engines/src/install.rs \
      --replace-fail 'Install it by hand and set its path in Settings → Engines.' \
      'Install it with your package manager and set its path in Settings → Engines. On NixOS, install it with nix shell nixpkgs#<package>.'
    substituteInPlace crates/engine/src/lib.rs \
      --replace-fail 'Install {} from Settings → Engines.' \
      'Install {} from Settings → Engines, or put it on your PATH.'
    substituteInPlace crates/engines/src/table.rs \
      --replace-fail 'Set up Ghidra from Settings → Engines (Deep mode); it brings its own Java.' \
      'Set up Ghidra from Settings → Engines (Deep mode); it brings its own Java. On NixOS, use the nixpkgs ghidra and JDK instead.'
  '';

  cargoHash = "sha256-VC2ANtZRISPetfvAQei4/OF6tNop/rSEYK59iogSlDQ=";

  # The workspace also holds the wasm browser app and the CLI; build only the
  # desktop app.
  cargoBuildFlags = [
    "-p"
    "craft-anything"
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
    install -Dm644 packaging/linux/ai.storyteller.craft-anything.desktop \
      $out/share/applications/ai.storyteller.craft-anything.desktop
    install -Dm644 \
      assets/app-icon/hicolor/scalable/apps/ai.storyteller.craft-anything.svg \
      $out/share/icons/hicolor/scalable/apps/ai.storyteller.craft-anything.svg
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 \
        assets/app-icon/hicolor/$size\x$size/apps/ai.storyteller.craft-anything.png \
        $out/share/icons/hicolor/$size\x$size/apps/ai.storyteller.craft-anything.png
    done
  '';

  meta = {
    description = "See how any software works, then craft your own";
    longDescription = ''
      Evidence-backed answers about programs, apps, files, websites and phones
      (executables, archives, web bundles, Android packages, WebAssembly), from
      a native desktop app, a CLI and an MCP server.
    '';
    homepage = "https://github.com/storytold/craft-anything";
    changelog = "https://github.com/storytold/craft-anything/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "craft-anything";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
