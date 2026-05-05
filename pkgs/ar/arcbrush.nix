{ lib
, appimageTools
, fetchurl
}:

let
  pname = "arcbrush";
  version = "1.1.0";

  src = fetchurl {
    url = "https://arcbrush.com/downloads/ArcBrush-${version}-x86_64.AppImage";
    hash = "sha256-sH+JSywhTwU8gCkJQxXp1ij/zsfAI+y9tggeWVIufh0=";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = let
    contents = appimageTools.extractType2 { inherit pname version src; };
  in ''
    mkdir -p "$out/share/applications" "$out/share/icons/hicolor/256x256/apps"
    install -m 444 ${contents}/arcbrush.desktop -t $out/share/applications
    install -m 444 ${contents}/arcbrush.png -t $out/share/icons/hicolor/256x256/apps
  '';

  meta = with lib; {
    description = "Node-based image editor for palette-variant asset generation";
    homepage = "https://arcbrush.com";
    downloadPage = "https://arcbrush.com/downloads";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ "74k1" ];
    mainProgram = "arcbrush";
    platforms = [ "x86_64-linux" ];
  };
}
