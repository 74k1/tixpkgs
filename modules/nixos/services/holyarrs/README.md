> [!IMPORTANT]
> This module might not cover everything you need. If you run into missing options or rough edges, please [open an issue](https://github.com/74k1/tixpkgs/issues) or send a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.holyarrs`

HolyArrs is one self-hosted app for shows, movies, music, subtitles and requests.
It does the work of Sonarr, Radarr, Lidarr, Prowlarr, Bazarr and Seerr in one Go process with one SQLite library database.
It does not download by itself. It sends releases to your download client (qBittorrent, SABnzbd, Transmission, NZBGet, Deluge, rTorrent or aria2).

## Info

- Project Website: `https://holyarrs.com/`
- Project Source: `https://github.com/HolyArrs/HolyArrs`
- Project Docs: `https://docs.holyarrs.com/`

## Quick start

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.holyarrs
    # or
    inputs.tixpkgs.nixosModules."services/holyarrs"
  ];

  services.holyarrs = {
    enable = true;
    mediaDirs = [
      "/srv/media"
      "/srv/downloads"
    ];
  };
}
```

This starts HolyArrs on `127.0.0.1:6262`.
Open it and finish the setup wizard: folders, a downloader and a source.

The first visitor of a fresh install becomes the owner.
Make the owner at start (see [First start without the wizard](#first-start-without-the-wizard)) before you expose HolyArrs to other people.

To reach it from the local network:

```nix
services.holyarrs = {
  address = "0.0.0.0";
  openFirewall = true;
};
```

## Media folders

The service sees the file system as read-only, except for `dataDir` and the folders in `mediaDirs`.
`/home` is hidden.
Put every library folder and the downloader's save folder in `mediaDirs`, or HolyArrs cannot import or organise files.

```nix
services.holyarrs = {
  mediaDirs = [
    "/srv/media"
    "/srv/downloads"
  ];
  # The save folder as the downloader sees it. HolyArrs sends it with every download.
  savePath = "/srv/downloads";
  # Keep new files writable for the group.
  umask = "0002";
};

users.users.holyarrs.extraGroups = [ "media" ];
```

The folders must exist before the service starts.
The `holyarrs` user also needs file permissions on them.
A shared group for HolyArrs, the downloader and the media server is the usual setup.
Keep downloads and library folders on one file system, so files move or hardlink instead of copy.

## First start without the wizard

The module can make the owner and an API key at start, so no browser is needed and nobody can claim a fresh install first.

```nix
services.holyarrs = {
  ownerName = "admin";
  ownerPasswordFile = "/run/secrets/holyarrs-owner-password";
  apiKeyFile = "/run/secrets/holyarrs-api-key";
};
```

Make the files once:

```bash
umask 077
printf '%s\n' 'your owner password' > /run/secrets/holyarrs-owner-password
echo "hak_$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=')" > /run/secrets/holyarrs-api-key
```

- HolyArrs reads the password file only while there is no owner. Once an owner exists, `ownerName` and `ownerPasswordFile` change nothing.
- The API key must be `hak_` and 43 URL-safe base64 characters. A key in another format stops the start, and the page says why.
- `apiKeyScopes` sets the scopes of that key. The default is `all`. Send the key in the `X-Api-Key` header.

All secret files in this module (`ownerPasswordFile`, `apiKeyFile`, `masterKeyFile`, `oidc.clientSecretFile`, `metadata.tmdbKeyFile`) are loaded as systemd credentials (`LoadCredential`).
Systemd reads them as root before the sandbox starts, so they do not need to be readable by the `holyarrs` user.
This makes them usable directly with agenix or sops-nix.
Keep the files in place: the service does not start when one of them is missing.

## Master key

HolyArrs encrypts stored passwords and API keys with a master key.
By default it makes `holyarrs.key` in `dataDir` on the first start.
Backups never hold the master key. Without the matching key, a restored backup cannot read the stored secrets.

To manage the key yourself:

```nix
services.holyarrs.masterKeyFile = "/run/secrets/holyarrs-master-key";
```

Generate it once:

```bash
openssl rand -base64 32 | install -m 600 /dev/stdin /run/secrets/holyarrs-master-key
```

To move an existing install to `masterKeyFile`, copy the content of `dataDir/holyarrs.key` into the new file.
A new key cannot open secrets that the old key stored.

## Behind a reverse proxy

The module does not configure a reverse proxy.
Point your own proxy at `address:port`.

```nix
services.holyarrs = {
  allowedHosts = [ "holyarrs.example.com" ];
  trustedProxies = [ "127.0.0.1" ];
};

