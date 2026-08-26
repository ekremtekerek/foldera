# FOLDERA

**Kâğıdı katla, eşleri patlat** — *fold the paper, pop the pairs*. Offline oynanan, tek jestli, hyper-casual bir bulmaca.

---

## Mekanik

Tahta bir kâğıt parçası. Parmağını bir kareye koyup kaydırdığında, o kareye kadarki
kâğıt kaydırdığın yöne doğru **katlanır** ve üst üste gelen hücreler birleşir:

| üstteki | alttaki | sonuç |
|---|---|---|
| boş | boş | boş |
| taş | boş | taş yer değiştirir |
| aynı renk | aynı renk | **patlar** |
| joker | herhangi bir renk | **patlar** |
| farklı renk | farklı renk | katlama **reddedilir** |
| mandal | dolu herhangi bir şey | katlama **reddedilir** |

Kâğıt her katlamada **küçülür** — geri dönüş yok. Hedef: renkli taşların hepsini
temizlemek. Mandallar (`#`) asla temizlenmez, kalıcı engeldir.

Ama **çıkmaza düşemezsin**: her seviye, ulaşılabilen bütün durumları
denetlenerek seçiliyor. Hangi sırayla katlarsan katla tahta çözülebilir kalır.
Geri al düğmesi bir kurtarma değil, yıldız için hamle sayısını düşürme aracı.

Neden özgün: eşleştirme oyunlarında hamle genelde *iki taşı* etkiler. Burada tek
jest **tüm tahtayı** aynalar. Bu yüzden asıl bulmaca hangi taşı değil, **hangi
sırayla nereden katlayacağın**.

---

## Çalıştırma

```bash
# Godot 4.7.1 (portable):  D:\Tools\Godot\Godot_v4.7.1-stable_win64.exe
godot --path .                    # oyunu aç
godot --path . -- shots           # görsel doğrulama kareleri -> shots/
godot --path . -- soak            # uçtan uca oynanış testi (25 seviye)
godot --path . -- store           # mağaza görselleri + ikonlar -> store/
godot --headless --path . --script res://tests/test_logic.gd   # mantık testleri
godot --headless --path . --script res://tools/bake_levels.gd  # seviye bankasını üret
```

Hata ayıklama sürücüleri yalnızca debug derlemesinde ve `--` sonrası bayrakla
yüklenir; sürüm derlemesine hiç girmez.

### Sürüm alma

```bash
godot --headless --path . --export-release "Windows" "D:/Temp/foldera-build/FOLDERA.exe"
godot --headless --path . --export-release "Web"     "D:/Temp/foldera-web/index.html"
node tools/serve-web.mjs D:/Temp/foldera-web 8080      # telefondan test için
```

Web sürümü `file://` ile **açılmaz** — Godot'un thread'li şablonu
`SharedArrayBuffer` istiyor, o da cross-origin isolation başlıkları gerektiriyor.
`tools/serve-web.mjs` tam olarak bu başlıkları veriyor.

Export şablonları `D:\Tools\Godot\templates` altında; Godot'un aradığı
`%APPDATA%\Godot\export_templates\4.7.1.stable` yoluna junction ile bağlı
(C: sürücüsünü şişirmemek için).

---

## Mimari

Mantık ve görünüm tamamen ayrı: `BoardModel` hiçbir Godot düğümü tanımıyor, bu
yüzden bütün kurallar headless test edilebiliyor.

| dosya | işi |
|---|---|
| `scripts/tiles.gd` | taş kodlaması ve birleşme kuralları |
| `scripts/board_model.gd` | katlama geometrisi — saf, düğümsüz |
| `scripts/fold_graph.gd` | ulaşılabilir durum grafiği — **çıkmaz denetimi**, par, ipucu |
| `scripts/fold_solver.gd` | bağımsız IDDFS çözücü — yalnızca testlerde çapraz kontrol |
| `scripts/level_gen.gd` | seviye bankası + çıkmazsız üretim |
| `tools/bake_levels.gd` | 500 seviyeyi derleme anında üretir |
| `scripts/board_view.gd` | sürükleme, katlama animasyonu, önizleme |
| `scripts/paper_sheet.gd` | kâğıt yüzeyi, kat çizgileri, katlanmış kenarlar |
| `scripts/overlay_layer.gd` | kanadın gölgesi + hedef hayaletleri |
| `scripts/confetti.gd` | elle yazılmış kâğıt kırpıntısı patlaması |
| `scripts/audio_engine.gd` | tüm sesler çalışma anında sentezlenir |
| `scripts/main.gd` | akış, arayüz, ekran sarsıntısı, titreşim |

