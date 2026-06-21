> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.ferroxide`

A third-party, open-source ProtonMail bridge for servers. Translates standard mail protocols (SMTP, IMAP, CardDAV, CalDAV) into ProtonMail API requests. Mainly intended for Server SMTP use like: `git-send-email`, or any standards-compliant client with your Proton inbox.

> [!WARNING]
> IMAP support is work-in-progress. Here be dragons.

Runs the [ferroxide](https://github.com/acheong08/ferroxide) fork of the original [hydroxide](https://github.com/emersion/hydroxide), adding CalDAV, Tor/proxy support, and a customisable config directory.

## Info

- Ferroxide source: <https://github.com/acheong08/ferroxide>
- Original hydroxide source: <https://github.com/emersion/hydroxide>
- License: MIT

## Prerequisites / getting `auth.json`

Before enabling the module you must log in to ProtonMail through ferroxide **once** to generate an encrypted credential file:

```bash
ferroxide auth <username>
```

This asks for your ProtonMail password (and 2FA TOTP code if enabled) and your mailbox password, then prints a **bridge password**. Save that password, it is the password you'll configure in every mail client.

The command writes `~/.config/ferroxide/auth.json`. Copy that file to your server (e.g. `/var/secrets/ferroxide-auth.json`) and protect it (or use agenix / sops-nix):

```bash
chmod 600 /var/secrets/ferroxide-auth.json
```

## Usage

>[!INFO]
> Each service (smtp, imap, carddav, caldav) is DISABLED by default.

Default service ports: SMTP **1025**, IMAP **1143**, CardDAV **8080**, CalDAV **8081**.

### All four services with defaults

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.ferroxide
    # or
    inputs.tixpkgs.nixosModules."services/ferroxide"
  ];

  services.ferroxide = {
    enable = true;
    authFile = "/var/secrets/ferroxide-auth.json";
    serve = {
      smtp    = true;
      imap    = true;
      carddav = true;
      caldav  = true;
    };
  };
}
```

### Expose to the LAN with custom ports

```nix
services.ferroxide = {
  enable = true;
  authFile = "/var/secrets/ferroxide-auth.json";
  serve = {
    smtp    = { host = "0.0.0.0"; port = 587; };
    imap    = { host = "0.0.0.0"; port = 993; };
    carddav = { host = "0.0.0.0"; port = 8080; };
    caldav  = { host = "0.0.0.0"; port = 8081; };
  };
};
```

Each `serve` entry accepts `enable = true` / `enable = false` OR an attrset. Inside the attrset `enable` defaults to `true`, so `{ host = "0.0.0.0"; }` is enough to change only the bind address.

### SMTP + IMAP only (no CardDAV/CalDAV)

```nix
services.ferroxide = {
  enable = true;
  authFile = "/var/secrets/ferroxide-auth.json";
  serve = {
    smtp = true;
    imap = true;
    # carddav and caldav default to false
  };
};
```

### Over Tor

```nix
services.ferroxide = {
  enable = true;
  authFile = "/var/secrets/ferroxide-auth.json";
  proxyUrl = "socks5://127.0.0.1:9050";
  tor = true;
  serve.imap = true;
};
```

When `tor = true` the API endpoint is automatically switched to ProtonMail's `.onion`.

All four services run inside a single `ferroxide serve` process under a systemd `DynamicUser` with full sandboxing.

- Config home: `/var/lib/ferroxide` (systemd `StateDirectory`)
- Auth file: `/var/lib/ferroxide/ferroxide/auth.json` (copied from `authFile` at startup)
