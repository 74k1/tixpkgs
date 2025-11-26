{
  lib,
  buildGoModule,
  fetchFromGitHub
}:

buildGoModule rec {
  pname = "godap";
  version = "2.10.4";
  src = fetchFromGitHub {
    owner = "Macmod";
    repo = "godap";
    rev = "v${version}";
    hash = "sha256-mvzVOuFZABGE7DH3AkhOXvsvSZzgpW0aJUdXW6N6hf0=";
  };
  vendorHash = "sha256-NiNhKbf5bU1SQXFTZCp8/yNPc89ss8go6M2867ziqq4=";
}
