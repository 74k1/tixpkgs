{ libnotify
, light
, playerctl
, pulseaudio
, wget
, writeShellApplication
, ...
}:

writeShellApplication rec {
  name = "duvolbr";

  runtimeInputs = [
    libnotify
    light
    playerctl
    pulseaudio
    wget
  ];

  text = /* bash */ ''
    VOL_STEP=5 # how much the volume should step up/down on keypress
    BRI_STEP=5 # how much the brightness should step up/down on keypress
    MAX_VOL=100 # what the max volume should be
    NOTIF_TIMEOUT=1000 # the timeout of the notification in ms
    DOWNLOAD_ALBUM_ART="true" # if this should download the album art in a tmp dir
    SHOW_ALBUM_ART="true" # if you want to show an album art / local or tmp dir
    SHOW_MUSIC_IN_VOL_INDICATOR="true" # if you want to show music in the vol indicator

    # uses regex to get volume from pulseaudio
    function get_vol {
      pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]{1,3}(?=%)' | head -1
    }

    # uses regex to get mute status from pulseaudio
    function get_mute {
      pactl get-sink-mute @DEFAULT_SINK@ | grep -Po '(?<=Mute: )(yes|no)'
    }

    # uses regex to get brightness from xbacklight
    function get_bri {
      sudo light | grep -Po '[0-9]{1,3}' | head -n 1
    }

    # returns a mute icon, volume low icon or a volume high icon depending on the volume
    function get_vol_icon {
      vol=$(get_vol)
      mute=$(get_mute)
      if [ "$vol" -eq 0 ] || [ "$mute" == "yes" ] ; then
        vol_icon=""
      elif [ "$vol" -lt 50 ]; then
        vol_icon=""
      else
        vol_icon=""
      fi
    }

    # always returns same brightness icon
    function get_bri_icon {
      bri_icon=""
    }

    # gets album art :shrug:
    function get_album_art {
      url=$(playerctl -f "{{mpris:artUrl}}" metadata)
      if [[ "$url" == "file://"* ]]; then
        album_art="''${url/file:\/\//}"
      elif [[ "$url" == "http://"* ]] && [[ "$DOWNLOAD_ALBUM_ART" == "true" ]]; then
        # identify filename from URL
        filename="$(echo "$url" | sed "s/.*\///")"
        
        # download file to /tmp if it doesn't already exist
        if [ ! -f "/tmp/$filename" ]; then
          wget -O "/tmp/$filename" "$url"
        fi

        album_art="/tmp/$filename"
      ## TODO - the uh, https/http stuff
      elif [[ "$url" == "https://"* ]] && [[ "$DOWNLOAD_ALBUM_ART" == "true" ]]; then
        # identify filename from URL
        filename="$(echo "$url" | sed "s/.*\///")"

        # download file to /tmp if it doesn't already exist
        if [ ! -f "/tmp/$filename" ]; then
          wget -O "/tmp/$filename" "$url"
        fi

        album_art="/tmp/$filename"
      else
        album_art=""
      fi
    }

    # displays a volume notification
    function show_vol_notif {
      vol=$(get_mute)
      get_vol_icon

      if [[ "$SHOW_MUSIC_IN_VOL_INDICATOR" == "true" ]]; then
        current_song=$(playerctl -f "{{title}} - {{artist}}" metadata)

        if [[ "$SHOW_ALBUM_ART" == "true" ]]; then
          get_album_art
        fi

        notify-send -t "$NOTIF_TIMEOUT" -h string:x-dunst-stack-tag:volume_notif -h int:value:"$vol" -i "$album_art" "$vol_icon $vol%" "$current_song"
      else
        notify-send -t "$NOTIF_TIMEOUT" -h string:x-dunst-stack-tag:volume_notif -h int:value:"$vol" "$vol_icon $vol%"
      fi
    }

    # display a music notification
    function show_music_notif {
      song_title=$(playerctl -f "{{title}}" metadata)
      song_artist=$(playerctl -f "{{artist}}" metadata)
      song_album=$(playerctl -f "{{album}}" metadata)

      if [[ "$SHOW_ALBUM_ART" == "true" ]]; then
        get_album_art
      fi

      notify-send -t "$NOTIF_TIMEOUT" -h string:x-dunst-stack-tag:music_notif -i "$album_art" "$song_title" "$song_artist - $song_album"
    }

    # displays a brightness notification
    function show_bri_notif {
      bri=$(get_bri)
      echo "$bri"
      get_bri_icon
      notify-send -t "$NOTIF_TIMEOUT" -h string:x-dunst-stack-tag:bri_notif -h int:value:"$bri" "$bri_icon $bri%"
    }

    # main function
    # takes user input: "vol_up" "vol_down" "vol_mute" "bri_up" "bri_down" "next_track" "prev_track" "play_pause" "pause"
    case $1 in
      vol_up)
        # unmutes, increases volume and displays notif
        pactl set-sink-mute @DEFAULT_SINK@ 0
        vol=$(get_vol)
        if [ $(( "$vol" + "$VOL_STEP" )) -gt $MAX_VOL ]; then
          pactl set-sink-volume @DEFAULT_SINK@ "$MAX_VOL"%
        else
          pactl set-sink-volume @DEFAULT_SINK@ +"$VOL_STEP"%
        fi
        show_vol_notif
        ;;

      vol_down)
        # decreases volume and displays notif
        pactl set-sink-volume @DEFAULT_SINK@ -"$VOL_STEP"%
        show_vol_notif
        ;;

      vol_mute)
        # toggles mute and displays notif
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        show_vol_notif
        ;;

      bri_up)
        # increases brightness and display notif
        sudo light -A "$BRI_STEP"
        show_bri_notif
        ;;

      bri_down)
        # decreases brightness and display notif
        sudo light -U "$BRI_STEP"
        show_bri_notif
        ;;

      next_track)
        # skips to next song and displays notif
        playerctl next
        sleep 0.5 && show_music_notif
        ;;

      prev_track)
        # skips to previous song and displays notif
        playerctl previous
        sleep 0.5 && show_music_notif
        ;;

      play_pause)
        # toggles play/pause and displays notif
        playerctl play-pause
        show_music_notif
        ;;

      pause)
        # just pauses and displays notif
        playerctl pause
        show_music_notif
        ;;
    esac
  '';
}
