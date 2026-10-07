{
  lib,
  stdenv,
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
  pname = "vectorcraft-bin";
  version = "0.4.0";

  src = fetchurl {
    url = "https://github.com/storytold/vectorcraft/releases/download/v${finalAttrs.version}/vectorcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-tzGe41TADt0Nv3ePlea0kMjec77+VnIBToEGV8EdZwc=";
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
    description = "Open-source, native vector illustration app (prebuilt binary)";
    homepage = "https://github.com/storytold/vectorcraft";
    changelog = "https://github.com/storytold/vectorcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "vectorcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
