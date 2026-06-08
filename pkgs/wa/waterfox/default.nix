{
  config,
  lib,
  stdenv,
  wrapFirefox,
  waterfox-unwrapped,
  applicationName ? waterfox-unwrapped.binaryName or (lib.getName waterfox-unwrapped),
  pname ? applicationName,
  version ? lib.getVersion waterfox-unwrapped,
  nameSuffix ? "",
  icon ? applicationName,
  wmClass ? applicationName,
  nativeMessagingHosts ? [ ],
  pkcs11Modules ? [ ],
  useGlvnd ? (!stdenv.hostPlatform.isDarwin),
  cfg ? config.${applicationName} or { },
  extraPrefs ? "",
  extraPrefsFiles ? [ ],
  extraPolicies ? { },
  extraPoliciesFiles ? [ ],
  libName ? waterfox-unwrapped.libName or applicationName,
  nixExtensions ? null,
  hasMozSystemDirPatch ? (lib.hasPrefix "firefox" pname && !lib.hasSuffix "-bin" pname),
  ...
}:

(wrapFirefox waterfox-unwrapped {
  inherit
    applicationName
    pname
    version
    nameSuffix
    icon
    wmClass
    nativeMessagingHosts
    pkcs11Modules
    useGlvnd
    cfg
    extraPrefs
    extraPrefsFiles
    extraPolicies
    extraPoliciesFiles
    libName
    nixExtensions
    hasMozSystemDirPatch
    ;
}).overrideAttrs
  (oldAttrs: {
    passthru = (oldAttrs.passthru or { }) // {
      updateScript = waterfox-unwrapped.updateScript;
    };
  })
