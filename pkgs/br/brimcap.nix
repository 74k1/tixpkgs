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

  installPhase = ''
    runHook preInstall
    
    # Install Go binaries
    mkdir -p $out/bin
    install -Dm755 $GOPATH/bin/brimcap $out/bin/brimcap
    
    # Create directory structure
    mkdir -p $out/share/brimcap/zeek
    mkdir -p $out/share/brimcap/suricata
    
    # Copy zeek files
    cp -r ${zeekBinary}/* $out/share/brimcap/zeek/
    
    # Create zeekrunner script (pointing to the correct path)
    cat > $out/share/brimcap/zeek/zeekrunner << 'EOF'
    #!/bin/sh
    SCRIPTPATH="$(cd "$(dirname "\$0")" && pwd)"
    exec "$SCRIPTPATH/zeek/bin/zeek" "$@"
    EOF
    chmod 755 $out/share/brimcap/zeek/zeekrunner
    
    # Copy suricata files
    cp -r ${suricataBinary}/* $out/share/brimcap/suricata/
    
    # Create suricatarunner script
    cat > $out/share/brimcap/suricata/suricatarunner << 'EOF'
    #!/bin/sh
    SCRIPTPATH="$(cd "$(dirname "$0")" && pwd)"
    BASEDIR="$SCRIPTPATH/suricata"
    mkdir -p "$HOME/.cache/brimcap/suricata"
    cp -n "$BASEDIR/etc/suricata/brim-conf.yaml" "$HOME/.cache/brimcap/suricata/brim-conf-run.yaml"
    exec "$BASEDIR/bin/suricata" -c "$HOME/.cache/brimcap/suricata/brim-conf-run.yaml" "$@"
    EOF
    chmod 755 $out/share/brimcap/suricata/suricatarunner
    
    # Create symlinks to runners in main bin directory
    ln -sf $out/share/brimcap/zeek/zeekrunner $out/bin/zeekrunner
    ln -sf $out/share/brimcap/suricata/suricatarunner $out/bin/suricatarunner
    
    # Create symlink for brimcap in the brimcap directory
    ln -sf $out/bin/brimcap $out/share/brimcap/brimcap
    
    # Wrap the brimcap binary
    wrapProgram $out/bin/brimcap \
      --prefix PATH : $out/bin \
      --prefix PATH : $out/share/brimcap \
      --prefix PATH : $out/share/brimcap/zeek \
      --prefix PATH : $out/share/brimcap/suricata \
      --prefix PATH : ${lib.makeBinPath [ zq ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
        stdenv.cc.cc.lib
        zlib
        nss
        nspr
      ]}
      
    runHook postInstall
  '';

  # Skip default autoPatchelf
  dontAutoPatchelf = true;

  postFixup = ''
    find $out/share/brimcap/zeek/bin -type f -executable -exec autoPatchelf {} \; || true
    find $out/share/brimcap/suricata/bin -type f -executable -exec autoPatchelf {} \; || true
  '';

  meta = with lib; {
    description = "Convert pcap files into richly-typed ZNG summary logs";
    homepage = "https://github.com/brimdata/brimcap";
    license = licenses.bsd3;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
