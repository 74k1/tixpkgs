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
  version = "1.9.0";

  src = fetchFromGitHub {
    owner = "jnsahaj";
    repo = "lumen";
    rev = "v${version}";
    hash = "sha256-BUCL7qe1oDlU65yqePK3CsLjRvHxOHukqUMv2nztykw=";
  };

  cargoHash = "sha256-lJntyjZhJYyt3vO5SNGO0+HIhMrmOmnWw2Y60aXBFQk=";

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
