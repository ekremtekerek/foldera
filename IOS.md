# iOS derleme ve App Store

Geliştirme makinesi Windows; **`.ipa` yalnızca macOS'ta üretilebiliyor**.
Godot Xcode projesini Windows'ta da yazıyor ama imzalama ve paketleme için
bir mac gerekiyor — onu GitHub Actions sağlıyor
(`.github/workflows/ios.yml`).

## Durum

| | |
|---|---|
| Apple ID | `6822205137` |
| Paket | `com.foldera.game` (bundle id `YSS3LKJ7RQ`) |
| Takım | `3X9H5TXF29` |
| Sürüm | 1.0, derleme 1 |
| AdMob iOS | uygulama `ca-app-pub-6484682017091395~6008222688` |
| | geçiş `.../3960643842`, ödüllü `.../3235639553` |
| Gizlilik | https://sites.google.com/view/foldera-privacy |
| Destek | https://ekremtekerek.github.io/foldera-destek.html |

## Mağaza varlıkları — hepsi API'den

Depoya hiçbir mağaza dosyası girmiyor. Tek kaynak `store/copy.json` +
`store/appstore.json`.

```bash
node tools/appstore_meta.mjs            # karakter sınırlarını denetler
node tools/appstore_text.mjs            # 13 dilde metin
godot --path . -- store ios             # iPhone afişleri (13 dil x 6)
godot --path . -- store ipad            # iPad afişleri
node tools/appstore_shots.mjs --iphone
node tools/appstore_shots.mjs --ipad
bash tools/video_ios.sh                 # 13 önizleme videosu
node tools/appstore_video.mjs           # videoları yükler
node tools/appstore_video.mjs --kapak   # yalnız kapak karesi (gerekirse)
godot --path . -- store header          # ürün sayfası başlıkları
node tools/appstore_header.mjs          # başlıkları yükler
godot --path . -- store icons           # ikonlar (1024 App Store dahil)
node tools/appstore_kurulum.mjs         # kategori/yaş/inceleme bilgileri
node tools/appstore_fiyat.mjs           # ücretsiz + 175 ülke
```

**Neden `fastlane deliver` değil:** deliver metni ve görselleri dosya
ağacından okuyor — 13 dil × 8 alan = 104 metin dosyası ve 78 ekran
görüntüsü **depoya** girmek zorunda kalıyordu. Arcera'da tam olarak bu,
13 MB'lik mağaza görüntüsünün oyun paketine (`.pck`) sızmasına yol açtı
ve ancak CI günlüğünün `savepack` satırları okunurken fark edildi.

### İki ayrı metin kaynağı

Kolayca karıştırılıyor ve yanlış olanı denemek "attribute is not valid"
ile 409 dönüyor:

| Alan | Kaynak |
|---|---|
| ad, alt başlık, gizlilik adresi | `appInfoLocalizations` (**uygulamaya** bağlı) |
| açıklama, anahtar kelime, tanıtım, destek/pazarlama adresi | `appStoreVersionLocalizations` (**sürüme** bağlı) |

Bir dili app info'ya eklemek, sürüm yerelleştirmesini de kendiliğinden
açıyor; `appstore_text.mjs` bu yüzden çakışmada listeyi tazeleyip
güncellemeye düşüyor.

## Önizleme videosu — üç tuzak

Apple 886×1920, H.264, en çok 30 fps, **15–30 saniye** istiyor. Üçü de
denenerek bulundu:

1. **`--resolution` Movie Maker'ı etkilemiyor.** Kayıt çözünürlüğü
   `window/size/viewport_*` ayarından geliyor. `video_ios.sh` geçici bir
   `override.cfg` yazıyor (izlenen hiçbir dosyaya dokunmuyor, çıkışta
   siliniyor).
2. **Taban genişliği 720 kalmalı.** Doğrudan 886×1920 verince oyunun
   kendi yerleşimi de büyüyor ve tahta yanlardan taşıyor. Doğru oran aynı
   genişlikle kuruluyor: **720×1560**.
