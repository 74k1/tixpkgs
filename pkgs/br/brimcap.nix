{ lib
, stdenv
, fetchFromGitHub
, fetchzip
, buildGoModule
, makeWrapper
, zq
, autoPatchelfHook
, zlib
, nss
, nspr
}:

buildGoModule rec {
  pname = "brimcap";
  version = "1.18.0";

  src = fetchFromGitHub {
    owner = "brimdata";
    repo = "brimcap";
    rev = "v${version}";
    hash = "sha256-LWhaZHIK7J9+Ee5YSGVBMR7gCGJWcvPmZTx4zKik5jk=";
  };

  vendorHash = "sha256-w47Glwgp18gDVdhaxmSz9sJIDKIJ7TOJSXzijfmNjeM=";

  nativeBuildInputs = [ 
    makeWrapper 
    autoPatchelfHook
  ];
  
  propagatedBuildInputs = [ zq ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
    nss
    nspr
  ];

  zeekBinary = fetchzip {
    url = "https://github.com/brimdata/build-zeek/releases/download/v7.0.0-brim1/zeek-v7.0.0-brim1.${stdenv.hostPlatform.parsed.kernel.name}-amd64.zip";
    hash = "sha256-3FUB7KSSeHNZEpo7xoiZquVianliUJMX672RwB3ZeFI=";
    stripRoot = false;
  };

  suricataBinary = fetchzip {
    url = "https://github.com/brimdata/build-suricata/releases/download/v5.0.3-brim5/suricata-v5.0.3-brim5.${stdenv.hostPlatform.parsed.kernel.name}-amd64.zip";
    hash = "sha256-4t+ZOZY9lFCGB2dGKe+wQh9g4hB34qUbOkA38iPxExI=";
    stripRoot = false;
  };

  preBuild = ''
    mkdir -p dist
    cp -r ${zeekBinary}/* dist/
    cp -r ${suricataBinary}/* dist/

    chmod +x dist/zeek/bin/* dist/suricata/bin/*
  '';

  buildPhase = ''
    runHook preBuild

    go build -ldflags="-s -w -X github.com/brimdata/brimcap/cli.Version=${version}" \
      -o dist/brimcap ./cmd/brimcap

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/brimcap
    cp -r dist/* $out/share/brimcap/
    
    ln -s $out/share/brimcap/brimcap $out/bin/brimcap
    
    wrapProgram $out/bin/brimcap \
      --prefix PATH : $out/share/brimcap \
      --prefix PATH : ${lib.makeBinPath [ zq ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
        stdenv.cc.cc.lib
        zlib
        nss
        nspr
      ]} \
      --set BRIM_SURICATA_USER_DIR "."
      # --set BRIM_SURICATA_USER_DIR "\$HOME/.local/share/brimcap"

    runHook postInstall
  '';

  dontAutoPatchelf = true;

  postFixup = ''
    autoPatchelf $out/share/brimcap/zeek/bin/*
    autoPatchelf $out/share/brimcap/suricata/bin/*
  '';

  meta = with lib; {
    description = "Convert pcap files into richly-typed ZNG summary logs";
    homepage = "https://github.com/brimdata/brimcap";
    license = with lib.licenses; [bsd3];
    maintainers = with lib.maintainers; ["74k1"];
    platforms = platforms.unix;
  };
}
