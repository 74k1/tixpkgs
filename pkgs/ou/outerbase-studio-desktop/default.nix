{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}: let
  pname = "outerbase-studio-desktop";
  version = "0.1.29";

  src = fetchurl {
    url = "https://github.com/outerbase/studio-desktop/releases/download/v${version}/Outerbase-Studio-Linux-${version}.AppImage";
    name = "Outerbase-Studio-Linux-${version}.AppImage";
    hash = "sha256-ne2HRfn05Qt/7OBnng29dFYlYoHoq9Og2ZztaiNZiy4=";
  };
in
appimageTools.wrapType2 rec {
  inherit pname version src;

  extraInstallCommands = let
    contents = appimageTools.extractType2 {inherit pname version src;};
  in
    /*
    sh
    */
    ''
      mkdir -p "$out/share/applications"
      install -m 444 ${contents}/${meta.mainProgram}.desktop -t $out/share/applications
      substituteInPlace $out/share/applications/${pname}.desktop --replace-fail 'Exec=AppRun' 'Exec=${meta.mainProgram}'
      cp -r ${contents}/usr/share/icons $out/share
    '';

  meta = with lib; {
    description = "A lightweight Electron wrapper for the Outerbase Studio web version.";
    homepage = "https://www.outerbase.com/";
    license = licenses.agpl3Plus;
    maintainers = [maintainers."74k1"];
    mainProgram = "outerbase-studio-desktop";
    platforms = ["x86_64-linux"];
  };
}
