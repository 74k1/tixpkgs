{
  stdenv,
  lib,
  fetchFromGitHub,
  qt6,
  pkg-config,
  vulkan-headers,
  SDL2,
  SDL2_ttf,
  ffmpeg,
  libopus,
  libplacebo,
  openssl,
  alsa-lib,
  libpulseaudio,
  libva,
  libvdpau,
  libxkbcommon,
  wayland,
  libdrm,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "moonlight-qt-fork";
  version = "6.21.46";

  src = fetchFromGitHub {
    owner = "qiin2333";
    repo = "moonlight-qt";
    rev = "6856b26b30f1fdd46f88ed08eda50522ec91060f";
    hash = "sha256-v3ZBOWRo82FXBoGs2dgAhzE1ugXEJzig7akRJ39As3Q=";
    fetchSubmodules = true;
  };

  patches = [
    ./fix-async-loader.patch
  ];

  nativeBuildInputs = [
    qt6.qmake
    qt6.wrapQtAppsHook
    pkg-config
    vulkan-headers
  ];

  buildInputs = [
    SDL2
    SDL2_ttf
    ffmpeg
    libopus
    libplacebo
    qt6.qtdeclarative
    qt6.qtimageformats
    qt6.qtmultimedia
    qt6.qtsvg
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    alsa-lib
    libpulseaudio
    libva
    libvdpau
    libxkbcommon
    qt6.qtwayland
    wayland
    libdrm
  ];

  qmakeFlags = [ "CONFIG+=disable-prebuilts" ];

  postInstall = lib.optionalString stdenv.hostPlatform.isDarwin ''
    mkdir $out/Applications $out/bin
    mv app/Moonlight.app $out/Applications
    ln -s $out/Applications/Moonlight.app/Contents/MacOS/Moonlight $out/bin/moonlight
  '';

  meta = {
    description = "GameStream client for PCs (qiin2333 fork with enhanced streaming features)";
    homepage = "https://github.com/qiin2333/moonlight-qt";
    license = lib.licenses.gpl3Plus;
    maintainers = [ "74k1" ];
    platforms = lib.platforms.all;
    mainProgram = "moonlight";
  };
})
