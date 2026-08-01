{
  lib,
  buildDotnetModule,
  copyDesktopItems,
  dotnetCorePackages,
  fetchFromGitHub,
  ffmpeg,
  fontconfig,
  icoutils,
  makeDesktopItem,
  makeFontsConf,
  python314Packages,
  unrar,
  xdelta,
  xdg-utils,
}:

let
  g3mtool = buildDotnetModule {
    pname = "g3mtool";
    version = "1.2.1";

    src = fetchFromGitHub {
      owner = "y114git";
      repo = "G3MTool";
      tag = "1.2.1";
      hash = "sha256-V3okV2RJDyKiztulSUB0/qgdHXyGhXd6nWm9cUhXan4=";
    };

    projectFile = "G3MToolCLI/G3MToolCLI.csproj";
    nugetDeps = ./g3mtool-deps.json;
    dotnet-sdk = dotnetCorePackages.sdk_10_0;
    dotnet-runtime = dotnetCorePackages.runtime_10_0;
    selfContainedBuild = true;
    executables = [ "G3MTool" ];

    meta = {
      description = "Command-line tool for GameMaker data files";
      homepage = "https://github.com/y114git/G3MTool";
      license = lib.licenses.gpl3Only;
      maintainers = with lib.maintainers; [ _74k1 ];
      mainProgram = "G3MTool";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
  };

  fontsConf = makeFontsConf {
    inherit fontconfig;
    fontDirectories = [ ];
    impureFontDirectories = [
      "~/.fonts"
      "~/.local/share/fonts"
      "~/.nix-profile/share/fonts"
      "/run/current-system/sw/share/X11/fonts"
      "/run/current-system/sw/share/fonts"
    ];
    includes = [ "${fontconfig}/etc/fonts/conf.d" ];
  };

  playsound3 = python314Packages.buildPythonPackage {
    pname = "playsound3";
    version = "3.3.1";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "szmikler";
      repo = "playsound3";
      rev = "v3.3.1";
      hash = "sha256-vTMhSJBasC+z3i52JtSeZwuF47yA6Bl0hawvOxNkXzU=";
    };

    build-system = [ python314Packages.hatchling ];

    # No dependencies on Linux; pywin32 only needed on Windows.
    dependencies = [ ];
  };
in
python314Packages.buildPythonApplication (finalAttrs: {
  pname = "g3m";
  version = "3.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "y114git";
    repo = "G3M";
    rev = "e98e0c0214910dc0b8f30ba239c33c9c9c323614";
    hash = "sha256-KL3i3/N+yJurhZVmonIKYQsIzx5ol9mUNJ1aAET9nSs=";
  };

  patches = [ ./runtime-paths.patch ];

  build-system = [ python314Packages.setuptools ];

  dependencies = [
    python314Packages.pyqt6
    python314Packages.defusedxml
    playsound3
    python314Packages.psutil
    python314Packages.py7zr
    python314Packages.python-dotenv
    python314Packages.rarfile
    python314Packages.requests
    python314Packages.urllib3
  ];

  nativeBuildInputs = [
    copyDesktopItems
    icoutils
    python314Packages.pythonRelaxDepsHook
  ];

  pythonRelaxDeps = true;

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      ffmpeg
      g3mtool
      unrar
      xdelta
      xdg-utils
    ])
    "--set"
    "FONTCONFIG_FILE"
    "${fontsConf}"
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "g3m";
      desktopName = "G3M";
      comment = "Mod Manager for GameMaker games";
      exec = "g3m %u";
      icon = "g3m";
      categories = [ "Game" ];
      mimeTypes = [
        "x-scheme-handler/g3m"
        "x-scheme-handler/deltahub"
      ];
    })
  ];

  # Setuptools with package-dir = { "" = "src" } uses find_packages which
  # only picks up directories with __init__.py. Standalone modules at the
  # src root (main.py) and non-Python assets (icons, themes, fonts, language
  # packs, QSS stylesheets) must be copied manually so resource_path()
  # resolves them at runtime.
  #
  # Also install a bin/g3m entry point that wrapPythonPrograms will wrap
  # with the full PYTHONPATH of all dependencies.
  postInstall = ''
    site_packages=$out/${python314Packages.python.sitePackages}
    cp src/main.py $site_packages/
    cp -r src/assets $site_packages/
    cp -r src/config/qss $site_packages/config/

    icotool -x src/assets/icons/icon.ico
    install -Dm644 icon_1_256x256x32.png \
      $out/share/icons/hicolor/256x256/apps/g3m.png

    mkdir -p $out/bin
    cat > $out/bin/g3m <<'PYEOF'
    #!${python314Packages.python}/bin/python
    from main import main
    import sys
    sys.exit(main())
    PYEOF
    chmod +x $out/bin/g3m
  '';

  # The package has no importable namespace — everything is flat under
  # site-packages (main.py, utils/, config/, app/, etc.). There's no
  # single import that proves the package is functional.
  pythonImportsCheck = [ ];

  passthru = {
    inherit g3mtool;
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "Mod Manager for GameMaker games";
    homepage = "https://github.com/y114git/G3M";
    changelog = "https://github.com/y114git/G3M/releases/tag/${finalAttrs.version}";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ _74k1 ];
    mainProgram = "g3m";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
