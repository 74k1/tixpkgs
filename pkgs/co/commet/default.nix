{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  flutter341,
  rustPlatform,
  writeText,
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
  sqlite,
  webkitgtk_4_1,
  xdg-utils,
  zlib,
}:

let
  libwebrtcZip = fetchurl {
    url = "https://github.com/flutter-webrtc/flutter-webrtc/releases/download/v1.2.1/libwebrtc.zip";
    hash = "sha256-rMQjW2KdD3yPGj8mAU/9Qw7WYrqeHtRHFJcAnBIHWpk=";
  };

  libwebrtc = fetchzip {
    url = "https://github.com/flutter-webrtc/flutter-webrtc/releases/download/v1.2.1/libwebrtc.zip";
    hash = "sha256-i4LRG44f//SDIOl072yZavkYoTZdiydPZndeOm6/fBM=";
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
    webkitgtk_4_1
    zlib
  ];
in
flutter341.buildFlutterApplication (finalAttrs: {
  pname = "commet";
  version = "0.4.2+hotfix.2";

  src = fetchFromGitHub {
    owner = "commetchat";
    repo = "commet";
    tag = "v${finalAttrs.version}";
    hash = "sha256-z8V6p8DO/8YVDhpoin4FajMvDNg8FGEi27QH9q7+7wM=";
  };

  sourceRoot = "source";

  pubspecLock = lib.importJSON ./pubspec.lock.json;
  gitHashes = lib.importJSON ./git-hashes.json;

  customSourceBuilders.flutter_vodozemac =
    { version, src, ... }:
    let
      rustDep = rustPlatform.buildRustPackage {
        pname = "flutter_vodozemac-rs";
        inherit version src;

        sourceRoot = "${src.name}/rust";
        cargoHash = "sha256-eKKrcroV2yl/FV2WmgZWFPO5MPAGz0xCvpr0fgIuGZ4=";

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
        substituteInPlace third_party/CMakeLists.txt \
          --replace-fail 'set(ZIPFILE "''${CMAKE_CURRENT_LIST_DIR}/downloads/libwebrtc.zip")' \
                         'set(ZIPFILE "${libwebrtcZip}")'
        ln -s ${libwebrtc} third_party/libwebrtc
      '';

      installPhase = ''
        runHook preInstall

        mkdir $out
        cp -r ./* $out/

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
    broken = true;
  };
})
