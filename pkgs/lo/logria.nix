{
  lib
  , fetchFromGitHub
  , rustPlatform
}:
rustPlatform.buildRustPackage rec {
  pname = "logria";
  version = "0.4.2";

  src = fetchFromGitHub {
    owner = "ReagentX";
    repo = "logria";
    rev = "${version}";
    hash = "sha256-5tq+kD0jiaAtC7YYD0H4gYK95+XWCaay7vo5z5WBhU8=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-nKrMzwTOW8MeOY16w3lSNadQa+mf8GHpQiwyLCJ5uLU=";

  doCheck = false;

  meta = {
    description = "A powerful CLI tool that puts log aggregation at your fingertips.";
    homepage = "https://github.com/ReagentX/Logria";
    license = lib.licenses.gpl3Plus;
    maintainers = [ "74k1" ];
    platforms = lib.platforms.all;
  };
}
