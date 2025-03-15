{
  lib
  , fetchFromGitHub
  , rustPlatform
}:
rustPlatform.buildRustPackage rec {
  pname = "logria";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "ReagentX";
    repo = "logria";
    rev = "${version}";
    hash = "sha256-09U/M527X78IOOzKYhRdep0Ql8ec4Q8VMkeA5iwuqtQ=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-cdZQEpnqDasB4TP2pzsfDHk9KUYIPgtXnR6N6hIVy+Y=";

  doCheck = false;

  meta = {
    description = "A powerful CLI tool that puts log aggregation at your fingertips.";
    homepage = "https://github.com/ReagentX/Logria";
    license = lib.licenses.gpl3Plus;
    maintainers = [ "74k1" ];
    platforms = lib.platforms.all;
  };
}