### Üç tasarım kararı

**Çıkmaz yok — hiçbir seviyede.** Seviyeler geriye doğru üretiliyor: boş bir
tahtadan başlanıp N kez "açılıyor", her açılış ileri yönde geçerli bir
katlamanın tam tersi. Bu, seviyenin **bir** çözümü olduğunu garanti ediyordu ama
yetmiyordu: oyuncu geçerli ama ölümcül bir kat çizgisi seçince eşleri bir daha
kavuşturamayacağı bir tahtada kalabiliyordu. Ölçtük — **80 seviyenin 61'inde en
az bir çıkmaz vardı**, toplam 406 çözümsüz durum.

Bulmacada çıkmaz kabul edilemez; geri al düğmesi bunun özrü olamaz. Bu yüzden
her aday artık `FoldGraph` ile **tam denetimden** geçiyor: tahtadan ulaşılabilen
bütün durumlar çıkarılıp her birinin hâlâ çözülebilir olduğu doğrulanıyor. Tek
bir çıkmaz varsa aday eleniyor.

Yayınlanan her seviye şu özelliği taşıyor: **hangi sırayla katlarsan katla,
tahta çözülebilir kalır.** Oyuncu kaybedemez; maharet en *kısa* çözümü bulmakta.

Bu ucuz değil (temiz aday oranı ~%6), o yüzden 500 seviye **derleme anında**
üretilip `levels/levels.txt` içine yazılıyor — 36 KB, cihazda arama yok, seviye
açılışı anlık. Bankanın ötesindeki seviyelerde aynı denetim çalışma anında
yapılıyor (~65 ms).

**Grafik hem ipucu hem emniyet kemeri.** Seviye açılırken bir kez çıkarılıyor
(birkaç ms) ve seviye boyunca duruyor. İpucu artık arama değil tablo okuması —
eski IDDFS çözücü derinlik limitine takılıp boş dönebiliyordu. Her katlamadan
sonra tahtanın hâlâ çözülebilir olduğu da doğrulanıyor; üretim garantisi
gereği asla tetiklenmemeli, tetiklenirse hata sessizce geçmesin diye duruyor.

**Hiçbir ses/görsel varlık dosyası yok.** Sesler `AudioStreamWAV` olarak çalışma
anında sentezleniyor, ikonlar ve taşlar vektörle çiziliyor. Tek veri dosyası
seviye bankası. Sonuç: lisans derdi yok, her ekran yoğunluğunda keskin.

---

## Mağaza görselleri

`godot --path . -- store` her şeyi üretir → `store/`

| ne | boyut | nerede |
|---|---|---|
| ekran görselleri | 1080×1920 (9:16) | `store/<dil>/01..06.png` |
| özellik grafiği | 1024×500 | `store/<dil>/feature.png` |
| uygulama ikonu | 512×512 | `store/icon-512.png` |
| başlatıcı ikonları | 192 + 432×3 | `store/icons/` |
| Play Console metinleri | — | `store/LISTING.md` |

**13 dilin hepsi ayrı ayrı.** Play, kullanıcının ülkesine/diline göre o dilin
sayfasını gösteriyor: Türkiye'den bakan Türkçe afişi, Almanya'dan bakan
Almancasını görüyor; listelenmeyen her yer İngilizce sayfaya düşüyor.

