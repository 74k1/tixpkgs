{
  lib,
  stdenv,
  fetchurl,
}:

# PCRE version 1. Upstream stopped maintenance in 2021 and nixpkgs removed it.
# Nim's `std/re` and `std/nre` support no other version, so `shitter` needs it.
# JIT stays disabled, so services can keep `MemoryDenyWriteExecute`.
stdenv.mkDerivation (finalAttrs: {
  pname = "pcre";
  version = "8.45";

  src = fetchurl {
    url = "mirror://sourceforge/project/pcre/pcre/${finalAttrs.version}/pcre-${finalAttrs.version}.tar.bz2";
    hash = "sha256-Ta5v3NK7C7bDe1+Xwzwr6VTadDmFNpzdrDVG4yGL/7g=";
  };

  outputs = [
    "bin"
    "dev"
    "out"
    "doc"
    "man"
  ];

  patches = [
    # https://bugs.exim.org/show_bug.cgi?id=2173
    ./stacksize-detection.patch
  ];

  configureFlags = [
    "--enable-unicode-properties"
    "--disable-cpp"
  ];

  doCheck = true;

  preCheck = ''
    patchShebangs RunGrepTest
  '';

  postFixup = ''
    moveToOutput bin/pcre-config "$dev"
  '';

  meta = {
    description = "Library for Perl Compatible Regular Expressions (version 1, end of life)";
    homepage = "https://www.pcre.org/";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
    pkgConfigModules = [
      "libpcre"
      "libpcreposix"
    ];
  };
})
