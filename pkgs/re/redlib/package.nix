{
  lib,
  cacert,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  pkg-config,
  zstd,
  cmake,
  git,
}:

let
  rev = "54cd683e61ac6b698703da6307f379895210c4a5";

  # Changes when a theme file changes, so browsers drop the cached stylesheet.
  themesHash = builtins.substring 0 7 (
    builtins.hashString "sha256" (
      lib.concatMapStrings builtins.readFile [
        ./snqnDark.css
        ./snqnLight.css
        ./snqnOled.css
      ]
    )
  );
in
rustPlatform.buildRustPackage {
  pname = "redlib";
  version = "latest-unstable-2026-11-22";

  src = fetchFromGitHub {
    owner = "Nachtalb";
    repo = "redlib";
    inherit rev;
    hash = "sha256-lXX3oxXGtpvUeSyrR2DfwNdCniZdJ1z8oCfp5AcBsH8=";
  };

  cargoHash = "sha256-Pubx+IBu6in1xG+rI9l+OtKUvbGkURlL4Hy77sVzSH8=";

  nativeBuildInputs = [
    pkg-config
    cmake
    git
    rustPlatform.bindgenHook
  ];
  buildInputs = [ zstd ];

  postPatch = ''
    cp ${./snqnDark.css} static/themes/snqnDark.css
    cp ${./snqnLight.css} static/themes/snqnLight.css
    cp ${./snqnOled.css} static/themes/snqnOled.css
    substituteInPlace src/utils.rs \
      --replace-fail '"rosebox" => "Rosebox",' '"rosebox" => "Rosebox",
        "snqnDark" => "snqn Dark",
        "snqnLight" => "snqn Light",
        "snqnOled" => "snqn OLED",'
    substituteInPlace templates/base.html \
      --replace-fail 'style.css?v={{ crate::utils::short_git_hash() }}' \
        'style.css?v={{ crate::utils::short_git_hash() }}-${themesHash}'
  '';

  postInstall = ''
    install --mode=444 -D contrib/redlib.service $out/lib/systemd/system/redlib.service
    substituteInPlace $out/lib/systemd/system/redlib.service \
      --replace-fail "/usr/bin/redlib" "$out/bin/redlib"
  '';

  checkFlags = [
    "--skip=backends::live_tests::"
    # These tests try to connect to Reddit.
    # utils.rs
    "--skip=test_fetching_subreddit_quarantined"
    "--skip=test_fetching_nsfw_subreddit"
    "--skip=test_fetching_ws"

    # client.rs
    "--skip=test_obfuscated_share_link"
    "--skip=test_share_link_strip_json"
    "--skip=test_localization_popular"
    "--skip=test_private_sub"
    "--skip=test_banned_sub"
    "--skip=test_gated_sub"
    "--skip=test_default_subscriptions"
    "--skip=test_rate_limit_check"

    # subreddit.rs
    "--skip=test_fetching_subreddit"
    "--skip=test_gated_and_quarantined"

    # user.rs
    "--skip=test_fetching_user"

    # These tests try to connect to the OAuth client.
    # oauth.rs
    "--skip=test_oauth_client"
    "--skip=test_oauth_client_refresh"
    "--skip=test_oauth_token_exists"
    "--skip=test_oauth_headers_len"
    "--skip=test_generic_web_backend"
    "--skip=test_mobile_spoof_backend"
  ];

  env = {
    # The source has no .git directory. Without this, every build reports "dev".
    GIT_HASH = rev;
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  passthru = {
    updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
  };

  meta = {
    description = "Private front-end for Reddit (Continued fork of Libreddit)";
    homepage = "https://github.com/Nachtalb/redlib";
    license = lib.licenses.agpl3Only;
    mainProgram = "redlib";
    maintainers = with lib.maintainers; [
      Guanran928
      _74k1
    ];
  };
}
