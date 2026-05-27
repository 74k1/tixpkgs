{
  lib,
  stdenv,
  fetchurl,
  coreutils,
  autoPatchelfHook,
  makeWrapper,
  qt5,
  alsa-lib,
  cups,
  libusb-compat-0_1,
  libusb1,
  libxml2_13,
  pcsclite,
  zlib,
  libX11,
  libXinerama,
  libXpm,
  libXtst,
  xdg-utils,
  xwayland-satellite,
  withQtWebEngine ? false,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "parallels-ras-client";
  version = "21.1.26543";

  src = fetchurl {
    url = "https://download.parallels.com/ras/v21/21.1.0.26543/RASClient-${finalAttrs.version}_x86_64.tar.bz2";
    hash = "sha256-JEg4CeYTJhhD/r+r77rW4agzM5NRJkcVYGzovGuEsDA=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    qt5.wrapQtAppsHook
  ];

  buildInputs = [
    alsa-lib
    cups.lib
    libusb-compat-0_1
    libusb1
    libxml2_13
    pcsclite
    qt5.qtbase
    qt5.qtmultimedia
    qt5.qtx11extras
    zlib
    libX11
    libXinerama
    libXpm
    libXtst
    stdenv.cc.cc.lib
  ] ++ lib.optionals withQtWebEngine [
    qt5.qtwebengine
  ];

  runtimeDependencies = [
    xdg-utils
    xwayland-satellite
  ];

  dontConfigure = true;
  dontBuild = true;
  dontWrapQtApps = true;

  # appserverclient dynamically loads libusb-1.0 for USB redirection and
  # libmtp-prl.so links to libusb-0.1 via libusb-compat for MTP/PTP.
  # Keep both in the wrapper's library path even though libusb-1.0 is not
  # visible to autoPatchelf as a DT_NEEDED dependency.

  # Only libwebview.so links to QtWebEngine. Qt 5 WebEngine is marked
  # insecure in nixpkgs, so keep the rest of the client usable without
  # forcing consumers to allow it. Override withQtWebEngine = true if you
  # need embedded web views and have permitted qtwebengine-5.15.x.
  autoPatchelfIgnoreMissingDeps = lib.optionals (!withQtWebEngine) [
    "libQt5WebEngineCore.so.5"
    "libQt5WebEngineWidgets.so.5"
  ];

  unpackPhase = ''
    runHook preUnpack
    tar -xjf $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/2X $out/bin $out/share/applications $out/share/mime/packages $out/share/pixmaps
    cp -r opt/2X/Client $out/opt/2X/
    chmod -R u+w $out/opt/2X/Client

    install -Dm444 opt/2X/Client/share/2X.png $out/share/pixmaps/2X.png
    install -Dm444 opt/2X/Client/share/sharedmimeinfo/2XClient.xml $out/share/mime/packages/2XClient.xml

    install -Dm444 opt/2X/Client/share/rasclient.desktop $out/share/applications/rasclient.desktop
    install -Dm444 opt/2X/Client/share/rassession.desktop $out/share/applications/rassession.desktop
    install -Dm444 opt/2X/Client/share/tuxclient.desktop $out/share/applications/tuxclient.desktop

    substituteInPlace $out/share/applications/rasclient.desktop \
      --replace-fail 'Exec=/opt/2X/Client/bin/2XClient' 'Exec=2XClient' \
      --replace-fail 'Icon=/usr/share/pixmaps/2X.png' 'Icon=2X'
    substituteInPlace $out/share/applications/rassession.desktop \
      --replace-fail 'Exec=/opt/2X/Client/bin/appserverclient -i %f' 'Exec=appserverclient -i %f' \
      --replace-fail 'Icon=/usr/share/pixmaps/2X.png' 'Icon=2X'
    substituteInPlace $out/share/applications/tuxclient.desktop \
      --replace-fail 'Exec=/opt/2X/Client/bin/appserverclient "%u"' 'Exec=appserverclient "%u"' \
      --replace-fail 'Icon=/usr/share/pixmaps/2X.png' 'Icon=2X'

    runHook postInstall
  '';

  postFixup = ''
    wrapClientEnv() {
      local source="$1"
      local wrapper="$2"
      shift 2

      makeWrapper "$source" "$wrapper" \
        "''${qtWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "$out/opt/2X/Client/lib:${lib.makeLibraryPath finalAttrs.buildInputs}" \
        --prefix PATH : "${lib.makeBinPath finalAttrs.runtimeDependencies}" \
        --set-default SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
        "$@"
    }

    wrapClientInPlace() {
      local binary="$1"
      local target="$out/opt/2X/Client/bin/$binary"
      local unwrapped="$out/opt/2X/Client/bin/.$binary-unwrapped"

      mv "$target" "$unwrapped"
      wrapClientEnv "$unwrapped" "$target"
    }

    wrapAppserverclient() {
      local target="$out/opt/2X/Client/bin/appserverclient"
      local unwrapped="$out/opt/2X/Client/bin/.appserverclient-unwrapped"
      local envWrapper="$out/opt/2X/Client/bin/.appserverclient-env"

      mv "$target" "$unwrapped"
      wrapClientEnv "$unwrapped" "$envWrapper" \
        --set QT_QPA_PLATFORM xcb

      cat > "$target" <<'EOF'
#!@shell@
xwayland_pid=""
if [ -z "''${DISPLAY:-}" ] && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
  for display in {100..199}; do
    if [ ! -e "/tmp/.X11-unix/X$display" ]; then
      @xwaylandSatellite@ ":$display" >/dev/null 2>&1 &
      xwayland_pid=$!

      for attempt in {1..50}; do
        if [ -S "/tmp/.X11-unix/X$display" ]; then
          export DISPLAY=":$display"
          break 2
        fi
        if ! kill -0 "$xwayland_pid" 2>/dev/null; then
          break
        fi
        @sleep@ 0.1
      done

      if [ -z "''${DISPLAY:-}" ]; then
        kill "$xwayland_pid" 2>/dev/null || true
        xwayland_pid=""
      fi
    fi
  done
fi

if [ -n "$xwayland_pid" ]; then
  "@envWrapper@" "$@"
  status=$?
  kill "$xwayland_pid" 2>/dev/null || true
  exit "$status"
fi

exec "@envWrapper@" "$@"
EOF
      substituteInPlace "$target" \
        --replace-fail '@shell@' '${stdenv.shell}' \
        --replace-fail '@xwaylandSatellite@' '${lib.getExe xwayland-satellite}' \
        --replace-fail '@sleep@' '${lib.getExe' coreutils "sleep"}' \
        --replace-fail '@envWrapper@' "$envWrapper"
      chmod +x "$target"
    }

    # 2XClient launches appserverclient via ../bin/appserverclient, bypassing
    # $out/bin/appserverclient. Wrap the vendor binaries in-place so child
    # sessions get the same library/plugin environment as the top-level entry.
    wrapClientInPlace 2XClient
    wrapAppserverclient
    wrapClientInPlace downloader

    ln -s $out/opt/2X/Client/bin/2XClient $out/bin/2XClient
    ln -s $out/opt/2X/Client/bin/appserverclient $out/bin/appserverclient
    ln -s $out/opt/2X/Client/bin/downloader $out/bin/2XClient-downloader
    ln -s 2XClient $out/bin/parallels-ras-client
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Client for Parallels Remote Application Server";
    homepage = "https://www.parallels.com/products/ras/download/client/";
    downloadPage = "https://www.parallels.com/products/ras/download/client/";
    changelog = "https://kb.parallels.com/en/131037";
    license = lib.licenses.unfree;
    maintainers = [ "74k1" ];
    mainProgram = "2XClient";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
