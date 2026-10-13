#!/usr/bin/env bash
#
# APP STORE ONIZLEME VIDEOSU (App Preview) -- 13 dil.
#
#   bash tools/video_ios.sh [dil ...]     (bos birakilirsa hepsi)
#
# Apple'in istedigi: 886x1920, H.264, en cok 30 fps, 15-30 saniye,
# alfa yok. Cikti D:/Temp/foldera-video/ios-<dil>.mp4
#
# Kaydi tools/video_runner.gd yapiyor (reel_runner.gd DEGIL: oteki 9:16
# ve ~40 saniye, Apple'in sure tavanini asiyor).
#
# UC SESSIZ TUZAK, ucu de Arcera'da deneyerek bulundu:
#
# 1. `--resolution` Movie Maker'i ETKILEMIYOR. Kayit cozunurlugu
#    projenin `window/size/viewport_*` ayarindan geliyor. O yuzden
#    gecici bir `override.cfg` yaziliyor (izlenen hicbir dosyaya
#    dokunulmuyor, cikista siliniyor).
#
# 2. TABAN GENISLIGI 720 KALMALI. override ile dogrudan 886x1920
#    verince oyunun kendi yerlesimi de buyuyor ve tahta yanlardan
#    tasiyor. Dogru oran ayni genislikle kuruluyor: 720x1560
#    (886:1920 ile ayni oran).
#
# 3. PENCERE EKRANA SIGMALI. Pencere 1560 piksel isteyip ekran 1080
#    olunca Windows pencereyi kirpiyor; `stretch=expand` gorunur alani
#    genisletiyor ama Movie Maker taban boyutu kaydediyor, yani kayit
#    kenarlardan kirpik cikiyor. Pencereye AYNI ORANDA kucuk bir boy
#    veriliyor (480x1040), boylece expand hicbir sey eklemiyor.
#
set -euo pipefail

GODOT="${GODOT:-D:/Tools/godot/Godot_v4.7.1-stable_win64_console.exe}"
FF="${FFMPEG:-D:/Tools/ffmpeg/ffmpeg.exe}"
FFPROBE="${FFPROBE:-D:/Tools/ffmpeg/ffprobe.exe}"
CIKTI="${CIKTI:-D:/Temp/foldera-video}"
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TABAN_W=720; TABAN_H=1560      # kayit cozunurlugu (886:1920 orani)
PENCERE="480x1040"             # ekrana sigan, AYNI oranda pencere
HEDEF_W=886; HEDEF_H=1920      # Apple'in istedigi

DILLER=("$@")
if [ ${#DILLER[@]} -eq 0 ]; then
	mapfile -t DILLER < <(node -e '
		const d = JSON.parse(require("node:fs").readFileSync(
			process.argv[1] + "/store/appstore.json", "utf8"));
		for (const k of Object.keys(d.diller)) console.log(k);
	' "$KOK")
fi

mkdir -p "$CIKTI"
cd "$KOK"

temizle() { rm -f "$KOK/override.cfg"; }
trap temizle EXIT

printf '[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\n' \
	"$TABAN_W" "$TABAN_H" > override.cfg

basarisiz=()
for dil in "${DILLER[@]}"; do
	ham="$CIKTI/ham-$dil.avi"
	son="$CIKTI/ios-$dil.mp4"
	echo "== $dil"

	# Godot bu makinede ara sira hic acilmadan dusuyor (antivirus);
	# uc deneme hakki veriliyor ve CIKTI DOGRULANIYOR.
	ok=0
	for deneme in 1 2 3; do
		rm -f "$ham"
		"$GODOT" --path . --resolution "$PENCERE" --write-movie "$ham" -- video "$dil" \
			> /dev/null 2>&1 || true
		if [ -f "$ham" ] && [ "$(stat -c %s "$ham")" -gt 1000000 ]; then ok=1; break; fi
		echo "   deneme $deneme bos dondu, yeniden"
	done
	if [ "$ok" -eq 0 ]; then basarisiz+=("$dil"); continue; fi

	"$FF" -y -v error -i "$ham" \
		-vf "scale=${HEDEF_W}:${HEDEF_H}:flags=lanczos,fps=30" \
		-c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
		-crf 18 -preset slow \
		-c:a aac -b:a 192k -ar 44100 -ac 2 \
		-movflags +faststart "$son"
	rm -f "$ham"

	# Apple olcuyu ve sureyi yuklemede denetliyor; burada denetlemek
	# on uc dosyayi bos yere yuklemekten ucuz. Sure araligi 15-30 sn.
	bilgi=$("$FFPROBE" -v error \
		-show_entries stream=width,height,r_frame_rate:format=duration \
		-of csv=p=0 "$son" | tr '\n' ' ')
	sure=$("$FFPROBE" -v error -show_entries format=duration \
		-of csv=p=0 "$son")
	echo "   $bilgi"
	if awk "BEGIN{exit !($sure < 15 || $sure > 30)}"; then
		echo "   SURE DISARIDA ($sure sn; Apple 15-30 istiyor)" >&2
		basarisiz+=("$dil")
	fi
done

if [ ${#basarisiz[@]} -gt 0 ]; then
	echo "URETILEMEYEN/GECERSIZ: ${basarisiz[*]}" >&2
	exit 1
fi
echo "tamam -> $CIKTI"
