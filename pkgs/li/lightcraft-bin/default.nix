{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  libxkbcommon,
  vulkan-loader,
  wayland,
  xorg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lightcraft-bin";
  version = "0.2.1";

  src = fetchurl {
    url = "https://github.com/storytold/lightcraft/releases/download/v${finalAttrs.version}/lightcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-UVFayvG9bmZ9Hhg0cKfZS+lwgYHaNdekiU0TSzVgGfc=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  buildInputs = [
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
    description = "Open-source, native photo library and raw developer (prebuilt binary)";
    homepage = "https://github.com/storytold/lightcraft";
    changelog = "https://github.com/storytold/lightcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "lightcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
