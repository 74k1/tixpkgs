{
  lib,
  stdenvNoCC,
  nodejs,
  typescript,
  bun,
  fetchFromGitHub,
  buildNpmPackage,
  node-gyp,
  python3,
  zstd,
}:

let
  version = "2.7.0";

  src = fetchFromGitHub {
    owner = "rybbit-io";
    repo = "rybbit";
    rev = "v${version}";
    hash = "sha256-JRCkJhNDtfLBCKkFhVg5pFvfod12J7QRYO3Gv6JCGjg=";
  };

  rybbit-shared = stdenvNoCC.mkDerivation {
    pname = "rybbit-shared";
    inherit version src;

    sourceRoot = "source/shared";

    nativeBuildInputs = [
      nodejs
      typescript
    ];

    buildPhase = ''
      runHook preBuild
      tsc
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist $out/
      cp package.json $out/
      runHook postInstall
    '';
  };

  rybbit-client = buildNpmPackage {
    pname = "rybbit-client";
    inherit version src;

    sourceRoot = "source/client";

    npmDepsHash = "sha256-e3hHfTq77XNi5J90H2IhQtyC2Kl822Opyf2l438rB4E=";
    npmFlags = [ "--legacy-peer-deps" ];

    postPatch = ''
            sed -i \
              -e '/import { Inter } from "next\/font\/google";/d' \
              -e 's/const inter = Inter({ subsets: \["latin"\] });/const inter = { className: "" };/' \
              src/app/layout.tsx

            sed -i '/^};$/i\
        async rewrites() {\
          return [\
            {\
              source: "/api/:path*",\
              destination: "http://127.0.0.1:3001/api/:path*",\
            },\
          ];\
        },
      ' next.config.ts

            sed -i \
              -e '/import { Tilt_Warp } from "next\/font\/google";/d' \
              -e '/const tilt_wrap = Tilt_Warp({/,/});/c\const tilt_wrap = { className: "" };' \
              'src/app/[site]/main/components/MainSection/MainSection.tsx'

            sed -i \
              -e '/import { Tilt_Warp } from "next\/font\/google";/d' \
              -e '/const tilt_wrap = Tilt_Warp({/,/});/c\const tilt_wrap = { className: "" };' \
              'src/app/[site]/performance/components/PerformanceChart.tsx'
    '';

    postConfigure = ''
      rm -rf node_modules/@rybbit/shared
      mkdir -p node_modules/@rybbit/shared
      cp -r ${rybbit-shared}/dist node_modules/@rybbit/shared/
      cp ${rybbit-shared}/package.json node_modules/@rybbit/shared/
    '';

    env = {
      NEXT_TELEMETRY_DISABLED = "1";
      NEXT_PUBLIC_BACKEND_URL = "";
      NEXT_PUBLIC_DISABLE_SIGNUP = "false";
    };

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/rybbit-client
      cp -r .next/standalone/. $out/share/rybbit-client/
      cp -r .next/static $out/share/rybbit-client/.next/static
      cp -r public $out/share/rybbit-client/public

      runHook postInstall
    '';
  };

in
buildNpmPackage {
  pname = "rybbit";
  inherit version src;

  sourceRoot = "source/server";

  npmDepsHash = "sha256-0hRXtmNmUGPwnlqUDBxlkv8kzIzN0Lof6/n9pSA27XA=";

  npmRebuildFlags = [ "--ignore-scripts" ];

  npmFlags = [ "--legacy-peer-deps" ];

  nativeBuildInputs = [
    node-gyp
    python3
  ];

  buildInputs = [
    zstd.dev
    zstd.out
  ];

  postConfigure = ''
    rm -rf node_modules/@rybbit/shared
    mkdir -p node_modules/@rybbit/shared
    cp -r ${rybbit-shared}/dist node_modules/@rybbit/shared/
    cp ${rybbit-shared}/package.json node_modules/@rybbit/shared/

    substituteInPlace node_modules/@mongodb-js/zstd/binding.gyp \
      --replace-fail "<(module_root_dir)/deps/zstd/lib" "${zstd.dev}/include" \
      --replace-fail "<(module_root_dir)/deps/zstd/out/lib/libzstd.a" "${zstd.out}/lib/libzstd.so"

    pushd node_modules/@mongodb-js/zstd
    node-gyp rebuild --nodedir=${nodejs}
    popd

    sed -i "s/port: 3001/port: parseInt(process.env.PORT || '3001')/g" src/index.ts
  '';

  installPhase = ''
        runHook preInstall

        mkdir -p $out/share/rybbit-server $out/share/rybbit-client $out/bin

        cp -r ${rybbit-client}/share/rybbit-client/. $out/share/rybbit-client/

        cp -r dist $out/share/rybbit-server/
        cp -r public $out/share/rybbit-server/
        cp -r drizzle $out/share/rybbit-server/
        cp drizzle.config.ts $out/share/rybbit-server/
        cp package.json $out/share/rybbit-server/
        cp GeoLite2-City.mmdb $out/share/rybbit-server/
        cp -r node_modules $out/share/rybbit-server/
        cp -r src $out/share/rybbit-server/

        cat > $out/bin/rybbit-server <<WRAPPER
    #!/bin/sh
    cd $out/share/rybbit-server
    exec ${bun}/bin/bun $out/share/rybbit-server/dist/index.js "\$@"
    WRAPPER
        chmod +x $out/bin/rybbit-server

        cat > $out/bin/rybbit-server-cluster <<WRAPPER
    #!/bin/sh
    cd $out/share/rybbit-server
    exec ${bun}/bin/bun $out/share/rybbit-server/dist/cluster.js "\$@"
    WRAPPER
        chmod +x $out/bin/rybbit-server-cluster

        cat > $out/bin/rybbit-client <<WRAPPER
    #!/bin/sh
    cd $out/share/rybbit-client
    export NODE_ENV=production
    export NEXT_TELEMETRY_DISABLED=1
    export PORT="\''${PORT:-3002}"
    export HOSTNAME="\''${HOSTNAME:-127.0.0.1}"
    exec ${nodejs}/bin/node $out/share/rybbit-client/server.js "\$@"
    WRAPPER
        chmod +x $out/bin/rybbit-client

        runHook postInstall
  '';

  passthru = {
    inherit rybbit-client rybbit-shared;
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "Open-source and privacy-friendly alternative to Google Analytics that is 10x more intuitive";
    homepage = "https://rybbit.com/";
    license = licenses.agpl3Only;
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "rybbit-server";
    platforms = platforms.linux;
  };
}
