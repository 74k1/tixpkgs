{
  lib,
  stdenv,
  fetchurl,
  ncurses,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "whowatch";
  version = "1.8.6";

  src = fetchurl {
    url = "https://github.com/mtsuszycki/whowatch/releases/download/whowatch-${finalAttrs.version}/whowatch-${finalAttrs.version}.tar.gz";
    hash = "sha256-m98DOIUP1mA2y02x96YbNfUCFYwxWYH3F22Pg0oLWgI=";
  };

  buildInputs = [ ncurses ];

  # gcc 14+ rejects old-style `void handler()` passed to signal()
  env.NIX_CFLAGS_COMPILE = "-std=gnu11 -Wno-error=incompatible-pointer-types";

  meta = {
    description = "Interactive who-like program displaying users and their processes in real time";
    homepage = "https://github.com/mtsuszycki/whowatch";
    changelog = "https://github.com/mtsuszycki/whowatch/releases/tag/whowatch-${finalAttrs.version}";
    license = lib.licenses.gpl2Only;
    mainProgram = "whowatch";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
