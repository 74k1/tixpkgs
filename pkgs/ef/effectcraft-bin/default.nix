{
  lib,
  stdenv,
  dbus,
  fetchurl,
  dpkg,
  alsa-lib,
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
  pname = "effectcraft-bin";
  version = "0.7.0";

  src = fetchurl {
    url = "https://github.com/storytold/effectcraft/releases/download/v${finalAttrs.version}/effectcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-GWIsdRBG3yHL7NzcJZYleheV0E05SxZQCeFp+WoTpOI=";
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
    dbus.lib
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
    description = "Open-source, native motion graphics and visual effects app (prebuilt binary)";
    homepage = "https://github.com/storytold/effectcraft";
    changelog = "https://github.com/storytold/effectcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "effectcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