3. **Pencere ekrana sığmalı.** 1560 piksel isteyip ekran 1080 olunca
   Windows pencereyi kırpıyor; `stretch=expand` görünür alanı
   genişletiyor ama Movie Maker taban boyutu kaydediyor, yani kayıt
   kenarlardan kırpık çıkıyor. Pencereye aynı oranda küçük bir boy
   veriliyor: `--resolution 480x1040`.

Kaydı `tools/video_runner.gd` yapıyor, `reel_runner.gd` **değil**:
öteki 9:16 ve ~40 saniye, Apple'ın tavanını aşıyor. Ölçülen süre
**19,8 saniye**.

> Not: 886×1920, iPhone 15/16'nın gerçek oranı (2622×1206). Tahtanın
> etrafındaki boşluk kayıt hatası değil — oyun o cihazlarda gerçekten
> böyle görünüyor. Tahtayı uzun ekranlarda büyütmek ayrı bir iş.

### Kapak karesi

Ürün sayfasında video oynamadan önce duran kare. Varsayılan ilk karedir
ve orada tahta henüz yok. Biçim **`SAAT:DAKİKA:SANİYE:KARE` ve bütün
ayraçlar iki nokta**; noktalı virgül, ondalık saniye ve düz saniye —
üçü de "Invalid format!" ile 409 dönüyor.

## Ekran görüntüleri

| Set | Ölçü | Zorunlu mu |
|---|---|---|
| `APP_IPHONE_61` | 1206×2622 | evet |
| `APP_IPAD_PRO_3GEN_129` | 2048×2732 | **evet** |

iPad seti isteğe bağlı değil: Godot'nun iOS dışa aktarımında cihaz
ailesi seçeneği yok, üretilen Xcode projesi **evrensel**. Paket iPad'i de
hedeflediği için "Add for Review" şu tek satırla reddediyor:
*"You must upload a screenshot for 13-inch iPad displays."*

Afişler Play'inkiyle aynı tasarım; `store_poster.gd` içindeki sayılar
1080 genişliğe göre ayarlanmıştı, `_k()` ölçek katsayısıyla başka
genişliklere taşındı. 1080'de katsayı 1.0, yani Play görselleri bit bit
aynı kalıyor.

Metne ayrılan dikey pay **genişlikle** ölçülüyor (`pw * 0.45`),
yükseklikle değil: yazı boyutları genişlikle büyüdüğü için iPad'de
(2048×2732, geniş ve basık) alt başlık kartın altında kalıyordu.

## Ürün sayfası başlığı

5244×2950 PNG, dil başına bir dosya. **Tek dosya iki yere gidiyor** —
ürün sayfasının en üstündeki görsel ve arama sonuçlarındaki görsel —
çünkü Apple bu ölçüyü `universalAsset` sayıyor; dil başına tek görsel
yüklenip iki yerleşim açılıyor.

