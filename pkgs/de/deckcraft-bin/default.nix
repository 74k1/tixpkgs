{
  lib,
  stdenv,
  dbus,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  alsa-lib,
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
  pname = "deckcraft-bin";
  version = "0.4.0";

  src = fetchurl {
    url = "https://github.com/storytold/deckcraft/releases/download/v${finalAttrs.version}/deckcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-VEBHlMD/Yko8NoiFX1SrQ7pf4Y0T01K5j+9DcLdcYeM=";
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
    alsa-lib
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
    description = "Presentations and slide shows, a clean-room reimplementation of Microsoft PowerPoint in pure Rust (prebuilt binary)";
    homepage = "https://github.com/storytold/deckcraft";
    changelog = "https://github.com/storytold/deckcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "deckcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
