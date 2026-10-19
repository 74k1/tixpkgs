{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "logria";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "ReagentX";
    repo = "logria";
    rev = "${version}";
    hash = "sha256-mkrzhBAzIwcIafJkmqX6WSlSi/8YB3SenLWMLfk6pPQ=";
  };

  cargoHash = "sha256-RTgU+R7wopij8FxfwwtjJP5OdSUgAHvx9X3NhBEjdII=";

  doCheck = false;

  meta = {
    description = "A powerful CLI tool that puts log aggregation at your fingertips.";
    homepage = "https://github.com/ReagentX/Logria";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.all;
  };
}
