{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  buildNpmPackage,
  nodejs_24,
  gradle_9,
  makeWrapper,
  openjdk25,
  ffmpeg,
  kepubify,
  libarchive,
}:
let
  version = "3.0.3";

  src = fetchFromGitHub {
    owner = "grimmory-tools";
    repo = "grimmory";
    rev = "v${version}";
    hash = "sha256-dWZcCX0Tp+yPp+4vBERYEwu+rysCzJ9QfMQhD65t1vQ=";
  };

  buildNpmPackage' = buildNpmPackage.override { nodejs = nodejs_24; };

  webui = buildNpmPackage' {
    pname = "grimmory-ui";
    inherit version;

    src = src + "/frontend";

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmBuildScript = "build:prod";
    npmFlags = [ "--legacy-peer-deps" ];
    npmDepsHash = "sha256-DBa/2q7pUZuKJB48JVDnlxK+q4eXBmOfrxIJ3WuzTY0=";

    env = {
      CI = "1";
      NG_CLI_ANALYTICS = "false";
    };

    installPhase = ''
      runHook preInstall

      cp -r dist/grimmory/browser $out

      runHook postInstall
    '';
  };

  gradle = gradle_9.override { java = openjdk25; };

  grimmory = stdenvNoCC.mkDerivation (final: {
    pname = "grimmory";
    inherit version;

    src = src + "/backend";

    APP_VERSION = version;

    postPatch = ''
      substituteInPlace src/main/resources/application.yaml \
        --replace-fail "path-config: '/app/data'" "path-config: \''${GRIMMORY_DATA_DIR:/var/lib/grimmory/data}" \
        --replace-fail "bookdrop-folder: '/bookdrop'" "bookdrop-folder: \''${GRIMMORY_BOOKDROP_DIR:/var/lib/grimmory/bookdrop}"
    '';

    nativeBuildInputs = [
      gradle
      makeWrapper
    ];

    mitmCache = gradle.fetchDeps {
      inherit (final) pname;
      pkg = grimmory;
      data = ./deps.json;
    };

    preBuild = ''
      cp -r ${webui} frontend-dist
      chmod -R u+rwX frontend-dist
      gradleFlagsArray+=("-PfrontendDistDir=$PWD/frontend-dist")
    '';

    gradleBuildTask = "bootJar";

    installPhase = ''
      runHook preInstall

      jar=$(find build/libs -maxdepth 1 -name '*.jar' ! -name '*plain.jar' -print -quit)
      install -Dm644 "$jar" $out/share/grimmory/grimmory.jar

      makeWrapper ${lib.getExe' openjdk25 "java"} $out/bin/grimmory \
        --prefix PATH : ${lib.makeBinPath [ ffmpeg kepubify ]} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libarchive ]} \
        --set-default APP_VERSION "${version}" \
        --add-flags "--enable-native-access=ALL-UNNAMED" \
        --add-flags "--enable-preview" \
        --add-flags "-jar $out/share/grimmory/grimmory.jar"

      runHook postInstall
    '';

    meta = {
      description = "Self-hosted, multi-user digital library with smart shelves, metadata, Kobo and KOReader sync, OPDS, and a built-in reader";
      mainProgram = "grimmory";
      homepage = "https://github.com/grimmory-tools/grimmory";
      changelog = "https://github.com/grimmory-tools/grimmory/releases/tag/v${version}";
      license = lib.licenses.agpl3Only;
      maintainers = [ "74k1" ];
      platforms = [ "x86_64-linux" ];
    };
  });
in
  grimmory
