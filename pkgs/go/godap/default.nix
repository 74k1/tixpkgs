{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "godap";
  version = "2.11.0";
  src = fetchFromGitHub {
    owner = "Macmod";
    repo = "godap";
    rev = "v${version}";
    hash = "sha256-um9IsORwD4rPcqklEsRYI+J86R2vf7SE4RnTpaM6PnA=";
  };
  vendorHash = "sha256-D5Eq2JFIEmxO/FBGON+nKtGktWPOzXfv8l5akRTpz7Q=";

  meta = with lib; {
    description = "A lightweight LDAP directory server";
    homepage = "https://github.com/Macmod/godap";
    license = licenses.mit;
    maintainers = [ "74k1" ];
  };
}
