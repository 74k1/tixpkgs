{
  lib,
  stdenvNoCC,
  fetchFromGitLab,
  bash,
  coreutils,
  fzf,
  gawk,
  gnugrep,
  gnused,
  makeWrapper,
  mpc,
  procps,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mpdq";
  version = "2.4.5";

  src = fetchFromGitLab {
    domain = "gitlab.com";
    owner = "uriel1998";
    repo = "mpdq";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Trv8MmGKDkHVPN5jj4JYEkfigdiJLLgGQdt3fu0oeAE=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 mpdq $out/bin/mpdq

    wrapProgram $out/bin/mpdq \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          fzf
          gawk
          gnugrep
          gnused
          mpc
          procps
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Automatic MPD \"smart playlist\" creator with minimal but hackable setup";
    longDescription = ''
      mpdq autoqueues random tracks from an existing MPD music library with
      per-genre weighting, simple defaults, and repeat avoidance, to create a
      configurable "party mode" effect without relying on external services.
    '';
    homepage = "https://uriel1998.gitlab.io/mpdq/";
    changelog = "https://gitlab.com/uriel1998/mpdq/-/blob/master/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "mpdq";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.unix;
  };
})
