{
  apple-sdk_15,
  buildMozillaMach,
  fetchFromGitHub,
  lib,
  stdenv,
}:

(buildMozillaMach rec {
  pname = "waterfox";
  version = "6.6.15";

  applicationName = "Waterfox";
  binaryName = "waterfox";
  branding = "waterfox/browser/branding";

  src = fetchFromGitHub {
    owner = "BrowserWorks";
    repo = "Waterfox";
    tag = version;
    hash = "sha256-pwEG42CTXjT//xIoESkhB1OD3G1L3Dp//mXjG9a9k5I=";
    fetchSubmodules = true;
    preFetch = ''
      export GIT_CONFIG_COUNT=1
      export GIT_CONFIG_KEY_0=url.https://github.com/.insteadOf
      export GIT_CONFIG_VALUE_0=git@github.com:
    '';
  };

  extraBuildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    apple-sdk_15
  ];

  extraConfigureFlags = [
    "--with-app-basename=${applicationName}"
  ];

  extraPatches = [
    ./remove-missing-icons.patch
  ];

  extraPostPatch = ''
    rm .mozconfig .mozcinfig-*
  '';

  updateScript = ./update.sh;

  meta = {
    broken = stdenv.buildPlatform.is32bit;
    changelog = "https://github.com/BrowserWorks/Waterfox/releases/tag/${version}";
    description = "Privacy-focused, multi-platform web browser";
    homepage = "https://www.waterfox.net/";
    license = lib.licenses.mpl20;
    mainProgram = "waterfox";
    maintainers = [ "74k1" ];
    maxSilent = 14400;
    platforms = lib.platforms.unix;
  };
})