services.nginx.virtualHosts."holyarrs.example.com" = {
  forceSSL = true;
  enableACME = true;
  locations."/" = {
    proxyPass = "http://127.0.0.1:6262";
    # Live updates use server-sent events.
    extraConfig = ''
      proxy_buffering off;
      proxy_read_timeout 1h;
    '';
  };
};
```

- `allowedHosts`: HolyArrs accepts IP addresses and `localhost` only. Add every host name people use to reach it.
- `trustedProxies`: without it, single sign-on, real client addresses and the Secure cookie do not work behind the proxy.

To serve HolyArrs under a path, set `urlBase`.
The proxy must pass the path on unchanged, so do not strip it:

```nix
services.holyarrs.urlBase = "/holyarrs";

services.nginx.virtualHosts."home.example.com".locations."/holyarrs" = {
  proxyPass = "http://127.0.0.1:6262";
  extraConfig = ''
    proxy_buffering off;
    proxy_read_timeout 1h;
  '';
};
```

When `urlBase` is set, the path saved in **Settings > This app** is ignored.

## Single sign-on

### OpenID Connect

```nix
services.holyarrs = {
  trustedProxies = [ "127.0.0.1" ];
  oidc = {
    enable = true;
    issuer = "https://auth.example.com/application/o/holyarrs/";
    clientId = "holyarrs";
    clientSecretFile = "/run/secrets/holyarrs-oidc-client-secret";
    redirectUrl = "https://holyarrs.example.com/api/v1/auth/oidc/callback";
    allowJoin = true;
    groupsClaim = "groups";
    groupRoles = {
      admins = "admin";
      family = "member";
    };
  };
};
```

- `redirectUrl` must be your address, then `urlBase` if set, then `/api/v1/auth/oidc/callback`.
- When `oidc.enable` is true, Settings only show single sign-on. When it is false, the module sets nothing and you can set up single sign-on in Settings.
- `oidc.allowLocalNetwork` and `oidc.allowLoopbackHttp` also apply to single sign-on set up in Settings.

A bad setup stops HolyArrs from starting. The log says why.

### Trusted proxy sign-in

For a proxy that signs people in itself and passes the name on:

```nix
services.holyarrs.forwardAuth = {
  enable = true;
  issuer = "https://auth.example.com";
  trustedPeers = [ "127.0.0.1" ];
  allowJoin = true;
};
```

- The proxy must strip incoming `Remote-User` and `Remote-Name` headers and set its own after sign-in.
- `Remote-User` is one stable name. `Remote-Name` is an optional display name.
- `trustedPeers` must not be an all-address range such as `0.0.0.0/0`.
- Trusted proxy sign-in shows as a button on the sign-in page. A visit never signs anyone in from headers alone.

## Metadata

Titles, artwork and charts come from the HolyArrs metadata server by default, with no sign-up.
To use your own TMDB read access token instead:

```nix
services.holyarrs.metadata = {
  mode = "own";
  tmdbKeyFile = "/run/secrets/holyarrs-tmdb-key";
};
```

When `metadata.mode` is set, it locks the choice in **Settings > Metadata**.
See [what is sent](https://docs.holyarrs.com/library/metadata/) to the metadata server.

## Updates

The package is built without the in-app installer.
HolyArrs never installs a version itself. Nix owns the version.
HolyArrs still tells you when a new version is out. To turn that check off:

```nix
services.holyarrs.updateCheck = false;
```

Before a new version changes how data is stored, HolyArrs makes a backup.
To go back to an older version, see [Commands](#commands).

## Extra settings

The remaining upstream variables go through `environment` or `environmentFile`.
See the [upstream reference](https://docs.holyarrs.com/reference/env-vars/) for all variables.

```nix
services.holyarrs.environment = {
  # Use video and music files that are symlinks.
  HOLYARRS_FOLLOW_LINKS = "1";
  # Downloaders HolyArrs must never change, by ID or address.
  HOLYARRS_READONLY_DOWNLOADERS = "http://127.0.0.1:8080";
  # Start only the core: sign-in, library, settings, backups and health.
  HOLYARRS_SAFE_MODE = "1";
  # Force low-memory mode on (1) or off (0).
  HOLYARRS_LOW_MEMORY = "0";
};
```

Values in `environment` land in the Nix store.
Put secrets in `environmentFile` instead.
It uses the systemd format (`KEY=value`, one per line, no shell syntax) and is read by systemd as root.

Any variable can also come from a file: put `FILE__` in front of its name and give the file path as the value.
The `holyarrs` user must be able to read that file.

To trust your own certificate authority for outgoing HTTPS, put its PEM files in `dataDir/certs/` and restart HolyArrs.

## Commands

The `holyarrs` program has commands for recovery.
Run them as the service user and give the config folder.

```bash
# Check the config folder, database and folders.
sudo -u holyarrs holyarrs doctor -config /var/lib/holyarrs