**Kareler sahte değil.** Her biri gerçekten oynanan oyundan, o dilin arayüzüyle
alınıyor ve afişe 1:1 basılıyor (oyun penceresi tam 720×1280'e zorlanıyor).
Mağazada görülen şey indirilen şeyle birebir aynı — mock-up yok.

Metinler `tools/store_copy.gd` içinde, sıralaması ASO'ya göre: ilk iki kare
tıklanma oranını belirlediği için en güçlü iki iddia orada (mekanik, sonra
"çıkmaza düşemezsin"). Başlıklar en fazla iki satır ve küçük küçük resimde
okunacak boyutta; sığmazsa yazı tipi otomatik küçülüyor.

> **Uygulama ikonu bir hataydı.** Bu iş yapılana kadar APK **Godot'un varsayılan
> robot ikonuyla** çıkıyordu — `export_presets.cfg` içinde `launcher_icons/*`
> hiç ayarlanmamıştı. Mağazadaki en önemli tek görsel budur.


### Tanıtım videosu

```bash
godot --path . -- store plate                                    # yatay çerçeve
godot --path . --write-movie D:/Temp/foldera-video/en.avi \
      --fixed-fps 60 -- reel en                                  # oynanış kaydı
tools/make_video.sh en tr                                        # MP4'e çevir
```

| çıktı | boyut | nereye |
|---|---|---|
| `foldera-<dil>-landscape.mp4` | 1920×1080 | YouTube → linki Play Console'a |
| `foldera-<dil>-portrait.mp4` | 1080×1920 | reklam, Shorts/Reels/TikTok |
| `foldera-<dil>-thumb.jpg` | 1280×720 | YouTube küçük resmi |

**Play Console video dosyası kabul etmiyor** — promo video alanı yalnızca bir
YouTube bağlantısı alıyor. Bu yüzden yatay sürüm asıl çıktı; Play videoyu
YouTube oynatıcısında gösterdiği için yatayı öneriyor, oyun ise dikey. Aradaki
farkı `store/<dil>/reel-plate.png` kapatıyor: oynanış sağdaki kâğıt kartın
üzerine biniyor, sol taraf markaya ve üç iddiaya kalıyor.

Kayıt Godot'un Movie Maker kipiyle alınıyor: zaman sabit adımla ilerlediği için
kayıt gerçek zamandan yavaş sürse de videodaki tempo `reel_runner.gd` içinde
yazan sürelerle birebir aynı. Ses de kaydediliyor — patlama ve katlama sesleri
sentezlendiği için videoda da var.

**Oynanış sahte değil.** Her katlama gerçek jest yoluyla yapılıyor (bas ·
sürükle · bırak), oyun normal akışını işletiyor. Parmak hareketi smoothstep ile
yavaşlayıp hızlanıyor ve bırakma noktası kasten tam katlanmadan önce (0.85) —
kalan yolu oyunun kendi yaslanma animasyonu tamamlıyor, kâğıt "şak" diye
oturuyor. Sabit hızlı sürükleme robot gibi duruyordu.

Katlamalar ipucunun önerdiği hamleler, yani çözüm her zaman par uzunluğunda
bitiyor ve video her seferinde üç yıldızla kapanıyor.
## Diller

Metinlerin tamamı `locale/foldera.csv` içinde; kodda yalnızca anahtar var.
Godot dosyayı içe aktarıp her dil için bir `.translation` üretiyor.

**13 dil:** English · Türkçe · Español · Português · Deutsch · Français ·
Italiano · Русский · Polski · Nederlands · Bahasa Indonesia · Tiếng Việt ·
Українська

Oyun varsayılan olarak **telefonun dilini** kullanıyor
(`OS.get_locale_language()`); desteklenmeyen bir dilse İngilizce'ye düşüyor.
Başlık ekranındaki dil düğmesinden elle de seçilebiliyor — Japonca telefon
kullanan biri İngilizce yerine bildiği başka bir dile geçebilsin diye. Her dil
listede **kendi dilinde** yazıyor ("Deutsch", "Русский"): kullanıcı anlamadığı
bir dilde kendi dilini arayamaz.

### Neden bu 13 dil

Yazı tipi kısıtı. Nunito **Latin, Latin Extended, Kiril ve Vietnamca**
kapsıyor. Kapsamadıkları için şimdilik dışarıda kalanlar ve gerekenler:

| dil | gereken |
|---|---|
| العربية | Noto Sans Arabic (~300 KB) **+ sağdan-sola yerleşim** |
| हिन्दी | Noto Sans Devanagari (~300 KB) |
| ไทย | Noto Sans Thai (~200 KB) |
| Ελληνικά | Noto Sans (~400 KB) |
| 中文 · 日本語 · 한국어 | Noto Sans SC/JP/KR — **her biri 5–16 MB** |

Godot font fallback desteklediği için ilk dördü ucuz: font dosyasını ekleyip
`FontFile.fallbacks` listesine koymak yetiyor. CJK ise indirme boyutunu ciddi
şekilde büyütüyor, bu yüzden ayrı bir karar.

### Çeviriler hakkında dürüst not

13 dilin tamamı ilk geçiş kalitesinde — **yayından önce ana dili konuşan
birinin gözden geçirmesi gerekiyor.** Özellikle düğme metinleri ve öğretici
kartlar. CSV tek dosya olduğu için düzeltmek önemsiz.

Yerelleştirmeyi koruyan üç otomatik kontrol var (`tests/test_logic.gd`):
kodda kullanılan her anahtar tabloda var mı, her dilde her hücre dolu mu ve
**biçim belirteçlerinin sayısı tüm dillerde aynı mı** — bir çevirmen `%d`
düşürürse `Loc.f()` çöker ya da yanlış sayı basar.

### Metin genişlemesi

Almanca ve Rusça metinler İngilizce'nin %30–40 uzunu olabiliyor. `ChipButton`
metnini **çizim anında düğmenin gerçek genişliğine** göre sığdırıyor ve
gerekirse yazı tipini küçültüyor; `custom_minimum_size` de metne göre büyüyor.

> Bunu yaparken bir Godot tuzağına düştüm: `Button` asgari boyutunu C++
> tarafında hesaplıyor ve GDScript'teki `_get_minimum_size()` override'ına
> **hiç bakmıyor**. Genişliği `custom_minimum_size` üzerine yazmak gerekiyor.

## Rehber (onboarding)

Öğretme sırası kasıtlı olarak **seviye numarasına değil oyuncunun gerçek
deneyimine** bağlı — üretici rastgele olduğu için mandal herkeste aynı seviyede
çıkmıyor.

| tetik | ne gösterir |
|---|---|
| ilk 6 katlamadan önce | parmak animasyonu + "kâğıdı tut ve karşıya katla" |
| tahtada ilk kez mandal | MANDAL kartı — mandal + taş → ✕ |
| tahtada ilk kez joker | JOKER kartı — joker + renk → patlar |
| ilk seviye bitişi | YILDIZLAR kartı — par nedir |
| 4. seviye | TAKILIRSAN kartı — geri al / yeniden / ipucu |

Kartların kuralı: **metinden önce resim**. Üstte her zaman iki taş, bir işaret
ve sonuç var; oyuncu metni okumasa bile kuralı anlıyor. Her kart bir kez çıkar
(`SaveData.seen`).

## Para kazanma

Model: **dengeli** — ilk 10 seviye tamamen reklamsız, sonra ölçülü.

| yerleşim | kural |
|---|---|
| geçiş reklamı | seviye 11+, her 3 seviyede bir, en az 90 sn ara, ödüllü reklamdan sonra 45 sn bekleme |
| ödüllü: ipucu | ipucu bitince → +3 ipucu |
| ödüllü: çözüm | takılınca → oyun çözümü kendisi oynar, sonra seviye baştan başlar |
| IAP | `no_ads` (₺149) · `hints_10` (₺29) · `hints_30` (₺69) |
| ipucu ekonomisi | günde 3 ücretsiz; satın alınan bakiye gün değişiminde silinmez |

Üç tasarım kararı:

- **Reklam ödül anında değil, DEVAM'a basınca çıkıyor.** Yıldızların göründüğü
  anı reklamla bölmek en çok terk ettiren kalıp.
- **İpucu yalnızca gösterilecek bir hamle varsa harcanıyor.** Çözümsüz tahtada
  bakiye yenmiyor.
- **Bedava kontenjan önce harcanıyor.** Gün sonunda kaybolacak olan önce gider;
  tersi yapılırsa oyuncu parasını verdiğini boşa harcamış hisseder.

Kod ayrımı: **ne zaman** gösterileceği `AdPolicy`'de (saf mantık, headless test
edilebilir), **nasıl** gösterileceği `AdProvider`'da. Reklam ağı değiştirmek
politikaya hiç dokunmuyor.

