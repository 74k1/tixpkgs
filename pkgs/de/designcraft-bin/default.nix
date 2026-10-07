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
  pname = "designcraft-bin";
  version = "0.2.1";

  src = fetchurl {
    url = "https://github.com/storytold/designcraft/releases/download/v${finalAttrs.version}/designcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-l1DArDuVIFuaCmMeudNRcxKW1pNRe4fbllHOQahc7gQ=";
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
    description = "Open-source, native page layout and publishing app (prebuilt binary)";
    homepage = "https://github.com/storytold/designcraft";
    changelog = "https://github.com/storytold/designcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "designcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
