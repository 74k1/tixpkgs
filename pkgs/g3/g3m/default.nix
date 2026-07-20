{
  lib,
  python314Packages,
  fetchFromGitHub,
  unrar,
}:

let
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
    rev = "3.2.1";
    hash = "sha256-szwBzm/Tg7xZkYiaC3CIAgYg4OIs+7oaXGrRMeNXCvw=";
  };

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
    python314Packages.pythonRelaxDepsHook
  ];

  pythonRelaxDeps = true;

  makeWrapperArgs = [
    "--prefix" "PATH" ":" "${unrar}/bin"
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

  passthru.updateScript = ./update.sh;

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
