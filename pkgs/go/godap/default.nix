{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "godap";
  version = "2.11.1";
  src = fetchFromGitHub {
    owner = "Macmod";
    repo = "godap";
    rev = "v${version}";
    hash = "sha256-004j01OcFz8MgWBp3r+ejBJuR6hjy9U9S0b6A6GRS5U=";
  };
  vendorHash = "sha256-D5Eq2JFIEmxO/FBGON+nKtGktWPOzXfv8l5akRTpz7Q=";

  meta = with lib; {
    description = "A lightweight LDAP directory server";
    homepage = "https://github.com/Macmod/godap";
    license = licenses.mit;
    maintainers = with lib.maintainers; [ _74k1 ];
  };
}
