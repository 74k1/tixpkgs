{
  lib,
  stdenv,
  fetchFromGitHub,
  autoPatchelfHook,
  autoAddDriverRunpath,
  makeWrapper,
  buildNpmPackage,
  cmake,
  avahi,
  libevdev,
  libpulseaudio,
  libxtst,
  libxrandr,
  libxi,
  libxfixes,
  libxdmcp,
  libx11,
  libxcb,
  openssl,
  libopus,
  boost,
  pkg-config,
  libdrm,
  wayland,
  wayland-scanner,
  libffi,
  libcap,
  libgbm,
  curl,
  pcre2,
  python3,
  libuuid,
  libselinux,
  libsepol,
  libthai,
  libdatrie,
  libxkbcommon,
  libepoxy,
  libva,
  libvdpau,
  libglvnd,
  numactl,
  amf-headers,
  svt-av1,
  vulkan-loader,
  libappindicator,
  libnotify,
  miniupnpc,
  nlohmann_json,
  config,
  cudaSupport ? config.cudaSupport,
  cudaPackages ? { },
  apple-sdk_15,
}:
let
  inherit (stdenv.hostPlatform) isLinux isDarwin;
  stdenv' = if cudaSupport then cudaPackages.backendStdenv else stdenv;
in
stdenv'.mkDerivation (finalAttrs: {
  pname = "foundation-sunshine";
  version = "2026.615.115523";

  src = fetchFromGitHub {
    owner = "AlkaidLab";
    repo = "foundation-sunshine";
    # latest master as of 2026-06-15
    rev = "d826c93e11cfa14d8dfdcaef9cb15140050aab08";
    hash = "sha256-1/dG+PtxU+jcBR5S4cH8mhDC4iQ93Xen8/JytAFAj2I=";
    fetchSubmodules = true;
  };

  # build webui
  ui = buildNpmPackage {
    inherit (finalAttrs) src version;
    pname = "foundation-sunshine-ui";
    npmDepsHash = "sha256-EKEKa2jok6r1ryn31uzE2o4UNBvoAETYBEr/7u+DI9c=";

    # use generated package-lock.json as upstream does not provide one
    postPatch = ''
      cp ${./package-lock.json} ./package-lock.json
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -a . "$out"/

      runHook postInstall
    '';
  };

  postPatch =
    # don't look for npm since we build webui separately
    ''
      substituteInPlace cmake/targets/common.cmake \
        --replace-fail 'find_program(NPM npm REQUIRED)' 'message(STATUS "npm not needed, webui built separately")'
    ''
    # fix tray source file extension mismatch
    + ''
      substituteInPlace cmake/compile_definitions/linux.cmake \
        --replace-fail 'tray_linux.c' 'tray_linux.cpp'
    ''
    # add missing AMF encoder constants for non-Windows builds
    + ''
      sed -i '/#define AMF_VIDEO_ENCODER_CALV 2/a\
      #define AMF_VIDEO_ENCODER_AV1_RATE_CONTROL_METHOD_QUALITY_VBR 4\
      #define AMF_VIDEO_ENCODER_AV1_RATE_CONTROL_METHOD_HIGH_QUALITY_VBR 5\
      #define AMF_VIDEO_ENCODER_AV1_RATE_CONTROL_METHOD_HIGH_QUALITY_CBR 6\
      #define AMF_VIDEO_ENCODER_HEVC_RATE_CONTROL_METHOD_QUALITY_VBR 4\
      #define AMF_VIDEO_ENCODER_HEVC_RATE_CONTROL_METHOD_HIGH_QUALITY_VBR 5\
      #define AMF_VIDEO_ENCODER_HEVC_RATE_CONTROL_METHOD_HIGH_QUALITY_CBR 6\
      #define AMF_VIDEO_ENCODER_RATE_CONTROL_METHOD_QUALITY_VBR 4\
      #define AMF_VIDEO_ENCODER_RATE_CONTROL_METHOD_HIGH_QUALITY_VBR 5\
      #define AMF_VIDEO_ENCODER_RATE_CONTROL_METHOD_HIGH_QUALITY_CBR 6' \
        src/config.cpp
    ''
    # remove non-existent input.cpp from source list (replaced by inputtino files)
    + ''
      sed -i '/platform\/linux\/input\.cpp/d' cmake/compile_definitions/linux.cmake
    ''
    # remove Windows-only display device files from common source list
    + ''
      sed -i \
        -e '/display_device\/parsed_config/d' \
        -e '/display_device\/session\./d' \
        -e '/display_device\/vdd_utils/d' \
        -e '/display_device\/vdd_ioctl/d' \
        -e '/entry_handler\./d' \
        -e '/display_control\./d' \
        -e '/display_scale\./d' \
        cmake/compile_definitions/common.cmake
    ''
    # remove upstream dependency on systemd and udev, set install paths manually
    # also skip packaging files that don't exist in this fork version
    + lib.optionalString isLinux (''
      substituteInPlace cmake/packaging/linux.cmake \
        --replace-fail 'find_package(Systemd)' 'set(SYSTEMD_USER_UNIT_INSTALL_DIR "lib/systemd/user")' \
        --replace-fail 'find_package(Udev)' 'set(UDEV_RULES_INSTALL_DIR "lib/udev/rules.d")'

      # Remove configure_file lines for files that don't exist in this fork
      sed -i \
        -e '/sunshine\.desktop/d' \
        -e '/sunshine_terminal\.desktop/d' \
        -e '/sunshine\.service\.in/d' \
        -e '/sunshine\.appdata\.xml/d' \
        cmake/prep/special_package_configuration.cmake
    '');

  nativeBuildInputs = [
    cmake
    pkg-config
    python3
    makeWrapper
  ]
  ++ lib.optionals isLinux [
    wayland-scanner
    autoPatchelfHook
  ]
  ++ lib.optionals cudaSupport [
    autoAddDriverRunpath
    cudaPackages.cuda_nvcc
    (lib.getDev cudaPackages.cuda_cudart)
  ];

  buildInputs = [
    boost
    curl
    miniupnpc
    nlohmann_json
    openssl
    libopus
  ]
  ++ lib.optionals isLinux [
    avahi
    libevdev
    libpulseaudio
    libx11
    libxcb
    libxfixes
    libxrandr
    libxtst
    libxi
    libdrm
    wayland
    libffi
    libcap
    pcre2
    libuuid
    libselinux
    libsepol
    libthai
    libdatrie
    libxdmcp
    libxkbcommon
    libepoxy
    libva
    libvdpau
    numactl
    libgbm
    amf-headers
    svt-av1
    libappindicator
    libnotify
  ]
  ++ lib.optionals cudaSupport [
    cudaPackages.cudatoolkit
    cudaPackages.cuda_cudart
  ]
  ++ lib.optionals isDarwin [
    apple-sdk_15
  ];

  runtimeDependencies = lib.optionals isLinux [
    avahi
    libgbm
    libxrandr
    libxcb
    libglvnd
  ];

  cmakeFlags = [
    "-Wno-dev"
    (lib.cmakeFeature "CMAKE_CXX_STANDARD" "17")
    (lib.cmakeBool "BUILD_TESTS" false)
    (lib.cmakeBool "SUNSHINE_BUILD_APPIMAGE" false)
    (lib.cmakeBool "SUNSHINE_BUILD_FLATPAK" false)
  ]
  ++ lib.optionals (!cudaSupport) [
    (lib.cmakeBool "SUNSHINE_ENABLE_CUDA" false)
  ]
  ++ lib.optionals isDarwin [
    (lib.cmakeFeature "OPENSSL_ROOT_DIR" "${openssl.dev}")
    (lib.cmakeBool "SUNSHINE_BUILD_HOMEBREW" true)
  ];

  env = {
    BUILD_VERSION = "${finalAttrs.version}";
    BRANCH = "master";
    COMMIT = "";
  };

  preBuild = ''
    cp -r ${finalAttrs.ui}/build ../
  '';

  buildFlags = [
    "sunshine"
  ];

  installPhase = ''
    runHook preInstall

    cmake --install .

    runHook postInstall
  '';

  postInstall = lib.optionalString isLinux ''
    # desktop and service files are not available in this fork version
  '';

  postFixup = lib.optionalString cudaSupport ''
    wrapProgram $out/bin/sunshine \
      --set LD_LIBRARY_PATH ${lib.makeLibraryPath [ vulkan-loader ]}
  '';

  meta = {
    description = "Game stream host for Moonlight - AlkaidLab fork with HDR and virtual display support";
    homepage = "https://github.com/AlkaidLab/foundation-sunshine";
    license = lib.licenses.gpl3Only;
    mainProgram = "sunshine";
    maintainers = [ "74k1" ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
