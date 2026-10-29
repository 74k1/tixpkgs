> [!IMPORTANT]
> This module might not cover everything you need. If you run into missing options or rough edges, please [open an issue](https://github.com/74k1/tixpkgs/issues) or send a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.enclosed`

Enclosed is a minimalistic web application for sending end-to-end encrypted notes and files.
The server and its storage have zero knowledge of the note content.

## Info

- Project Website: `https://enclosed.cc/`
- Project Source: `https://github.com/CorentinTh/enclosed`
- Project Docs: `https://docs.enclosed.cc/`

## Quick start

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.enclosed
    # or
    inputs.tixpkgs.nixosModules."services/enclosed"
  ];

  services.enclosed = {
    enable = true;
  };
}
```

This starts Enclosed on port 8787.
The service listens on all interfaces. Use `nginx` or the firewall to restrict access.

## With SSL

```nix
services.enclosed = {
  enable = true;
  domain = "notes.example.com";
  nginx = {
    forceSSL = true;
    enableACME = true;
  };
};
```

Set `nginx` to a non-null value to enable the nginx reverse proxy.
`domain` is required in that case.

## Authentication

Set `authenticationRequired` to require a login before a note can be created or read.
Supply the users and the JWT secret as files:

```nix
services.enclosed = {
  enable = true;
  domain = "notes.example.com";
  nginx.forceSSL = true;
  authenticationRequired = true;
  jwtSecretFile = "/run/secrets/enclosed-jwt-secret";
  usersFile = "/run/secrets/enclosed-users";
};
```

Both files are loaded as systemd credentials (`LoadCredential`), so systemd reads them as root before the sandbox starts.
They do not need to be readable by the `enclosed` user, which makes them usable directly with agenix or sops-nix:

```nix
services.enclosed = {
  jwtSecretFile = config.age.secrets.enclosed-jwt-secret.path;
  usersFile = config.age.secrets.enclosed-users.path;
};
```

`usersFile` contains a comma-separated list of `email:bcrypt-hash` pairs.
Generate the hashes with the [key generator](https://docs.enclosed.cc/self-hosting/users-authentication-key-generator):

```
admin@example.com:$2a$10$...
```

Generate the JWT secret once:

```bash
openssl rand -base64 32 | tr -d '/+=' | install -m 600 /dev/stdin /run/secrets/enclosed-jwt-secret
```

If `jwtSecretFile` is not set, upstream falls back to the literal secret `change-me`.
The module warns about both missing files when `authenticationRequired` is enabled.

## Extra settings

The remaining upstream settings go through `environmentFile` or `environment`.
`environmentFile` uses the systemd format (`KEY=value`, one per line, no shell syntax) and is read by systemd as root:

```nix
services.enclosed.environmentFile = "/run/secrets/enclosed.env";
```

Example `/run/secrets/enclosed.env`:

```
SERVER_CORS_ORIGINS=https://notes.example.com
PUBLIC_DEFAULT_NOTE_TTL_SECONDS=86400
NOTES_MAX_ENCRYPTED_PAYLOAD_LENGTH=104857600
TASK_DELETE_EXPIRED_NOTES_CRON=0 * * * *
```

Non-secret values can also be set directly:

```nix
services.enclosed.environment = {
  PUBLIC_DEFAULT_NOTE_TTL_SECONDS = "86400";
};
```

Values in `environment` land in the Nix store.
Put secrets in `environmentFile`, `jwtSecretFile`, or `usersFile` instead.
`jwtSecretFile` and `usersFile` take precedence over the same variables in `environmentFile`.

When Enclosed is served from a subpath, set the matching base URL:

```nix
services.enclosed.publicBaseApiUrl = "/enclosed";
```

See the [upstream configuration reference](https://docs.enclosed.cc/self-hosting/configuration) for all variables.

## Data layout

| Path | Purpose |
|---|---|
| `dataDir/data/` | Encrypted notes and attachments |

`dataDir` defaults to `/var/lib/enclosed`.

## Hardening

The service runs with a hardened systemd unit:

- `ProtectSystem = "strict"`, and `dataDir` is the only writable path.
- `CapabilityBoundingSet = ""`, `NoNewPrivileges = true`, `RestrictSUIDSGID = true`.
- `PrivateDevices`, `PrivateTmp`, `ProtectHome`, `ProtectProc = "invisible"`, `RemoveIPC`.
- `RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ]`, `RestrictNamespaces`, `RestrictRealtime`.
- `SystemCallFilter = [ "@system-service" "~@privileged" ]` with `SystemCallErrorNumber = "EPERM"`.
- `SystemCallArchitectures = "native"`, `UMask = "0027"`.

`MemoryDenyWriteExecute` stays off: V8 compiles JavaScript into executable memory.

Enclosed binds all interfaces and has no bind-address setting.
Before you expose it to the internet, enable `authenticationRequired` with real secrets, and put it behind nginx or the firewall.
