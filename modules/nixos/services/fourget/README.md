# 4get

Donate to the project maintainer here: [https://4get.ca/donate](https://4get.ca/donate).

## Usage

`services.fourget` manages the 4get application files and PHP-FPM pool.
Nginx integration is optional.

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

If you enable nginx integration and want HTTPS, also set one of:

- `nginx.enableACME = true`
- `nginx.useACMEHost = "example.com"`
- your own manual certificate settings on `services.nginx.virtualHosts.<name>`

TLS mode options:

- `nginx.forceSSL = true` redirects HTTP to HTTPS
- `nginx.addSSL = true` serves both HTTP and HTTPS
- `nginx.onlySSL = true` serves HTTPS only

These three options are mutually exclusive.

If you already manage the web server yourself, leave `nginx.enable = false` and use:

- `config.services.fourget.webRoot` as the document root
- `config.services.fourget.socket` as the PHP-FPM socket

The module rewrites extensionless routes such as `/web` and `/settings` to the matching PHP
entrypoints when nginx integration is enabled.

Minimal external web server setup:

```nix
{
  services.fourget.enable = true;

  # Then point your web server at:
  # - document root: config.services.fourget.webRoot
  # - PHP-FPM socket: config.services.fourget.socket
}
```

Runtime state lives in `/var/lib/fourget` by default:

- cached favicons: `/var/lib/fourget/icons`
- proxy lists: `/var/lib/fourget/proxies`
- API key files: `/var/lib/fourget/api_keys`

Most upstream configuration can be passed through `services.fourget.settings` using the original
constant names from `data/config.php`.
Do not put secrets there; those values are written to the Nix store.

For Cloudflare-protected scrapers such as Yep, you can pass `LD_PRELOAD` and `CURL_IMPERSONATE`
through `services.fourget.environment`.

Direct `.php` paths are intentionally not rewritten by the module, because nginx config validation rejects
the common `return 301 $1` regex form as a possible HTTP-splitting issue.
