{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "ferroxide";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "acheong08";
    repo = "ferroxide";
    rev = "v${version}";
    hash = "sha256-GShbqcsfM2Wx4Ge4pmdgAUhXIsQSxlG+WE3VKda8ZoU=";
  };

  vendorHash = "sha256-YjJdC0ZXNLAUbCoK4L2h0B4EG4y+iYKcTudJkAiOItU=";

  doCheck = false;

  subPackages = [ "cmd/ferroxide" ];

  meta = {
    description = "Third-party, open-source ProtonMail bridge (ferroxide fork of hydroxide)";
    homepage = "https://github.com/acheong08/ferroxide";
    license = lib.licenses.mit;
    mainProgram = "ferroxide";
    maintainers = with lib.maintainers; [ _74k1 ];
  };
}
