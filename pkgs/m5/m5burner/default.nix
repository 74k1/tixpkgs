{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, copyDesktopItems
, makeDesktopItem
, unzip
, buildFHSEnv
, writeShellScript
, alsa-lib
, atk
, cairo
, cups
, dbus
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, libdrm
, libpulseaudio
, libxcb
, libxkbcommon
, mesa
, nspr
, nss
, pango
, systemd
, libx11
, libxcomposite
, libxdamage
, libxext
, libxfixes
, libxrandr
, libxshmfence
, libGL
, libusb1
, python3
, zlib
}:

let
  pname = "m5burner";
  version = "3-beta";

  src = fetchurl {
    url = "https://m5burner-cdn.m5stack.com/app/M5Burner-v${version}-linux-x64.zip";
    hash = "sha256-oGLbbav6HiR/k0CLCgoBghe/1ohzO4z2WJCI9OMXYcU=";
    curlOpts = "--referer https://m5burner-cdn.m5stack.com/";
  };

  deps = [
    alsa-lib
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libGL
    libpulseaudio
    libusb1
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxshmfence
    zlib
  ];

  unwrapped = stdenv.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version src;

    nativeBuildInputs = [
      autoPatchelfHook
      unzip
    ];

    buildInputs = deps;

    unpackPhase = ''
      runHook preUnpack
      mkdir -p source
      cd source
      ${unzip}/bin/unzip $src
      runHook postUnpack
    '';

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/m5burner $out/share/icons/hicolor/256x256/apps
      cp -r bin $out/share/m5burner/
      cp -r packages $out/share/m5burner/
      chmod u+w $out/share/m5burner/bin/chrome-sandbox
      cp packages/view/assets/images/logo.png $out/share/icons/hicolor/256x256/apps/m5burner.png
      for tool in $out/share/m5burner/packages/tool/esptool $out/share/m5burner/packages/tool/nvs; do
        if [ -f "$tool" ]; then autoPatchelf "$tool"; fi
      done
      for node in $out/share/m5burner/bin/resources/app.asar.unpacked/node_modules/*/build/Release/*.node; do
        autoPatchelf "$node"
      done
      runHook postInstall
    '';

    meta = with lib; {
      description = "M5Stack firmware burning tool (unwrapped)";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

  launcher = writeShellScript "m5burner-launcher" ''
    DATA_DIR="''${XDG_DATA_HOME:-''$HOME/.local/share}/m5burner"
    if [ ! -d "''$DATA_DIR/bin" ]; then
      mkdir -p "''$DATA_DIR"
      cp -r ${unwrapped}/share/m5burner/. "''$DATA_DIR/"
      chmod -R u+w "''$DATA_DIR"
      chmod u+w "''$DATA_DIR/bin/chrome-sandbox"
    fi
    cd "''$DATA_DIR/bin"
    exec ./m5burner --no-sandbox "''$@"
  '';

  desktopItem = makeDesktopItem {
    name = pname;
    exec = pname;
    icon = pname;
    desktopName = "M5Burner";
    comment = "M5Stack firmware burning tool";
    categories = [ "Development" "Utility" ];
    terminal = false;
    startupWMClass = "M5Burner";
  };
in
buildFHSEnv {
  name = pname;

  runScript = "${launcher}";

  targetPkgs = pkgs: deps ++ [ pkgs.python3 ];

  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/icons/hicolor/256x256/apps
    cp ${desktopItem}/share/applications/* $out/share/applications/
    ln -s ${unwrapped}/share/icons/hicolor/256x256/apps/m5burner.png \
      $out/share/icons/hicolor/256x256/apps/m5burner.png
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "M5Stack firmware burning tool";
    longDescription = ''
      M5Burner is a firmware burning tool for M5Stack devices.
      It provides an easy way to flash firmware to M5Stack
      development boards and modules.

      To access serial ports without root, add your user to the
      dialout group:
        sudo usermod -a -G dialout $USER
      Then log out and back in.
    '';
    homepage = "https://m5stack.com";
    downloadPage = "https://docs.m5stack.com/en/download";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ "74k1" ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
