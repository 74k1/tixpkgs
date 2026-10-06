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
  pname = "printcraft-bin";
  version = "0.2.1";

  src = fetchurl {
    url = "https://github.com/storytold/printcraft/releases/download/v${finalAttrs.version}/printcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-dKRVdPD1+qVSpXYYyZulHugYrcZe0yu0KbGV7CYM0eY=";
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
    description = "Open-source, native PDF reader, organizer and protector (prebuilt binary)";
    homepage = "https://github.com/storytold/printcraft";
    changelog = "https://github.com/storytold/printcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "printcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