# Set the owner's name and password when the password is lost.
sudo -u holyarrs holyarrs reset-owner -config /var/lib/holyarrs

# Put back the data from before the last update.
systemctl stop holyarrs
sudo -u holyarrs holyarrs restore -config /var/lib/holyarrs --pre-update
systemctl start holyarrs
```

With `masterKeyFile` set, the `restore` and `doctor` commands also need `HOLYARRS_MASTER_KEY_FILE` set to a copy of the key that the `holyarrs` user can read.

To go back to an older version, roll back the system first, then put back the pre-update data.
An older version that finds data from a newer version shows a page instead of the app until you do.
The newer data moves to `dataDir/backups/before-restore-<time>/`, so a restore can be undone.

## Data layout

| Path | Purpose |
|---|---|
| `dataDir/holyarrs.db` | Library, settings, users and history |
| `dataDir/holyarrs-events.db` | Events and activity |
| `dataDir/holyarrs.key` | Master key, when `masterKeyFile` is not set |
| `dataDir/backups/` | Scheduled backups and backups before updates |
| `dataDir/artwork/` | Picture cache |
| `dataDir/languages/` | Language packs |
| `dataDir/logs/` | Logs |

`dataDir` defaults to `/var/lib/holyarrs`.
HolyArrs refuses network shares (NFS, SMB), FUSE folders and memory-backed folders for `dataDir`.
Keep it on a local disk. Media folders can stay on a share.

## Hardening

The service runs with a hardened systemd unit:

- `ProtectSystem = "strict"`, and only `dataDir` and `mediaDirs` are writable.
- `ProtectHome = true`, so media folders under `/home` are not visible.
- `CapabilityBoundingSet = ""`, `NoNewPrivileges = true`, `RestrictSUIDSGID = true`.
- `MemoryDenyWriteExecute`, `LockPersonality`, `PrivateDevices`, `PrivateTmp`, `ProtectProc = "invisible"`, `RemoveIPC`.
- `RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_NETLINK" "AF_UNIX" ]`, `RestrictNamespaces`, `RestrictRealtime`.
- `SystemCallFilter = [ "@system-service" "~@privileged" ]` with `SystemCallErrorNumber = "EPERM"`.

HolyArrs runs plugins (such as the Tailscale plugin for remote access) in its own sandbox with Landlock and seccomp.
The unit leaves both available.
The unit does not delegate a cgroup to HolyArrs, so plugins run without their own memory, CPU and process limits.

`Restart = "on-failure"`: a restart from the controls and a backup restore exit with code 75, and systemd starts HolyArrs again.
A shut down from the controls exits with code 0, and HolyArrs stays stopped.
