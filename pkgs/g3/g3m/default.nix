{
  lib,
  python3Packages,
  fetchFromGitHub,
  unrar,
  makeWrapper,
}:

let
  playsound3 = python3Packages.buildPythonPackage {
    pname = "playsound3";
    version = "3.3.1";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "szmikler";
      repo = "playsound3";
      rev = "v3.3.1";
      hash = "sha256-vTMhSJBasC+z3i52JtSeZwuF47y6ABl0hawvOxNkXzU=";
    };

    build-system = [ python3Packages.hatchling ];

    # No dependencies on Linux; pywin32 only needed on Windows.
    dependencies = [ ];
  };
in
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "g3m";
  version = "3.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "y114git";
    repo = "G3M";
    rev = "3.2.1";
    hash = "sha256-szwBzm/Tg7xZkYiaC3CIAgYg4OIs+7oaXGrRMeNXCvw=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = [
    python3Packages.pyqt6
    python3Packages.defusedxml
    playsound3
    python3Packages.psutil
    python3Packages.py7zr
    python3Packages.python-dotenv
    python3Packages.rarfile
    python3Packages.requests
    python3Packages.urllib3
  ];

  nativeBuildInputs = [ makeWrapper ];

  # Setuptools with package-dir = { "" = "src" } only picks up .py files.
  # The non-Python assets (icons, themes, fonts, language packs, QSS
  # stylesheets) sit under src/assets/ and src/config/qss/ and must be
  # copied manually so resource_path() resolves them at runtime.
  postInstall = ''
    site_packages=$out/${python3Packages.python.sitePackages}
    cp -r src/assets $site_packages/
    cp -r src/config/qss $site_packages/config/
  '';

  postFixup = ''
    makeWrapper ${python3Packages.python}/bin/python $out/bin/g3m \
      --add-flags "-c" \
      --add-flags "from main import main; import sys; sys.exit(main())" \
      --prefix PATH : ${lib.makeBinPath [ unrar ]}
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
