{
  lib
  , stdenv
  , fetchFromGitHub
  , pkg-config
  , openssl
  , git
  , fzf
  , mdcat
  , rustPlatform
  , darwin
}:

rustPlatform.buildRustPackage rec {
  pname = "lumen";
  version = "1.6.0";

  src = fetchFromGitHub {
    owner = "jnsahaj";
    repo = "lumen";
    rev = "v${version}";
    hash = "sha256-d5K6ttOs1tnOg4GChMd5IBlucPTDaypqfC7qss5j5yU=";
  };

  cargoHash = "sha256-dN96HCY7z8G2ziGTT/lJ/FsIMPcynl6Eb5sfbK31Boo=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
    git
    fzf
    mdcat
  ] ++ lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
  ];

  env.OPENSSL_NO_VENDOR = 1;

  meta = {
    description = "Instant AI Git Commit message generator";
    homepage = "https://github.com/jnsahaj/lumen";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.all;
  };
}
