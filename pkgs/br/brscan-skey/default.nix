{
  lib,
  stdenv,
  fetchurl,
  perl,
  rpmextract,
  sane-backends,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "brscan-skey";
  version = "0.3.5-0";

  src = fetchurl {
    url = "https://download.brother.com/welcome/dlf006650/brscan-skey-${finalAttrs.version}.x86_64.rpm";
    hash = "sha256-AdyFnxl45kUUfO1exLVEjMPiaxxtLxEEg09YkcDhdGk=";
  };

  passthru.updateScript = ./update.sh;

  nativeBuildInputs = [
    rpmextract
    autoPatchelfHook
    perl
  ];

  buildInputs = [
    sane-backends
  ];

  unpackPhase = ''
    rpmextract $src
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/brscan-skey
    cp -r opt/brother/scanner/brscan-skey/* $out/lib/brscan-skey/
    rm $out/lib/brscan-skey/brscan-skey

    cat > $out/bin/brscan-skey <<'WRAPPER'
    #!/bin/sh
    set -e

    exe="@exe@"

    show_help() {
      cat <<'EOF'
    Usage: brscan-skey [option]

    This tool enables you to scan a document by using the
    Scan key on the Brother MFC.

      no option                :register all network MFCs
      -t (--terminate)         :terminate this tool
      -a (--add) MFC           :register the specified MFC
      -d (--delete) MFC        :exclude the specified MFC
      -p (--passwd) PASSWORD   :set the password
      -u (--username) USERNAME :set the user name
      -l (--list)              :list the available MFCs
      -m (--mailto) ADDRESS    :mail address (scan to e-mail)
      --refresh                :refresh settings
      --diagnosis              :print diagnosis data
      -h --help                :this help
    EOF
    }

    case "''${1:-}" in
      -h|--help) show_help; exit 0 ;;
      -l|--list|-t|--terminate|--refresh|--diagnosis) exec "$exe" "$@"; ;;
      -a|--add|-d|--delete|-p|--passwd|-u|--username|-m|--mailto) exec "$exe" "$@"; ;;
      -f) exec "$exe" "$@"; ;;
      *) "$exe" "$@" & ;;
    esac
    WRAPPER

    substituteInPlace $out/bin/brscan-skey \
      --replace-fail "@exe@" "$out/lib/brscan-skey/brscan-skey-exe"

    chmod +x $out/bin/brscan-skey

    substituteInPlace $out/lib/brscan-skey/brscan-skey.config \
      --replace-fail "/opt/brother/scanner/brscan-skey" "$out/lib/brscan-skey"

    substituteInPlace $out/lib/brscan-skey/brscan_mail.config \
      --replace-fail "/opt/brother/scanner/brscan-skey" "$out/lib/brscan-skey"

    for script in $out/lib/brscan-skey/script/*.sh; do
      substituteInPlace "$script" \
        --replace-fail "/etc//opt/brother/scanner/brscan-skey" "/etc/brscan-skey" \
        --replace-fail "/opt/brother/scanner/brscan-skey" "$out/lib/brscan-skey"
    done

    substituteInPlace $out/lib/brscan-skey/mk_mailmessage.sh \
      --replace-fail "/etc//opt/brother/scanner/brscan-skey" "/etc/brscan-skey"

    chmod +x $out/lib/brscan-skey/script/*.sh
    chmod +x $out/lib/brscan-skey/mk_mailmessage.sh

    perl -pi -e '
      $o="/opt/brother/scanner/brscan-skey/brscan-skey.config";
      $n="/etc/brscan-skey/brscan-skey.config";
      $n .= "\0" x (length($o) - length($n));
      s/\Q$o\E/$n/g;
    ' $out/lib/brscan-skey/brscan-skey-exe

    runHook postInstall
  '';

  meta = {
    description = "Brother scan-key-tool";
    homepage = "http://support.brother.com/";
    license = lib.licenses.unfree;
    maintainers = [ "74k1" ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "brscan-skey";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
