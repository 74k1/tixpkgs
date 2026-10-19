{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "godap";
  version = "2.12.2";
  src = fetchFromGitHub {
    owner = "Macmod";
    repo = "godap";
    rev = "v${version}";
    hash = "sha256-8Xlf9VL1rJ7PMk8dRia0bmYkx1gCstnp/Sv9FO1BxSw=";
  };
  vendorHash = "sha256-wqBpsZdfU9xOGKbspWYq8A6xmCrIQrKFhx4s7M6K6/M=";

  meta = with lib; {
    description = "A lightweight LDAP directory server";
    homepage = "https://github.com/Macmod/godap";
    license = licenses.mit;
    maintainers = with lib.maintainers; [ _74k1 ];
  };
}
