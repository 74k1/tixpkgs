{
  lib,
  stdenv,
  curl,
  cacert,
  autoPatchelfHook,
  makeWrapper,
  gtk4,
  pango,
  gdk-pixbuf,
  cairo,
  vulkan-loader,
  glib,
  libpng,
  fontconfig,
  lcms2,
  librsvg,
  zlib,
  cups,
  libepoxy,
  nettle,
  acl,
  xz,
  lz4,
  bzip2,
  icu74,
  sqlite,
  libpsl,
  libkrb5,
  nghttp2,
  lerc,
  jbigkit,
  libdeflate,
  glib-networking,
  hicolor-icon-theme,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fogpanther";
  version = "0.8.0";

  src = stdenv.mkDerivation {
    name = "fogpanther-${finalAttrs.version}.tar.xz";
    nativeBuildInputs = [
      curl
      cacert
    ];

    outputHash = "sha256-WXjRDBxL4O0esgW3QB5x9Hb/d95qo/QcH/Lrb9yNtjo=";
    outputHashAlgo = "sha256";
    outputHashMode = "flat";

    buildCommand = /* sh */ ''
      page=$(curl -sS -L "https://fogpanther.com/download")
      token=$(echo "$page" | sed -n 's/.*data-download-token-token-value="\([^"]*\)".*/\1/p' | head -1 | sed 's/=/%3D/g')
      url="https://fogpanther.com/releases/latest/tarball?arch=x86_64&token=$token"
      curl -sS -L -o "$out" "$url"
    '';
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    gtk4
    pango
    gdk-pixbuf
    cairo
    vulkan-loader
    glib
    libpng
    fontconfig
    lcms2
    librsvg
    zlib
    cups
    libepoxy
    nettle
    acl
    xz
    lz4
    bzip2
    icu74
    sqlite
    libpsl
    libkrb5
    nghttp2
    lerc
    jbigkit
    libdeflate
    glib-networking
    hicolor-icon-theme
    stdenv.cc.cc.lib
  ];

  appendRunpaths = [ "$out/opt/fogpanther/lib" ];

  dontConfigure = true;

  gav1Stub = builtins.toFile "gav1-stub.c" ''
    #include <stddef.h>
    #include <stdint.h>
    typedef enum { kGav1StatusOk = 0, kGav1StatusInvalidArgument = -1, kGav1StatusUnimplemented = -2 } Libgav1StatusCode;
    typedef void* Libgav1Decoder;
    typedef struct { int dummy; } Libgav1DecoderSettings;
    __attribute__((visibility("default")))
    Libgav1StatusCode Libgav1DecoderCreate(const Libgav1DecoderSettings* s, void* b, int n, Libgav1Decoder* d) { return kGav1StatusInvalidArgument; }
    __attribute__((visibility("default")))
    const char* Libgav1GetVersion(void) { return "0.18.0"; }
    __attribute__((visibility("default")))
    int Libgav1GetVersionString(char* buf, int len) { return 0; }
    __attribute__((visibility("default")))
    const char* Libgav1GetBuildConfiguration(void) { return "stub"; }
    __attribute__((visibility("default")))
    int Libgav1DecoderSettingsInitDefault(Libgav1DecoderSettings* s) { return 0; }
    __attribute__((visibility("default")))
    Libgav1StatusCode Libgav1SetFrameBuffer(Libgav1Decoder d, void* buf, int w, int h, int s, int b) { return kGav1StatusInvalidArgument; }
    __attribute__((visibility("default")))
    int Libgav1ComputeFrameBufferInfo(Libgav1Decoder d, int w, int h, int* info) { return 0; }
    __attribute__((visibility("default")))
    Libgav1StatusCode Libgav1DecoderEnqueueFrame(Libgav1Decoder d, const uint8_t* data, size_t size, int64_t ts, void* ctx) { return kGav1StatusInvalidArgument; }
    __attribute__((visibility("default")))
    Libgav1StatusCode Libgav1DecoderDequeueFrame(Libgav1Decoder d, void* buf, int* w, int* h, int* s, int* b, void* ctx) { return kGav1StatusInvalidArgument; }
    __attribute__((visibility("default")))
    Libgav1StatusCode Libgav1DecoderSignalEOS(Libgav1Decoder d) { return kGav1StatusInvalidArgument; }
    __attribute__((visibility("default")))
    void Libgav1DecoderDestroy(Libgav1Decoder d) {}
    __attribute__((visibility("default")))
    int Libgav1DecoderGetMaxBitdepth(void) { return 10; }
    __attribute__((visibility("default")))
    const char* Libgav1GetErrorString(int status) { return "stub"; }
  '';

  buildPhase = ''
    runHook preBuild
    $CC -shared -fPIC -Wl,-soname,libgav1.so.1 -o libgav1.so.1 ${finalAttrs.gav1Stub}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,opt/fogpanther/bin,share}
    cp -r . $out/opt/fogpanther

    rm -f $out/opt/fogpanther/lib/libgav1.so.1 $out/opt/fogpanther/libgav1.so.1
    cp libgav1.so.1 $out/opt/fogpanther/lib/libgav1.so.1

    cp -r share/applications $out/share/
    cp -r share/icons $out/share/
    cp -r share/metainfo $out/share/
    cp -r share/mime $out/share/
    cp -r share/fogpanther $out/share/
    cp -r share/licenses $out/share/
    cp -r share/thumbnailers $out/share/

    substituteInPlace $out/share/applications/com.fogpanther.FogPanther.desktop \
      --replace-fail "Exec=fogpanther" "Exec=$out/bin/fogpanther"
    runHook postInstall
  '';

  postInstall = ''
    makeWrapper $out/opt/fogpanther/bin/fogpanther $out/bin/fogpanther \
      --prefix LD_LIBRARY_PATH : "$out/opt/fogpanther/lib" \
      --prefix XDG_DATA_DIRS : "$out/share" \
      --set GIO_EXTRA_MODULES "${glib-networking}/lib/gio/modules" \
      --set GDK_PIXBUF_MODULE_FILE "$out/opt/fogpanther/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"

    cp ${hicolor-icon-theme}/share/icons/hicolor/index.theme $out/share/icons/hicolor/
  '';

  postFixup = ''
    LD_LIBRARY_PATH=${lib.makeLibraryPath finalAttrs.buildInputs}:$out/opt/fogpanther/lib \
    ${gdk-pixbuf.dev}/bin/gdk-pixbuf-query-loaders \
      ${gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.so \
      $out/opt/fogpanther/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.so \
      > $out/opt/fogpanther/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "Professional raster graphics editor for digital art and photo editing";
    homepage = "https://www.fogpanther.com";
    license = licenses.unfree;
    mainProgram = "fogpanther";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ _74k1 ];
  };
})
