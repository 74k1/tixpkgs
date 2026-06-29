{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule {
  pname = "degoog-mcp";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "degoog-org";
    repo = "mcp";
    rev = "0.1.0";
    hash = "sha256-aPPyjvno3Ayfnu9cMaE9C/Fi4p+9HzNqGmh/+hm07P8=";
  };

  vendorHash = "sha256-7BseL5WTC+S0X0gE2mQYdWNG804uqDFqjGoYFi+da4E=";

  meta = {
    description = "MCP server sidecar for the Degoog search aggregator";
    homepage = "https://github.com/degoog-org/mcp";
    license = lib.licenses.agpl3Only;
    mainProgram = "degoog-mcp";
    maintainers = [ "74k1" ];
    platforms = lib.platforms.unix;
  };
}
