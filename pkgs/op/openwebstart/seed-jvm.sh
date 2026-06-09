#!/bin/sh
# Pre-register the pinned JDK in OpenWebStart's JVM Manager so the user does not
# have to add it manually through the GUI. OWS keeps its local JVM list in
# $XDG_CACHE_HOME/icedtea-web/jvm-cache/cache.json; we seed it with the Nix JDK
# unless that exact javaHome is already present (so we never clobber a config
# the user has already curated).
set -eu

java_home="@jdk8@/lib/openjdk"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/icedtea-web/jvm-cache"
cache_file="$cache_dir/cache.json"

if [ -f "$cache_file" ] && grep -q "$java_home" "$cache_file"; then
  exit 0
fi

version="$(sed -n 's/^JAVA_VERSION="\(.*\)"/\1/p' "$java_home/release")"

mkdir -p "$cache_dir"
cat > "$cache_file" <<JSON
{
  "runtimes": [
    {
      "version": "$version",
      "vendor": "OpenJDK",
      "javaHome": "file://$java_home/",
      "active": true,
      "os": "LINUX64",
      "managed": false
    }
  ]
}
JSON
