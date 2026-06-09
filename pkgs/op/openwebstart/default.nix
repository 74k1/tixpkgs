{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  dpkg,
  jdk8,
}:
let
  version = "1.13.0";
  debVersion = lib.replaceStrings [ "." ] [ "_" ] version;
in
stdenvNoCC.mkDerivation {
  pname = "openwebstart";
  inherit version;

  src = fetchurl {
    url = "https://github.com/karakun/OpenWebStart/releases/download/v${version}/OpenWebStart_linux_${debVersion}.deb";
    hash = "sha256-q9XZlTt1nflylvNPWyXxh0zvY3Nm+8e481cic3xUWso=";
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];
  buildInputs = [ jdk8 ];

  dontUnpack = true;

  installPhase = ''
        runHook preInstall

        dpkg-deb --extract "$src" extracted

        install -Dm644 extracted/opt/OpenWebStart/openwebstart.jar \
          "$out/share/openwebstart/openwebstart.jar"

        install -Dm644 extracted/opt/OpenWebStart/App-Icon-512.png \
          "$out/share/icons/hicolor/512x512/apps/openwebstart.png"

        install -Dm644 /dev/stdin "$out/share/applications/openwebstart.desktop" << 'EOF'
    [Desktop Entry]
    Name=OpenWebStart
    Comment=Run Web Start based JNLP applications
    Exec=javaws %u
    Icon=openwebstart
    Terminal=false
    Type=Application
    MimeType=application/x-java-jnlp-file;x-scheme-handler/jnlp;x-scheme-handler/jnlps;
    Categories=Network;Java;
    EOF

        install -Dm755 ${./seed-jvm.sh} "$out/libexec/openwebstart-seed-jvm.sh"
        substituteInPlace "$out/libexec/openwebstart-seed-jvm.sh" \
          --replace-fail "@jdk8@" "${jdk8}"

        makeWrapper "${lib.getExe' jdk8 "java"}" "$out/bin/javaws" \
          --run "$out/libexec/openwebstart-seed-jvm.sh" \
          --add-flags "-jar $out/share/openwebstart/openwebstart.jar"

        makeWrapper "${lib.getExe' jdk8 "java"}" "$out/bin/openwebstart" \
          --run "$out/libexec/openwebstart-seed-jvm.sh" \
          --add-flags "-jar $out/share/openwebstart/openwebstart.jar" \
          --add-flags "ITW-Cpl"

        runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Run Web Start based JNLP applications";
    homepage = "https://openwebstart.com";
    changelog = "https://github.com/karakun/OpenWebStart/releases/tag/v${version}";
    license = lib.licenses.gpl2Only;
    maintainers = [ "74k1" ];
    mainProgram = "javaws";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
