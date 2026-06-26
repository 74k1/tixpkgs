{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpmConfigHook,
  pnpm_11,
  openssl,
  makeBinaryWrapper,
  pkg-config,
}:
let
  version = "2.9.3";

  src = fetchFromGitHub {
    owner = "cupcakearmy";
    repo = "cryptgeon";
    rev = "v${version}";
    hash = "sha256-CwCc6WPVKZtmdjGGRNxbiFljEq6bBL97mAzgLOW+ZfY=";
  };

  frontend = stdenv.mkDerivation (finalAttrs: {
    pname = "cryptgeon-frontend";
    inherit version src;

    pnpmDeps = fetchPnpmDeps {
      pname = finalAttrs.pname;
      inherit src version;
      pnpm = pnpm_11;
      hash = "sha256-pFy7BRZDekV0WWK9ezCasIF84DoytU2CBHrLK1O7ZIc=";
      fetcherVersion = 3;
    };

    nativeBuildInputs = [
      nodejs
      pnpmConfigHook
      pnpm_11
    ];

    buildPhase = ''
      runHook preBuild

      pnpm run build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r packages/frontend/build/* $out/

      runHook postInstall
    '';
  });
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cryptgeon";
  inherit version src;

  sourceRoot = "${src.name}/packages/backend";

  cargoHash = "sha256-GIDmjOJpKeYxUdMG9Yc3+lgMbRH1s9WTeD/hJ+rXHTw=";

  nativeBuildInputs = [
    makeBinaryWrapper
    pkg-config
  ];

  buildInputs = [ openssl ];

  checkFlags = [
    # no tests in this package
  ];

  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/cryptgeon \
      --set-default FRONTEND_PATH ${frontend}
  '';

  meta = {
    description = "Secure, open source note & file sharing service inspired by PrivNote, written in Rust & Svelte";
    homepage = "https://github.com/cupcakearmy/cryptgeon";
    changelog = "https://github.com/cupcakearmy/cryptgeon/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = [ "74k1" ];
    mainProgram = "cryptgeon";
    platforms = lib.platforms.unix;
    longDescription = ''
      cryptgeon is a secure, open source sharing note or file service inspired
      by PrivNote. Each note has a generated id and key. The id is used to save
      and retrieve the note; the note is encrypted client-side with AES-GCM
      using the key. Data is held in memory (Redis) and never persisted to disk.
      The server never sees the encryption key and cannot decrypt note contents.
    '';
  };

  passthru.updateScript = ./update.sh;
})
