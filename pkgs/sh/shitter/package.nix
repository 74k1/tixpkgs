{
  lib,
  buildNimPackage,
  fetchFromGitea,
  fetchzip,
  pcre,
  unstableGitUpdater,
}:

let
  redpool = lib.findFirst (
    dependency: lib.elem "redpool" dependency.packages
  ) null (lib.importJSON ./lock.json).depends;
  redpoolSource = fetchzip {
    name = "source";
    inherit (redpool) url sha256;
  };
in
buildNimPackage (finalAttrs: {
  pname = "shitter";
  version = "0-unstable-2026-11-13";

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "shitter";
    repo = "shitter";
    rev = "b43f1d9a0d83b6e1b0e5937866f1123aa639a7ef";
    hash = "sha256-D+7/uhdpJNYw83JlI/RDGBq0tkv0WrFeSpH5dR2v61E=";
  };

  lockFile = ./lock.json;

  buildInputs = [ pcre ];

  # redpool connects over TCP only. This copy takes precedence over the locked
  # one, and connects to a Unix socket when `redisHost` is an absolute path.
  postPatch = ''
    cp ${redpoolSource}/${redpool.srcDir}/redpool.nim src/redpool.nim
    chmod u+w src/redpool.nim
    substituteInPlace src/redpool.nim \
      --replace-fail 'conn: await openAsync(pool.host, pool.port),' \
        "conn: (if pool.host.len > 0 and pool.host[0] == '/': await openUnixAsync(pool.host) else: await openAsync(pool.host, pool.port)),"
  '';

  nimFlags = [
    "--mm:refc"
    # nixpkgs' Nim refuses `std/pcre` without this flag, see pkgs/pc/pcre.
    "-d:usePcre"
    # Link libpcre at build time. Nim otherwise loads it by name at run time.
    "--dynlibOverride:pcre"
    "--passL:-lpcre"
    # The source has no .git directory, so the about page needs these values.
    "-d:gitHash=${lib.substring 0 7 finalAttrs.src.rev}"
    "-d:gitDate=${
      lib.replaceStrings [ "-" ] [ "." ] (lib.removePrefix "0-unstable-" finalAttrs.version)
    }"
  ];

  postBuild = ''
    nim compile ${toString finalAttrs.nimFlags} -r tools/gencss
    nim compile ${toString finalAttrs.nimFlags} -r tools/rendermd
  '';

  postInstall = ''
    mkdir -p $out/share/shitter
    cp -r public $out/share/shitter/public
  '';

  passthru.updateScript = unstableGitUpdater { };

  meta = {
    description = "Alternative Twitter front-end, fork of Nitter";
    homepage = "https://codeberg.org/shitter/shitter";
    license = lib.licenses.agpl3Only;
    mainProgram = "nitter";
    maintainers = with lib.maintainers; [ _74k1 ];
    platforms = lib.platforms.linux;
  };
})
