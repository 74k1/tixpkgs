> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
>
> Contributions are always welcome!

# `nixosModules'.services.multi-scrobbler`

**multi-scrobbler** scrobbles plays from multiple sources to multiple clients.

## Info

- Project Website: `https://multi-scrobbler.app/`
- Project Source: `https://github.com/FoxxMD/multi-scrobbler`
- Project Docs: `https://docs.multi-scrobbler.app/`

## Usage

```nix
{
  config,
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.multi-scrobbler
    # or
    inputs.tixpkgs.nixosModules."services/multi-scrobbler"
  ];

  services.multi-scrobbler = {
    enable = true;
    stateDir = "/srv/multi-scrobbler";

    openFirewall = true;
    port = 9078;

    baseUrl = "https://scrobble.example.com";

    environmentFile = config.sops.secrets.multi-scrobbler.path;

    # see https://docs.multi-scrobbler.app/configuration/
    environment = {
      TZ = "Etc/UTC";
      PROMETHEUS_FULL = true;
    };

    configFiles = {
      spotify = {
        clients = [ "lastfm" ];
        data = {
          clientId = "[[SPOTIFY_CLIENT_ID]]";
          clientSecret = "[[SPOTIFY_CLIENT_SECRET]]";
        };
      };

      lastfm = [
        {
          data = {
            apiKey = "[[LASTFM_API_KEY]]";
            secret = "[[LASTFM_SECRET]]";
          };
        }
      ];
    };

    config = {
      sourceDefaults = {
        interval = 30;
      };

      webhooks = [
        {
          type = "ntfy";
          name = "alerts";
          url = "http://ntfy.internal:8080";
          topic = "multi-scrobbler";
        }
      ];
    };
  };
}
```

Example `environmentFile` contents:

```env
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
LASTFM_API_KEY=...
LASTFM_SECRET=...
```

## Notes

`configFiles` writes typed JSON config files like `spotify.json` and `lastfm.json`.

- The attribute name becomes the file name.
- A single attrset is wrapped into the upstream array format automatically.
- `name` defaults to the top-level attribute name when omitted.
- `enable` defaults to `true` when omitted.
- The attribute name `config` is reserved for `services.multi-scrobbler.config`.

Use a list when you need multiple entries of the same type:

```nix
services.multi-scrobbler.configFiles.spotify = [
  {
    name = "main";
    clients = [ "lastfm-main" ];
    data = {
      clientId = "[[SPOTIFY_CLIENT_ID]]";
      clientSecret = "[[SPOTIFY_CLIENT_SECRET]]";
    };
  }
  {
    name = "alt";
    clients = [ "lastfm-alt" ];
    data = {
      clientId = "[[SPOTIFY_ALT_CLIENT_ID]]";
      clientSecret = "[[SPOTIFY_ALT_CLIENT_SECRET]]";
    };
  }
];
```

The module supports all upstream configuration modes simultaneously:

- `environmentFile` for secrets
- `environment` for non-secret ENV
- `configFiles` for typed JSON files
- `config` for all-in-one `config.json`
