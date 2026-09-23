{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  lsp-plugins,
  bankstown-lv2,
}:

stdenvNoCC.mkDerivation {
  pname = "gpd-pocket-4-pipewire";
  version = "0-unstable-2025-04-08";

  # Last upstream commit; there are no tags.
  src = fetchFromGitHub {
    owner = "Manawyrm";
    repo = "gpd-pocket-4-pipewire";
    rev = "4709659fcb4d4f77a852916e13655bb6174cc0e4";
    hash = "sha256-sC+/oIIKT9cyINmfdAXE0Qb18jeT6e8mtJi2cWHPYEQ=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 pipewire.conf.d/sink-gpd-pocket-4.conf \
      "$out/share/pipewire/pipewire.conf.d/sink-gpd-pocket-4.conf"
    install -Dm644 \
      pipewire.conf.d/gpd-pocket-4-mp-48k-l.wav \
      pipewire.conf.d/gpd-pocket-4-mp-48k-r.wav \
      "$out/share/pipewire/pipewire.conf.d/"
    install -Dm644 LICENSE "$out/share/doc/gpd-pocket-4-pipewire/LICENSE"

    # Upstream hardcodes the Arch FHS path for the impulse responses.
    substituteInPlace "$out/share/pipewire/pipewire.conf.d/sink-gpd-pocket-4.conf" \
      --replace-fail '/usr/share/pipewire/pipewire.conf.d' \
      "$out/share/pipewire/pipewire.conf.d"

    runHook postInstall
  '';

  # Consumed by services.pipewire.configPackages via
  # passthru.requiredLv2Packages, which feeds the pipewire unit's LV2_PATH.
  passthru.requiredLv2Packages = [
    lsp-plugins
    bankstown-lv2
  ];

  meta = {
    description = "PipeWire speaker DSP profile (convolution EQ, bankstown) for the GPD Pocket 4";
    homepage = "https://github.com/Manawyrm/gpd-pocket-4-pipewire";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ _74k1 ];
  };
}
