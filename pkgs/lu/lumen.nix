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
  version = "1.7.1";

  src = fetchFromGitHub {
    owner = "jnsahaj";
    repo = "lumen";
    rev = "v${version}";
    hash = "sha256-4G9hRs7sZFXWEk3N1Gy8Y3YtCeuqgVeFaChYG5uKfEw=";
  };

  cargoHash = "sha256-z+BcHEX4h7u09kT+jfzHuKJSLxjrmlslFYUAsLk8GVM=";

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
    maintainers = [ "74k1" ];
    platforms = lib.platforms.all;
  };
}