### AdMob durumu — dürüst not

`scripts/ads/admob_ad_provider.gd` **çalışan bir entegrasyon değil, dikiş
yeri.** İçi `TODO(admob)` ile işaretli. Gerçek AdMob üç şey istiyor ve hiçbiri
bu makinede yok: Android SDK + JDK, Godot Android build şablonu, AdMob
eklentisi. Eklenti yokken `is_available()` false dönüyor ve servis sessizce
`StubAdProvider`'a düşüyor — oyun bugün de sorunsuz çalışıyor.

Sahte sağlayıcı sadece "hep başarılı" demiyor: yükleme gecikmesi, %92 doluluk
oranı ve erken kapatma (ödül verilmeden) davranışlarını taklit ediyor. Kötü
durumların doğru ele alındığı böylece Android olmadan test edilebiliyor.

### Yayından önce yapılması şart

- **Satın alma doğrulaması sunucuda.** `ads_removed` şu an sadece yerel dosyada;
  dosya düzenlenebilir.
- **"Satın alımları geri yükle"** akışı — Google mağaza incelemesinde arıyor.
- **Gerçek reklam birimi kimlikleri** — şu an Google'ın TEST kimlikleri.
- **UMP rıza akışı** (AB) ve **iOS ATT** izni. Uygulama içindeki rıza ekranı
  kendi katmanımız; SDK'nın kendi akışının yerine geçmiyor.

