{
  buildGoModule,
  callPackage,
  fetchFromGitHub,
  lib,
  makeBinaryWrapper,
}:
let
  version = "14.0.0";

  src = fetchFromGitHub {
    owner = "jhaals";
    repo = "yopass";
    rev = version;
    hash = "sha256-AbYmjdd5GyX3vOfsml8fptnRhwTcQZTr+PiHtdqbJfI=";
  };

  website = callPackage ./website.nix { inherit src version; };
in
buildGoModule (finalAttrs: {
  inherit version src;
  pname = "yopass";

  vendorHash = "sha256-4gQOXYDA0aN5CdTP6IPv7LuJNdIKKST8qD8fPvo8ZS4=";

  nativeBuildInputs = [ makeBinaryWrapper ];

  subPackages = [
    "cmd/yopass"
    "cmd/yopass-server"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  checkFlags = [
    # Disable tests that require network access (tries to connect to memcached/redis)
    "-skip=TestSecretNotFoundError|TestNewServer"
  ];

  postInstall = ''
    wrapProgram $out/bin/yopass-server \
      --add-flags "--asset-path ${website}"
  '';

  meta = {
    description = "Secure sharing of secrets, passwords and files";
    homepage = "https://github.com/jhaals/yopass";
    changelog = "https://github.com/jhaals/yopass/releases/tag/${finalAttrs.src.rev}";
    license = lib.licenses.asl20;
    maintainers = [ "74k1" ];
    mainProgram = "yopass";
    platforms = lib.platforms.unix;
  };

  passthru.updateScript = ./update.sh;
})
