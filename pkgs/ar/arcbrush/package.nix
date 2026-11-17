{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "arcbrush";
  version = "1.7.4";

  src = fetchurl {
    url = "https://arcbrush.com/downloads/ArcBrush-${version}-x86_64.AppImage";
    hash = "sha256-jlHXOAc0i1v8Hg+uVaQ7lHjUpJ5zclmyGhstokqrm6c=";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands =
    let
      contents = appimageTools.extractType2 { inherit pname version src; };
    in
    ''
      mkdir -p "$out/share/applications" "$out/share/icons/hicolor/256x256/apps"
      install -m 444 ${contents}/com.arcbrush.ArcBrush.desktop -t $out/share/applications
      install -m 444 ${contents}/arcbrush.png -t $out/share/icons/hicolor/256x256/apps
    '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "Node-based image editor for palette-variant asset generation";
    homepage = "https://arcbrush.com";
    downloadPage = "https://arcbrush.com/downloads";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "arcbrush";
    platforms = [ "x86_64-linux" ];
  };
}
