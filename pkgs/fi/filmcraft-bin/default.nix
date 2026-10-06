{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  alsa-lib,
  autoPatchelfHook,
  libxkbcommon,
  vulkan-loader,
  wayland,
  xorg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "filmcraft-bin";
  version = "0.2.1";

  src = fetchurl {
    url = "https://github.com/storytold/filmcraft/releases/download/v${finalAttrs.version}/filmcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-sghuom7m6jBHQgacr5jDG9cSPCJuQaylB7dSGe0Wdq8=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  buildInputs = [
    alsa-lib
    libxkbcommon
    vulkan-loader
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    xorg.libxcb
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;

  runtimeDependencies = [
    libxkbcommon
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
    description = "Open-source, native video editor with color and sound (prebuilt binary)";
    homepage = "https://github.com/storytold/filmcraft";
    changelog = "https://github.com/storytold/filmcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "filmcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
