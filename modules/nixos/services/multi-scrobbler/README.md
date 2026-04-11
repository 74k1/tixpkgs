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

  services.multi-scrobbler = rec {
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
      # Clients
      lastfm = {
        name = "lastfm_client";
        configureAs = "client";
        data = {
          apiKey = "[[CUSTOM_LASTFM_API_KEY]]";
          secret = "[[CUSTOM_LASTFM_SECRET]]";
          redirectUri = "${baseUrl}/lastfm/callback";
        };
      };

      # Sources
      spotify = {
        name = "spotify";
        clients = [ "lastfm_client" ];
        data = {
          clientId = "[[CUSTOM_SPOTIFY_CLIENT_ID]]";
          clientSecret = "[[CUSTOM_SPOTIFY_CLIENT_SECRET]]";
          redirectUri = "${baseUrl}/callback";
          interval = 60;
        };
      };
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
CUSTOM_LASTFM_API_KEY=...
CUSTOM_LASTFM_SECRET=...
CUSTOM_SPOTIFY_CLIENT_ID=...
CUSTOM_SPOTIFY_CLIENT_SECRET=...
```

> [!WARNING]
> Do not put upstream single-user env keys like `SPOTIFY_*`, `LASTFM_*`, `LIBREFM_*`, `MALOJA_*`, `LISTENBRAINZ_*`, `LZ_*`, or similar into `environment` or `environmentFile` when you are also using `configFiles` or `config`.
>
> multi-scrobbler consumes those names directly and will auto-create additional single-user configs like `unnamed` or `unnamed-lfm`.
>
> Use neutral env names like `CUSTOM_SPOTIFY_CLIENT_ID` and reference them from JSON with `[[CUSTOM_SPOTIFY_CLIENT_ID]]`.

## Notes

`configFiles` writes typed JSON config files like `spotify.json` and `lastfm.json`.

- The attribute name becomes the upstream file type.
- A single attrset is wrapped into the upstream array format automatically.
- `name` is required.
- `enable` defaults to `true` when omitted.
- The attribute name `config` is reserved for `services.multi-scrobbler.config`.

Use a list when you need multiple entries of the same type:

```nix
{
  services.multi-scrobbler.configFiles.spotify = [
    {
      name = "spotify_main";
      clients = [ "lastfm_main" ];
      data = {
        clientId = "[[CUSTOM_SPOTIFY_CLIENT_ID]]";
        clientSecret = "[[CUSTOM_SPOTIFY_CLIENT_SECRET]]";
      };
    }
    {
      name = "spotify_alt";
      clients = [ "lastfm_alt" ];
      data = {
        clientId = "[[CUSTOM_SPOTIFY_ALT_CLIENT_ID]]";
        clientSecret = "[[CUSTOM_SPOTIFY_ALT_CLIENT_SECRET]]";
      };
    }
  ];
}
```

The module supports all upstream configuration modes simultaneously:

- `environmentFile` for secrets
- `environment` for non-secret ENV
- `configFiles` for typed JSON files
- `config` for all-in-one `config.json`
