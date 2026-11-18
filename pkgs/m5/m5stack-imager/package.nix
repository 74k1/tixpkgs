{
  lib,
  appimageTools,
  fetchurl,
  stdenv,
}:

let
  pname = "m5stack-imager";
  version = "3.0.0";

  assets = {
    x86_64-linux = {
      arch = "x64";
      hash = "sha256-eLa636JLxX3fSnDLxQtY61nhC+mIBVpcwa7O+An5m6U=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-4eRAX02sG52Sr3AKJN99cqL/tMuHzLET3Ax5UESRK3M=";
    };
  };
  asset = assets.${stdenv.hostPlatform.system};

  src = fetchurl {
    url = "https://github.com/CardputerZero/m5stack-imager/releases/download/v${version}/M5-Imager-${version}-linux-${asset.arch}.AppImage";
    inherit (asset) hash;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands =
    let
      contents = appimageTools.extract { inherit pname version src; };
    in
    ''
      install -Dm644 ${contents}/rpi-imager.svg "$out/share/icons/hicolor/scalable/apps/${pname}.svg"
      desktop="$out/share/applications/${pname}.desktop"
      install -Dm644 ${contents}/com.raspberrypi.rpi-imager.desktop "$desktop"
      substituteInPlace "$desktop" \
        --replace-fail 'Exec=/usr/bin/rpi-imager' "Exec=$out/bin/${pname}" \
        --replace-fail 'Icon=rpi-imager' 'Icon=${pname}'
    '';

  meta = {
    description = "Desktop firmware flasher for M5Stack devices";
    homepage = "https://github.com/CardputerZero/m5stack-imager";
    downloadPage = "https://github.com/CardputerZero/m5stack-imager/releases";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = pname;
    platforms = builtins.attrNames assets;
  };
}
