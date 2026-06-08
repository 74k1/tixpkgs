{
  lib
  , fetchFromGitHub
  , rustPlatform
}:
rustPlatform.buildRustPackage rec {
  pname = "logria";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "ReagentX";
    repo = "logria";
    rev = "${version}";
    hash = "sha256-hzsUm6J2gxTw2n18vshEXzwAwrLHEjxR4ZYFidAvePM=";
  };

  cargoHash = "sha256-Mwv+5e01xzCJvkhsabBdJIj7OQCIBiceFsAH3+PF+fk=";

  doCheck = false;

  meta = {
    description = "A powerful CLI tool that puts log aggregation at your fingertips.";
    homepage = "https://github.com/ReagentX/Logria";
    license = lib.licenses.gpl3Plus;
    maintainers = [ "74k1" ];
    platforms = lib.platforms.all;
  };
}
