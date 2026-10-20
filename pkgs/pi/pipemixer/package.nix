{
  lib,
  inih,
  meson,
  ninja,
  stdenv,
  ncurses,
  pipewire,
  pkg-config,
  fetchFromGitHub,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "pipemixer";
  version = "0.5.1";

  src = fetchFromGitHub {
    owner = "heather7283";
    repo = "pipemixer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-dVw8x9c3DFSL5eLbBOe7ExNzeKsj3xB5Spl516XFqTQ=";
  };

  strictDeps = true;

  depsBuildBuild = [
    pkg-config
  ];

  buildInputs = [
    inih
    ncurses
    pipewire
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  meta = {
    description = "TUI volume control app for pipewire";
    homepage = "https://github.com/heather7283/pipemixer";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "pipemixer";
    platforms = [ "x86_64-linux" ];
  };
})
