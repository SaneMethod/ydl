#!/bin/bash

format=mp3
url=none
filename_template="%(title)s.%(ext)s"
as_video=false
is_playlist=false
start_index=1
cookies=youtube.cookies.txt

while [ "$1" != "" ]; do
  if [ "$1" = "--video" ]; then
    as_video=true
    shift

    continue
  fi

  if [ "$1" = "--get-url" ]; then
    as_url=true
    shift
    continue
  fi

  if [ "$1" = "--url" ]; then
    url=$2
  elif [ "$1" = "--format" ]; then
    format=$2
  elif [ "$1" = "--index" ]; then
    start_index=$2
    is_playlist=true
  elif [ "$1" = "--help" -o "$1" = "-h" ]; then
    echo "--Usage--"
    echo "--url url > specify the url to download from."
    echo "--format format > specify the format to download to - default mp3. Use --format best to preserve existing file format."
    exit 0
  fi
  shift
  shift
done

if [ "$as_url" == true ]; then
  yt-dlp -f bestaudio/best -g -e "$(printf "%s" "$url")"
  exit 0
fi

if [ "$as_video" == true ]; then
   cd /media/Video/Downloads/ || exit
   yt-dlp --format bestaudio+bestvideo "$(printf "%s" "$url")"
   exit 0
fi

if [ "$is_playlist" == true ]; then
  cd /media/Music/Downloads/ || exit
  pl_dir=$(echo "$url" | tr -cd '[:alnum:]')
  mkdir -p "$pl_dir"
  cd "$pl_dir" || exit
  yt-dlp --rm-cache-dir

  yt-dlp -x --yes-playlist --playlist-start "$(printf "%s" "$start_index")" --audio-format "$(printf "%s" "$format")" --audio-quality 0 -o "$(printf "%s" "$filename_template")" --format bestaudio "$(printf "%s" "$url")"
  exit 0
fi

cd /media/Music/Downloads/ || exit
yt-dlp -x --audio-format "$(printf "%s" "$format")" --audio-quality 0 -o "$(printf "%s" "$filename_template")" --cookies ./"$cookies" --format bestaudio "$(printf "%s" "$url")"


