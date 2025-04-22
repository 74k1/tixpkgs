{
  lib
  , fetchFromGitHub
  , rustPlatform
}:
rustPlatform.buildRustPackage rec {
  pname = "end-rs";
  version = "0.1.22";

  src = fetchFromGitHub {
    owner = "Dr-42";
    repo = "end-rs";
    rev = "v${version}";
    hash = "sha256-TP5ox0bIE+opu0c+nQVoLjCv2W5v1eJzi4KMdnnOSw0=";
  };

  cargoHash = "sha256-fQBf8RvO+0+XwzN1Jvwy2nt8fxUGjhsIAqBQFEpEilY=";

  meta = {
    description = "Eww notification daemon (in Rust)";
    homepage = "https://github.com/Dr-42/end-rs";
    license = lib.licenses.bsd2;
    maintainers = [ "74k1" ];
    platforms = lib.platforms.all;
  };
}
