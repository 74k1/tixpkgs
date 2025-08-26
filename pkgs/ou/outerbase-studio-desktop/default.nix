{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:
let
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

  extraInstallCommands = /* sh */ ''
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${meta.mainProgram}'
  '';

  meta = with lib; {
    description = "A lightweight Electron wrapper for the Outerbase Studio web version.";
    homepage = "https://www.outerbase.com/";
    license = licenses.agpl3Plus;
    maintainers = [maintainers."74k1"];
    mainProgram = "Outerbase-Studio-Desktop";
    platforms = ["x86_64-linux"];
  };
}
