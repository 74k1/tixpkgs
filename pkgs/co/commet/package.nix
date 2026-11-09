{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  flutter347,
  rustPlatform,
  writeText,
  writeScript,
  alsa-lib,
  atk,
  cairo,
  dbus,
  fontconfig,
  gdk-pixbuf,
  glib,
  glib-networking,
  gtk3,
  harfbuzz,
  keybinder3,
  libass,
  libdrm,
  libepoxy,
  libgbm,
  libpulseaudio,
  libxcb,
  libxkbcommon,
  mpv-unwrapped,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  mesa,
  pango,
  pcre2,
  pipewire,
  pkg-config,
  sqlite,
  sqlcipher,
  wayland,
  webkitgtk_4_1,
  xdg-utils,
  zlib,
}:

let
  libwebrtcZip = fetchurl {
    url = "https://github.com/webrtc-sdk/libwebrtc/releases/download/libwebrtc.m150.7871.07/libwebrtc-linux-x64-release.zip";
    hash = "sha256-7zgFJs+WFoSLwLl7JJkMvyrYUcIJ1dzpPMPrudN4n7w=";
  };

  libwebrtc = fetchzip {
    url = "https://github.com/webrtc-sdk/libwebrtc/releases/download/libwebrtc.m150.7871.07/libwebrtc-linux-x64-release.zip";
    hash = "sha256-vUyg8YDjNlrcuODXRfhJ2jK+syRfScbz7QLI60/Vzas=";
  };

  runtimeLibraries = [
    alsa-lib
    atk
    cairo
    dbus
    fontconfig
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    harfbuzz
    keybinder3
    libass
    libdrm
    libepoxy
    libgbm
    libpulseaudio
    # overlay pulls smithay-client-toolkit and winit: sctk links xkbcommon,
    # winit dlopens libwayland-client and libxcb at runtime.
    libxcb
    libxkbcommon
    mpv-unwrapped
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    mesa
    pango
    pcre2
    pipewire
    sqlite
    stdenv.cc.cc.lib
    wayland
    webkitgtk_4_1
    zlib
  ];
