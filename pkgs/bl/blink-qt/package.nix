{
  lib,
  cacert,
  fetchFromGitHub,
  python3Packages,
  qt6Packages,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "blink-qt";
  version = "7.2.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "AGProjects";
    repo = "blink-qt";
    tag = finalAttrs.version;
    hash = "sha256-nWs4wd+98ZabjJq1y9aeRnwCg1v87ldXPam17NIy1ek=";
  };

  nativeBuildInputs = [ qt6Packages.wrapQtAppsHook ];

  build-system = with python3Packages; [ setuptools ];

  buildInputs = [
    qt6Packages.qtbase
    qt6Packages.qtsvg
  ];

  dependencies = with python3Packages; [
    dateutils
    dnspython
    google-api-python-client
    google-auth-oauthlib
    lxml
    lxml-html-clean
    numpy
    pgpy
    pyqt6
    pyqt6-webengine
    python3-application
    python3-eventlib
    python3-gnutls
    python3-msrplib
    python3-otr
    python3-sipsimple
    python3-xcaplib
    sqlobject
  ];

  dontWrapQtApps = true;

  preFixup = ''
    makeWrapperArgs+=("''${qtWrapperArgs[@]}")
  '';

  postFixup = ''
    rm $out/share/blink/tls/ca.crt
    ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt $out/share/blink/tls/ca.crt
  '';

  pythonImportsCheck = [ "blink" ];

  nativeCheckInputs = with python3Packages; [ pytestCheckHook ];

  disabledTestPaths = [
    # ModuleNotFoundError: No module named 'blink.conference'
    "tests/test_pstn_normalize.py::ConferenceTests::test_conference_domains"

    # AssertionError: Tuples differ: ('✓✓', 'displayed') != ('✔✔', 'displayed')
    "tests/test_messagepane_format.py::DayTests::test_marks"

    # FileNotFoundError: the test reads share/blink from the pytest package tree
    "tests/test_contact_repair.py::NameTests::test_echoed_names"
    "tests/test_contact_repair.py::PlanTests::test_full_plan"
  ];

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Fully featured, easy to use SIP client with a Qt based UI";
    homepage = "https://icanblink.com";
    downloadPage = "https://github.com/AGProjects/blink-qt";
    changelog = "https://github.com/AGProjects/blink-qt/blob/${finalAttrs.src.rev}/debian/changelog";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
    mainProgram = "blink";
  };
})
