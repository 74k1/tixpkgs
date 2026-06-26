# Cryptgeon

Secure, open source note & file sharing service inspired by PrivNote, written in Rust & Svelte.

Each note gets a generated `id` (stored server-side) and `key` (in the URL fragment, never sent to the server). Notes are encrypted client-side with AES-GCM. Data is held in Redis memory and never persisted to disk.

## Quick start

```nix
services.cryptgeon = {
  enable = true;
  hostname = "notes.example.com";
  nginx = {
    forceSSL = true;
    enableACME = true;
  };
};
```

HTTPS is required — browsers will not support the cryptographic functions over plain HTTP.

## Requirements

- **Redis** — enabled by default via `services.cryptgeon.redis.createLocally`. Disable it and point at an external instance with `services.cryptgeon.redis.url`.
- No persistent storage needed. Everything lives in Redis memory.

## Settings

All settings have sensible defaults. Notable ones:

| Option | Default | Description |
|---|---|---|
| `settings.sizeLimit` | `"1 KiB"` | Max note size. `512 MiB` hard limit |
| `settings.allowFiles` | `true` | Enable file uploads |
| `settings.maxViews` | `100` | Max views per note |
| `settings.maxExpiration` | `360` | Max lifetime in minutes (6 hours) |

Theme customization (`themeImage`, `themeText`, `themePageTitle`, `themeFavicon`) and imprint/legal notice support are available under `settings`.
