#!/usr/bin/env bash
#
# Godot Movie Maker kaydini (AVI/MJPEG, ~130 MB) magazaya hazir MP4 uretir.
#
#   godot --path . --write-movie D:/Temp/foldera-video/en.avi --fixed-fps 60 -- reel en
#   tools/make_video.sh en tr
#
# Iki cikti:
#   *-portrait.mp4   1080x1920  reklam, TikTok/Reels/Shorts
#   *-landscape.mp4  1920x1080  Play tanitim videosu (YouTube'a yuklenip
#                               linki Play Console'a girilir -- Play dosya
#                               yuklemesini KABUL ETMIYOR)
#
set -euo pipefail

FF=${FF:-D:/Tools/ffmpeg/ffmpeg.exe}
SRC=${SRC:-D:/Temp/foldera-video}
PROJ=${PROJ:-D:/Projects/foldera}
OUT="$PROJ/store/video"
mkdir -p "$OUT"

for code in "$@"; do
	avi="$SRC/$code.avi"
	plate="$PROJ/store/$code/reel-plate.png"
	[ -f "$avi" ]   || { echo "yok: $avi"; exit 1; }
	[ -f "$plate" ] || { echo "yok: $plate  (godot --path . -- store plate)"; exit 1; }

	echo "== $code dikey"
	"$FF" -hide_banner -loglevel error -y -i "$avi" \
		-vf "scale=1080:1920:flags=lanczos" \
		-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -r 60 \
		-c:a aac -b:a 192k -movflags +faststart \
		"$OUT/foldera-$code-portrait.mp4"

	# Oynanis, plakadaki kagit kartin tam uzerine biniyor (1218,40 562x1000).
	# Bu koordinatlar store_poster.gd icindeki `video_rect` ile ayni olmali.
	echo "== $code yatay"
	"$FF" -hide_banner -loglevel error -y -loop 1 -i "$plate" -i "$avi" \
		-filter_complex "[1:v]scale=562:1000:flags=lanczos[g];[0:v][g]overlay=1218:40:shortest=1[v]" \
		-map "[v]" -map 1:a \
		-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -r 60 \
		-c:a aac -b:a 192k -movflags +faststart \
		"$OUT/foldera-$code-landscape.mp4"

	# 21. saniye: konfeti patlamasi -- en hareketli ve renkli kare
	echo "== $code kucuk resim"
	"$FF" -hide_banner -loglevel error -y -ss 21 -i "$OUT/foldera-$code-landscape.mp4" \
		-frames:v 1 -vf "scale=1280:720" -q:v 2 "$OUT/foldera-$code-thumb.jpg"
done

ls -la "$OUT"
