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
  pname = "pdfcraft-bin";
  version = "0.5.0";

  src = fetchurl {
    url = "https://github.com/storytold/pdfcraft/releases/download/v${finalAttrs.version}/pdfcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-e4QHhLaqrkdKTK5Qb2O7OSBJs1nn3jpMdY+YQCsJW18=";
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
    description = "Open-source, native PDF reader, organizer and protector (prebuilt binary)";
    homepage = "https://github.com/storytold/pdfcraft";
    changelog = "https://github.com/storytold/pdfcraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "pdfcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