Akış ekran görüntüsününkinden **farklı**: görsel önce uygulamanın
**varlık kütüphanesine** giriyor (sürüme değil uygulamaya bağlı), sonra
her dil için bir "placement" onu sürüm diline bağlıyor. Yerleşim
yalnızca sürüm `Prepare for Submission` iken açılabiliyor — Arcera'da
sürüm incelemeye girdiği için yapılamamıştı (409: *Creating a placement
is not permitted in AppStoreVersion's current state*).

**Güvenli alan.** Apple kareyi başka oranlara kırpıyor: 21:9 üstten ve
alttan, 3:2 yanlardan. Kesişim `x 409..4835, y 351..2599` ve bütün
içerik bunun içinde duruyor (`_draw_header()` içindeki `H_GUVENLI`).
Dışına taşan bir şey bazı yerleşimlerde kesiliyor ve bunu mağazada
görmeden fark etmek mümkün olmuyor.

Kart ölçeği **kanvastan değil kartın kendi genişliğinden** türetiliyor:
kanvas 5244 piksel ama kart 1153, kanvastan türetilen katsayı
yuvarlatmayı ve gölgeyi karta göre devasa yapıyordu.

## Derleme

```
gh workflow run ios.yml           # ya da ios-v* etiketi
```

Gereken gizli değerler:

| | |
|---|---|
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | App Store Connect API anahtarı |
| `IOS_CERT_P12`, `IOS_CERT_PASSWORD` | dağıtım sertifikası + özel anahtar |

### Dağıtım sertifikası — tür başına iki

`fastlane cert` koşucuda özel anahtar bulamadığı için **her koşuda
yeni** bir dağıtım sertifikası üretiyor. Apple'ın sınırı tür başına iki
ve Arcera'da altıncı koşuda doldu:

> Could not create another Distribution certificate, reached the maximum
> number of available Distribution certificates.

Üretilen sertifikaların özel anahtarları koşucunun geçici anahtarlığıyla
birlikte siliniyor — yani hepsi **ölü doğuyor**: Apple tarafında yuva
tutuyorlar, imzalamak için kullanılamıyorlar.

Doğrusu sertifikayı bir kez üretip özel anahtarıyla taşımak:
`arcera/tools/ios_sertifika.sh` anahtarı yerelde üretiyor, sertifikayı
Apple'dan isteyip `.p12` kuruyor ve `gh secret set` ile yazıyor.
**Sertifika hesap genelinde** — Arcera ile Foldera aynı sertifikayı
kullanıyor.

Yuva doluysa önce bir tanesini iptal etmek gerekiyor. Developer
portalında **"Created By" sütununda `API Key:` yazan `Distribution`**
satırları güvenli; `iOS Distribution` yazanlar **SMS Onay'ın (EAS)**,
onlara dokunulmayacak.

### Neden elle `xcodebuild` değil

Üç koşu boyunca denendi, her seferinde imza aşamasında düştü. Kök neden
hep aynı: otomatik imzalama CI'da geliştirme profili istiyor, CI'da ise
cihaz yok. Gerekçelerin tamamı `fastlane/Fastfile` başında.

Godot macOS'ta yalnızca Xcode projesini üretmiyor, kendi
`xcodebuild`ini de çalıştırıyor; o çağrı API anahtarımızı taşımadığı
için düşüyor. Bizim ondan istediğimiz tek şey **proje**, o yüzden iş
akışı o hatayı bilerek yutuyor ve projenin yazıldığını ayrıca
doğruluyor.

## Reklamlar

iOS **ayrı bir AdMob uygulaması** ve ayrı birimler. Android birimlerini
iOS'te kullanmak istekleri yanlış uygulamaya yazar; AdMob bunu hata
saymaz, yalnızca raporlar karışır.

İki sessiz tuzak, ikisi de testle kapatıldı (`t_ios_kurulum`):

- **`custom_features="liveads"`** olmadan derleme Google'ın *test*
  birimlerini yüklüyor: reklam görünür, oyun çalışır, kazanç sıfırdır.
  Mirera 1.0.1 böyle yayınlandı.
- **`addons/admob/ios/*`** dışlanırsa eklentinin iOS tarafı pakete
  girmiyor. O satır iOS reklamı kapalıyken konmuştu.

Mağaza bağlantısı yayına kadar yok, yani sunum **sınırlı** kalacak.
Yayından sonra AdMob → uygulama ayarları → mağazaya ekle yapılacak ve
**tam mağaza URL'siyle** aranacak; paket adıyla arama bulmuyor.

### ATT yok, `npa=1` var

AdMob Godot eklentisi ATT (izleme izni) istemini hiç sunmuyor — yalnızca
`AppTrackingTransparency.framework` bağlı, çağrı arayüzü yok. ATT onayı
olmadan iOS zaten IDFA erişimini kesiyor; `AdMobAdProvider._istek()`
iOS'te `npa=1` göndererek bunu açıkça söylüyor.

App Store gizlilik etiketinde bu yüzden **izleme yok** yazılacak.
Etiketin "izliyorum" deyip ATT istemi sunmaması Guideline 5.1.2'den
doğrudan ret sebebi.

## Satın alma

Mağaza katmanı yalnızca Google Play Billing. iOS'te `using_stub()` true
dönüyor ve `offers_enabled()` (`not stub or not production`) üretim
derlemesinde **false** — yani "Reklamsız oyna" ve "Geri yükle"
düğmeleri iOS'te hiç görünmüyor. Çalışmayan bir satın alma düğmesi tek
başına ret sebebi olurdu; bu kapı onu kapatıyor.

iOS'te reklam kaldırma satın alması **yok**; sürüm tamamen reklamla
destekleniyor. Destek sayfası da bunu böyle yazıyor.
