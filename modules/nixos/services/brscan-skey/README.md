> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.brscan-skey`

Brother Scan-key-tool daemon for starting scans from the hardware scan button on Brother MFC/scanner devices.

## Info

- Project Website: `https://support.brother.com/`
- Download Page: `https://support.brother.com/g/b/downloadhowto.aspx?c=us&lang=en&prod=mfcl3770cdw_us_eu_as&os=127&dlid=dlf006650_000&flang=4&type3=568`

## Usage

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.brscan-skey
    # or
    inputs.tixpkgs.nixosModules."services/brscan-skey"
  ];

  services.brscan-skey.enable = true;

  # Optional: override the commands run for each scanner button action.
  # services.brscan-skey.imageScript = "scan-to-image";
  # services.brscan-skey.ocrScript = "scan-to-ocr";
  # services.brscan-skey.emailScript = "scan-to-email";
  # services.brscan-skey.fileScript = "scan-to-file";
}
```

## Notes

The module creates a `brscan-skey.service`, a `brscan-skey` system user/group, and writes `/etc/brscan-skey/brscan-skey.config`.

By default the button actions use the scripts shipped by the `brscan-skey` package. You probably still need the matching Brother scanner/SANE driver and device setup separately for your scanner model.
