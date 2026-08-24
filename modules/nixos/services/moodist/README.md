> [!IMPORTANT]
> This Module _might_ not have all the capabilities you'd want / expect. Please raise an [issue](https://github.com/74k1/tixpkgs/issues) or figure out a fix for a PR. :)
> 
> Contributions are always welcome!

# `nixosModules'.services.moodist`

Moodist is a self-hostable ambient sounds web app: layer 84 curated sounds into
soundscapes, with binaural beat / isochronic generators, breathing exercise,
Pomodoro, and more. It's a static Astro single-page app (no backend), so the
module just serves the built site with nginx.

## Info

- Project Website: `https://moodist.mvze.net/`
- Project Source: `https://github.com/remvze/moodist`

## Usage

```nix
{
  inputs,
  ...
}: {
  imports = [
    inputs.tixpkgs.nixosModules'.services.moodist
    # or
    inputs.tixpkgs.nixosModules."services/moodist"
  ];

  services.moodist = {
    enable = true;
    hostname = "moodist.example.com";
    nginx = {
      forceSSL = true;
      enableACME = true;
    };
  };
}
```

## Notes

- Without a public domain, `services.moodist.hostname` defaults to `localhost`
  and the site is served over plain HTTP on port 80.
- Moodist is a client-side SPA: unknown routes (e.g. shareable mix URLs) fall
  back to `/index.html` automatically, mirroring the upstream Caddyfile.
