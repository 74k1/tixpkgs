> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.hydroxide`

A third-party, open-source ProtonMail bridge for servers. Translates standard mail protocols (SMTP, IMAP, CardDAV) into ProtonMail API requests. Mainly intended for Server SMTP use like: `git-send-email`, or any standards-compliant client with your Proton inbox.

Runs the upstream [hydroxide](https://codeberg.org/emersion/hydroxide) bridge (also mirrored at [github.com/emersion/hydroxide](https://github.com/emersion/hydroxide)), packaged in nixpkgs — no CalDAV here; for that see the [ferroxide](https://github.com/acheong08/ferroxide) fork, still packaged in this flake.

## Info

- hydroxide source: <https://codeberg.org/emersion/hydroxide>
- License: MIT
- Package: `pkgs.hydroxide` (from nixpkgs, overridable via `services.hydroxide.package`)

## Prerequisites / getting `auth.json`

Before enabling the module you must log in to ProtonMail through hydroxide **once** to generate an encrypted credential file:

```bash
hydroxide auth <username>
```

This asks for your ProtonMail password (and 2FA TOTP code if enabled) and your mailbox password, then prints a **bridge password**. Save that password, it is the password you'll configure in every mail client.

The command writes `~/.config/hydroxide/auth.json`. Copy that file to your server (e.g. `/var/secrets/hydroxide-auth.json`) and protect it (or use agenix / sops-nix):

```bash
chmod 600 /var/secrets/hydroxide-auth.json
```

Other useful commands: `hydroxide status` lists logged-in users, and `hydroxide export-secret-keys <username>` / `hydroxide export-messages` exist for backups/migration.

## Usage

>[!INFO]
> Each service (smtp, imap, carddav) is DISABLED by default.

Default service ports: SMTP **1025**, IMAP **1143**, CardDAV **8080**.

### All three services with defaults

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.hydroxide
    # or
    inputs.tixpkgs.nixosModules."services/hydroxide"
  ];

  services.hydroxide = {
    enable = true;
    authFile = "/var/secrets/hydroxide-auth.json";
    serve = {
      smtp    = true;
      imap    = true;
      carddav = true;
    };
  };
}
```

### Expose to the LAN with custom ports

```nix
services.hydroxide = {
  enable = true;
  authFile = "/var/secrets/hydroxide-auth.json";
  serve = {
    smtp    = { host = "0.0.0.0"; port = 587; };
    imap    = { host = "0.0.0.0"; port = 993; };
    carddav = { host = "0.0.0.0"; port = 8080; };
  };
};
```

Each `serve` entry accepts `enable = true` / `enable = false` OR an attrset. Inside the attrset `enable` defaults to `true`, so `{ host = "0.0.0.0"; }` is enough to change only the bind address.

### SMTP only (e.g. for `git-send-email`)

```nix
services.hydroxide = {
  enable = true;
  authFile = "/var/secrets/hydroxide-auth.json";
  serve.smtp = true;
};
```

### TLS

Set `services.hydroxide.tls.certFile` / `tls.keyFile` to enable TLS on all listeners; without it servers allow insecure auth. Add `tls.clientCAFile` to require client certificates (mTLS).

The service runs as a single `hydroxide serve` process under a systemd `DynamicUser` with full sandboxing.

- Config home: `/var/lib/hydroxide` (systemd `StateDirectory`, exported to the binary as `XDG_CONFIG_HOME`)
- Auth file: `/var/lib/hydroxide/hydroxide/auth.json` (copied from `authFile` at startup)
