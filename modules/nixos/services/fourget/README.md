# 4get search

- Project Source: `https://git.lolcat.ca/lolcat/4get/`
- Project Maintainer: `https://git.lolcat.ca/lolcat`
- Donate to the Project here: `https://4get.ca/donate`

> [!NOTE]
> This Module _might_ not have all the capabilities you'd want. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
> 
> Contributions are always welcome!

## Usage

```nix
{
  services.fourget = {
    enable = true;

    nginx = {
      enable = true;
      hostName = "search.example.com";
      enableACME = true;
      forceSSL = true;
      openFirewall = true;
    };

    settings = {
      SERVER_NAME = "Example 4get";
      SERVER_LONG_DESCRIPTION = "Private search instance";
      ALT_ADDRESSES = [ "https://search-alt.example.com" ];
    };

    environment = {
      # Optional: needed for some Cloudflare-protected scrapers such as Yep.
      LD_PRELOAD = "/usr/local/lib/libcurl-impersonate-ff.so";
      CURL_IMPERSONATE = "firefox117";
    };
  };
}
```

This will setup an nginx virtualHost with `hostName`.

If you already manage the web server yourself, leave `nginx.enable = false` and use:

- `config.services.fourget.webRoot` as the document root
- `config.services.fourget.socket` as the PHP-FPM socket

The module rewrites extensionless routes such as `/web` and `/settings` to the matching PHP entrypoints when nginx integration is enabled.

## Notes

Runtime state lives in `/var/lib/fourget`.

- cached favicons: `/var/lib/fourget/icons`
- proxy lists: `/var/lib/fourget/proxies`
- API key files: `/var/lib/fourget/api_keys`

Most upstream configuration can be passed through `services.fourget.settings` using the original constant names from `data/config.php`.

Do not put secrets there; those values are written to the Nix store.

For Cloudflare-protected scrapers such as Yep, you can pass `LD_PRELOAD` and `CURL_IMPERSONATE` through `services.fourget.environment`.