## Durum

Doğrulanmış: mantık testleri **19.442 kontrol**, uçtan uca oynanış testi
**283 kontrol** — hepsi geçiyor.

En kritik doğrulama seviye bankasında: **500 seviyenin tamamı çıkmazsız**
(ulaşılabilen her durum denetlenerek), par değerleri ilk 120 seviyede bağımsız
IDDFS çözücüyle çapraz kontrol edildi. Denetleyicinin kendisi de test ediliyor:
çözümü *olan* ama içinde çıkmaz *bulunan* elle kurulmuş bir tahta "kirli"
işaretlenmezse test düşüyor — bu olmadan bozuk bir denetleyici her şeye temiz
der ve 500 kontrolün hepsi boşa düşerdi.

Bağımsız ikinci doğrulama: rastgele oynayan bir oyuncu 2000 oyunun **hiçbirinde**
çıkmaza düşmüyor. Bu, grafiğin yalnızca *varsaydığı* ayna eşdeğerliğini gerçek
iki taraflı katlamalarla sınıyor. Aynı ölçüm oyunun kolaylaşmadığını da
gösteriyor: rastgele oyun üç yıldızı yalnızca **%15** oranında alıyor, ortalama
**1,55 × par** hamle harcıyor. Kaybedemiyor olmak, düşünmeden kazanmak değil.

Analitik şu an tamamen yerel (`user://events.jsonl`), hiçbir şey dışarı
gönderilmiyor. En kritik ölçüm huni: `level_start` / `level_complete` /
`level_abandon`. Yalnızca `level_complete` toplamak kaç kişinin takılıp
kaldığını gizler.

### Sıradakiler

- **Seviye haritası** — şu anda ilerleme doğrusal; seviye seçme ekranı yok.
- **Zorluk eğrisi 46. seviyede sabitleniyor** (5 katlama / 6×6). Ötesi için yeni
  taş tipleri gerek: zincir (iki kez katlanmalı), renk değiştiren taş, sabit
  kat çizgisi.
- **Haptik** yalnızca Android'de bağlı.
