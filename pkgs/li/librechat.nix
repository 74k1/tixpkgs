{ lib
, stdenv
, fetchFromGitHub
, nodejs
, nodePackages
}:

stdenv.mkDerivation rec {
  pname = "librechat";
  version = "0.7.6";

  src = fetchFromGitHub {
    owner = "danny-avila";
    repo = "LibreChat";
    rev = "v${version}";
    sha256 = "sha256-pyAF7FQcOoSO1a7XXGXdyahS1MUcc+LA0MetJv4ApqU=";
  };

  buildInputs = [ nodejs ];
  nativeBuildInputs = [ nodePackages.npm ];

  buildPhase = ''
    # Set home for npm
    export HOME=$TMPDIR

    # Install dependencies
    npm ci

    # Build the frontend (this creates a production build)
    cd client
    npm ci
    npm run build
    cd ..

    # Clean up development dependencies
    npm ci --omit=dev
  '';

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/lib/node_modules/librechat

    # Copy the backend and built frontend
    cp -r ./* $out/lib/node_modules/librechat/
    cp -r client/dist $out/lib/node_modules/librechat/client/dist

    # Create startup script
    cat > $out/bin/librechat << EOF
    #!${stdenv.shell}
    exec ${nodejs}/bin/node $out/lib/node_modules/librechat/api/server
    EOF
    chmod +x $out/bin/librechat
  '';

  meta = {
    description = "Self-hosted ChatGPT clone";
    homepage = "https://github.com/danny-avila/LibreChat";
    license = lib.licenses.mit;
    maintainers = [ "74k1" ];
    platforms = lib.platforms.unix;
  };
}
