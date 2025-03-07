{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook,
  dbus,
  electron,
  gtk3,
  atkmm,
  ell,
  ffmpeg,
  gtkmm3,
  libgbm,
  libgcc,
  libsecret,
  libpcap,
  libyaml,
  file,
  nss,
  pango,
  sqlite,
  xorg,
  mesa,
  libGL,
  libdrm,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  libpulseaudio,
  cups,
  xdg-utils,
  xdg-desktop-portal,
  xdg-desktop-portal-gtk,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "zui";
  version = "1.18.0";

  src = fetchurl {
    url = "https://github.com/brimdata/zui/releases/download/v${finalAttrs.version}/zui_${finalAttrs.version}_amd64.deb";
    hash = "sha256-7MK+bHSGidipAZhmD6IBwr+DBuVnBMwhZTP5Qw6wHCU=";
  };

  unpackCmd = "dpkg -x $curSrc source";

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook
  ];

  buildInputs = [
    gtk3
    atkmm
    ell
    ffmpeg.lib
    gtkmm3
    libgbm
    libgcc
    libsecret
    nss
    pango
    sqlite
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXrandr
    xorg.libXtst
    xorg.libxshmfence
    mesa
    libGL
    libdrm
    libpcap
    libyaml
    file
    alsa-lib
    at-spi2-atk
    at-spi2-core
    libpulseaudio
    cups.lib
    dbus
  ];

  runtimeDependencies = [
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-utils
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/applications,share/icons,opt}
    cp -r usr/share/applications/* $out/share/applications/
    cp -r usr/share/icons/* $out/share/icons/
    cp -r opt/Zui $out/opt/

    # Remove bundled libraries that might conflict
    rm -f $out/opt/Zui/resources/app.asar.unpacked/zdeps/suricata/bin/libnss*.so*
    rm -f $out/opt/Zui/resources/app.asar.unpacked/zdeps/suricata/bin/libssl*.so*
    rm -f $out/opt/Zui/resources/app.asar.unpacked/zdeps/suricata/bin/libsoftokn*.so*

    # Fix desktop file
    substituteInPlace $out/share/applications/zui.desktop \
      --replace "/opt/Zui/zui" "$out/bin/zui"

    # Set executable permissions on bundled binaries
    if [ -d $out/opt/Zui/resources/app.asar.unpacked/zdeps/brimcap ]; then
      find $out/opt/Zui/resources/app.asar.unpacked/zdeps/brimcap/bin -type f -exec chmod +x {} \;
    fi
    if [ -d $out/opt/Zui/resources/app.asar.unpacked/zdeps/suricata ]; then
      find $out/opt/Zui/resources/app.asar.unpacked/zdeps/suricata/bin -type f -exec chmod +x {} \;
    fi

    # Create plugin directory structure
    mkdir -p $out/opt/Zui/resources/app.asar.unpacked/zdeps/plugins

    runHook postInstall
  '';

  postFixup = ''
    # Create a more robustly wrapped executable
    makeWrapper ${electron}/bin/electron $out/bin/zui \
      --add-flags "$out/opt/Zui/resources/app.asar" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.buildInputs}" \
      --prefix PATH : "${lib.makeBinPath finalAttrs.runtimeDependencies}" \
      --prefix PATH : "$out/opt/Zui/resources/app.asar.unpacked/zdeps/brimcap/bin:$out/opt/Zui/resources/app.asar.unpacked/zdeps/suricata/bin" \
      --prefix XDG_DATA_DIRS : "$XDG_DATA_DIRS:$out/share" \
      --set ELECTRON_IS_DEV 0 \
      --set ELECTRON_TRASH "xdg-open" \
      --set ELECTRON_OZONE_PLATFORM_HINT "auto" \
      --set ZUI_PLUGIN_ROOT "$out/opt/Zui/resources/app.asar.unpacked/zdeps/plugins" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=UseOzonePlatform,WaylandWindowDecorations" \
      --add-flags "--no-sandbox"

    # Patch bundled binaries to use system libraries
    if [ -d $out/opt/Zui/resources/app.asar.unpacked/zdeps/brimcap ]; then
      find $out/opt/Zui/resources/app.asar.unpacked/zdeps/brimcap/bin -type f -executable -exec \
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                 --set-rpath "${lib.makeLibraryPath finalAttrs.buildInputs}" {} \; || true
    fi
    if [ -d $out/opt/Zui/resources/app.asar.unpacked/zdeps/suricata ]; then
      find $out/opt/Zui/resources/app.asar.unpacked/zdeps/suricata/bin -type f -executable -exec \
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                 --set-rpath "${lib.makeLibraryPath finalAttrs.buildInputs}" {} \; || true
    fi
  '';

  meta = {
    description = "Zui (formerly Brim) is a GUI for exploring data in Zed lakes.";
    homepage = "https://zui.brimdata.io/";
    license = with lib.licenses; [bsd3];
    maintainers = with lib.maintainers; ["74k1"];
    platforms = ["x86_64-linux"];
    mainProgram = "zui";
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
})