in
flutter347.buildFlutterApplication (finalAttrs: {
  pname = "commet";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "commetchat";
    repo = "commet";
    tag = "v${finalAttrs.version}";
    hash = "sha256-uJ9qZpGL+vNME0wcw96ai50TFzanBISTMYwpIFnNwb0=";
  };

  sourceRoot = "source";

  pubspecLock = lib.importJSON ./pubspec.lock.json;
  gitHashes = lib.importJSON ./git-hashes.json;

  # The nixpkgs sqlite3 builder does not yet support pub sqlite3 3.8.0.
  customSourceBuilders.sqlite3 =
    { version, src, ... }:
    stdenv.mkDerivation {
      pname = "sqlite3";
      inherit version src;
      inherit (src) passthru;

      setupHook = writeScript "sqlite3-setup-hook" ''
        sqliteFixupHook() {
          runtimeDependencies+=('${lib.getLib sqlite}' '${lib.getLib sqlcipher}')
        }
        preFixupHooks+=(sqliteFixupHook)
      '';

      postPatch = ''
        substituteInPlace lib/src/hook/compile/description.dart \
          --replace-fail "return fromGitHub(LibraryType.sqlite3);" "return LookupSystem('sqlite3');" \
          --replace-fail "return fromGitHub(LibraryType.sqlcipher);" "return LookupSystem('sqlcipher');"
      '';

      installPhase = ''
        runHook preInstall
        cp --recursive . "$out"
        runHook postInstall
      '';
    };

  customSourceBuilders.flutter_vodozemac =
    { version, src, ... }:
    let
      rustDep = rustPlatform.buildRustPackage {
        pname = "flutter_vodozemac-rs";
        inherit version src;

        sourceRoot = "${src.name}/rust";
        cargoHash = "sha256-FItk47LyzSkII1o7mn+ojLDctolfi5/X0el+/8tmO60=";

        passthru.libraryPath = "lib/libvodozemac_bindings_dart.so";
      };

      fakeCargokitCmake = writeText "FakeCargokit.cmake" ''
        function(apply_cargokit target manifest_dir lib_name any_symbol_name)
          set("''${target}_cargokit_lib" ${rustDep}/${rustDep.passthru.libraryPath} PARENT_SCOPE)
        endfunction()
      '';

      getLibraryPath = ''
        String _getLibraryPath() {
          if (kIsWeb) {
            return './';
          }
          try {
            return Platform.resolvedExecutable + '/../lib/libvodozemac_bindings_dart.so';
          } catch (_) {
            return './';
          }
        }
      '';
    in
    stdenv.mkDerivation {
      pname = "flutter_vodozemac";
      inherit version src;
      passthru = src.passthru // {
        inherit (rustDep) cargoDeps;
      };

      installPhase = ''
        runHook preInstall

        cp -r "$src" "$out"
        pushd $out
          chmod +rwx cargokit/cmake/cargokit.cmake
          cp ${fakeCargokitCmake} cargokit/cmake/cargokit.cmake
          chmod +rw lib/flutter_vodozemac.dart
          substituteInPlace lib/flutter_vodozemac.dart \
            --replace-warn "libraryPath: './'" "libraryPath: _getLibraryPath()"
          echo "${getLibraryPath}" >> lib/flutter_vodozemac.dart
        popd

        runHook postInstall
      '';
    };

  customSourceBuilders.flutter_webrtc =
    { version, src, ... }:
    stdenv.mkDerivation {
      pname = "flutter_webrtc";
      inherit version src;
      inherit (src) passthru;

      postPatch = ''
        # third_party/CMakeLists.txt reads binary_version and download_url from
        # libwebrtc_version.ini and looks for the archive at
        # downloads/libwebrtc-linux-x64-release.zip. It skips both the download
        # and the extraction when that archive and third_party/libwebrtc exist.
        # The asset name encodes linux-x64, which matches meta.platforms.
        mkdir -p third_party/downloads
        ln -s ${libwebrtcZip} third_party/downloads/libwebrtc-linux-x64-release.zip
        ln -s ${libwebrtc} third_party/libwebrtc
      '';

      installPhase = ''
        runHook preInstall

        mkdir $out
        cp -r ./* $out/

        runHook postInstall
      '';
    };

  customSourceBuilders.rust_lib_commet =
    { version, src, ... }:
    let
      rustDep = rustPlatform.buildRustPackage {
        pname = "rust_lib_commet-rs";
        inherit version src;

        # workspace root: Cargo.toml/Cargo.lock live at the repo root
        cargoLock = {
          lockFile = src + "/Cargo.lock";
          outputHashes = lib.importJSON ./cargo-output-hashes.json;
        };

        nativeBuildInputs = [ pkg-config ];
        buildInputs = [
          gtk3
          # smithay-client-toolkit's build script probes xkbcommon with pkg-config.
          libxkbcommon
          wayland
          webkitgtk_4_1
        ];

        passthru.libraryPath = "lib/librust_lib_commet.so";
      };

      fakeCargokitCmake = writeText "FakeCargokit.cmake" ''
        function(apply_cargokit target manifest_dir lib_name any_symbol_name)
          set("''${target}_cargokit_lib" ${rustDep}/${rustDep.passthru.libraryPath} PARENT_SCOPE)
        endfunction()
      '';
    in
    stdenv.mkDerivation {
      pname = "rust_lib_commet";
      inherit version src;
      passthru = src.passthru // {
        inherit (rustDep) cargoDeps;
      };

      installPhase = ''
        runHook preInstall

        cp -r "$src" "$out"
        pushd $out
          chmod +rwx rust/rust_builder/cargokit/cmake/cargokit.cmake
          cp ${fakeCargokitCmake} rust/rust_builder/cargokit/cmake/cargokit.cmake
        popd

        runHook postInstall
      '';
    };

  buildInputs = runtimeLibraries;

  env.COMMET_PROD = "1";

  buildPhase = ''
    runHook preBuild

    mkdir -p commet/.dart_tool
    jq 'del(.packages[] | select(.name == "_"))' \
      .dart_tool/package_config.json > commet/.dart_tool/package_config.json
    cp .dart_tool/package_graph.json commet/.dart_tool/package_graph.json
    cp pubspec.lock commet/pubspec.lock

    cd commet
    packageRunCustom intl_utils generate bin
    mkdir -p lib/generated/intl
    cat > lib/generated/intl/messages_all.dart <<'EOF'
    import 'dart:async';

    Future<bool> initializeMessages(String localeName) => Future.value(true);
    EOF
    packageRun build_runner build -- --delete-conflicting-outputs
    mkdir -p build/flutter_assets/fonts
    flutter build linux -v --split-debug-info="$debug" $flutterBuildFlags
    cd ..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    built=commet/build/linux/*/$flutterMode/bundle

    mkdir -p $out/bin $out/app $out/share/applications $out/share/icons/hicolor/scalable/apps
    mv $built $out/app/commet
    ln -s $out/app/commet/commet $out/bin/commet

    install -Dm444 commet/linux/flatpak/chat.commet.commetapp.desktop \
      $out/share/applications/chat.commet.commetapp.desktop
    substituteInPlace $out/share/applications/chat.commet.commetapp.desktop \
      --replace-fail "{{VERSION_TAG}}" "${finalAttrs.version}"

    install -Dm444 commet/assets/images/app_icon/icon.svg \
      $out/share/icons/hicolor/scalable/apps/chat.commet.commetapp.svg

    # make *.so executable
    find $out/app/commet -iname "*.so" -type f -exec chmod +x {} +

    # remove build-directory RPATHs emitted by Flutter/CMake
    for f in $(find $out/app/commet -executable -type f); do
      if patchelf --print-rpath "$f" >/dev/null 2>&1 && patchelf --print-rpath "$f" | grep /build; then
        newrp=$(patchelf --print-rpath "$f" | tr ':' '\n' | grep -v /build | paste -sd: -)
        patchelf --set-rpath "$newrp" "$f"
      fi
    done

    runHook postInstall
  '';

  extraWrapProgramArgs = ''
    --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
    --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}"
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Your space to connect";
    homepage = "https://github.com/commetchat/commet";
    changelog = "https://github.com/commetchat/commet/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "commet";
    platforms = [ "x86_64-linux" ];
  };
})
