{
  lib,
  stdenv,
  dbus,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrandr,
  vulkan-loader,
  wayland,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "craft-anything-bin";
  version = "0.3.0";

  src = fetchurl {
    url = "https://github.com/storytold/craft-anything/releases/download/v${finalAttrs.version}/craft-anything-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-sDNLYQXpNqnVq7eG/046hmGuApj001ZOCfFme9mEhw0=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  buildInputs = [
    libxkbcommon
    vulkan-loader
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
    libxcb
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;

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

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r usr/bin usr/share $out/
    chmod -R u+w $out
    runHook postInstall
  '';

  meta = {
    description = "See how any software works, then craft your own (prebuilt binary)";
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
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "craft-anything";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
