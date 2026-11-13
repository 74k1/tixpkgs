{
  lib,
  stdenv,
  fetchurl,
  _7zz,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  makeWrapper,
  bubblewrap,
  jack2,
  pipewire,
  vulkan-loader,
  wayland,
  libxkbcommon,
  libpng,
  freetype,
  libx11,
  lilv,
  zstd,
  ncurses,
}:

stdenv.mkDerivation rec {
  pname = "septabee";
  version = "B_T28";

  src = fetchurl {
    url = "https://downloads.septabee.com/SEPTABEE_DOWNLOADS/septabee_linux_${version}_offline.7z";
    hash = "sha256-J6oXQhoQkCs4UbrdWhiRjbO+PCDLdcLKmKVZ7fHuWHk=";
  };

  nativeBuildInputs = [
    _7zz
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
  ];

  # The executable contains an appended application payload.
  dontStrip = true;

  buildInputs = [ stdenv.cc.cc.lib ];

  runtimeDependencies = [
    libpng
    freetype
    libx11
    lilv
    zstd
    ncurses
    jack2
    pipewire
    vulkan-loader
    wayland
    libxkbcommon
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "septabee";
      desktopName = "Septabee";
      genericName = "Digital Audio Workstation";
      exec = "septabee";
      categories = [
        "AudioVideo"
        "Audio"
        "Music"
        "Midi"
      ];
    })
  ];

  unpackPhase = ''
    runHook preUnpack
    7zz x "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/libexec/septabee"
    cp -r linux/* "$out/libexec/septabee/"
    chmod +x "$out/libexec/septabee/septabee"
    runHook postInstall
  '';

  postFixup = ''
    makeWrapper ${bubblewrap}/bin/bwrap "$out/bin/septabee" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath (runtimeDependencies ++ [ stdenv.cc.cc.lib ])
      }" \
      --add-flags "--dev-bind / / --tmpfs /lib64 --ro-bind ${stdenv.cc.bintools.dynamicLinker} /lib64/ld-linux-x86-64.so.2 $out/libexec/septabee/septabee"
  '';

  meta = {
    description = "Digital audio workstation";
    homepage = "https://septabee.nekoweb.org/";
    license = lib.licenses.unfree;
    mainProgram = "septabee";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = with lib.maintainers; [ _74k1 ];
  };
}
