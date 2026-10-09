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
  pname = "soundcraft-bin";
  version = "0.3.0";

  src = fetchurl {
    url = "https://github.com/storytold/soundcraft/releases/download/v${finalAttrs.version}/soundcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-3hu/xLwUG1swXcEm7LjvS2jjf3z+v+kVX5byH5TE/uE=";
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
    description = "Open-source, clean-room reimplementation of Avid Pro Tools in pure Rust (prebuilt binary)";
    homepage = "https://github.com/storytold/soundcraft";
    changelog = "https://github.com/storytold/soundcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "soundcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
