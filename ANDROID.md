# Android derleme ve AdMob

Bu makinede kurulu ve çalışır durumda. Aşağıdakiler bir daha kurmak ya da
başka bir makineye taşımak gerekirse diye.

## Çıktılar

```bash
cd D:/Projects/foldera

# Play Store'a yüklenecek olan (Google cihaz başına böler)
godot --headless --path . --export-release "Android AAB" "D:/Temp/foldera-android/FOLDERA.aab"

# Doğrudan kurulum / test için
godot --headless --path . --export-release "Android"     "D:/Temp/foldera-android/FOLDERA-release.apk"
godot --headless --path . --export-debug   "Android"     "D:/Temp/foldera-android/FOLDERA-debug.apk"
```

Sürüm imzası **ortam değişkenlerinden** okunuyor — parola depoya girmiyor:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="D:/Tools/android-keys/foldera-upload.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="foldera-upload"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="..."
```

Telefona kurmak için: `D:\Tools\android-sdk\platform-tools\adb.exe install -r FOLDERA-release.apk`


## Hangi ön ayarla derlemeli

| ön ayar | özellik etiketi | reklam birimi | nereye |
|---|---|---|---|
| `Android AAB` | — | **test** | iç test, alfa, beta |
| `Android AAB (yayin)` | `liveads` | **canlı** | yalnızca üretim |

```bash
# iç test / beta — test reklamı
godot --headless --path . --export-release "Android AAB" "D:/Temp/foldera-android/FOLDERA.aab"

# üretim — gerçek reklam
godot --headless --path . --export-release "Android AAB (yayin)" "D:/Temp/foldera-android/FOLDERA-live.aab"
```


**Her yüklemeden önce `version/code` artırılmalı.** İki AAB ön ayarı da aynı
sayıyı taşıyor (`export_presets.cfg` içinde `version/code`); Play aynı sürüm
kodunu ikinci kez kabul etmez. Şu an ikisi de **2** — iç teste yüklenen sürüm
bu. Üretim AAB'sini derlemeden önce ikisini de 3 yap.

Kural `scripts/ads/admob_ad_provider.gd` içinde tek satır:
`var _live := OS.has_feature("liveads") and not OS.is_debug_build()`

**Neden iki ön ayar var.** Eski kural "hata ayıklama değilse canlı" idi, yani
iç teste giden release derlemesi **canlı** reklam yüklüyordu. Kendi reklamına
tıklamak AdMob politikası ihlali ve hesap askıya alma sebebi — üstelik sessizce
olur. Şimdi hata yönü tersine döndü: etiketi koymayı unutursan üretimde test
reklamı çıkar, gelir sıfır olur ama zarar vermez ve ilk raporda fark edilir.

Uygulama başlarken logcat'e hangi kipte olduğunu yazıyor:
`[ads] birim kipi: TEST  interstitial=ca-app-pub-3940256099942544/1033173712`

Bu satır yüzünden ayrıca **AdMob'da test cihazı tanımlamaya gerek kalmadı**.


### AdMob mağaza bağlama sırası (2026-08-26)

"Sınırlı reklam sunumu" uyarısını kaldırmak için AdMob'da uygulamayı Play
listelemesine bağlamak gerekiyor. **Bu, uygulama herkese açık yayınlanmadan
yapılamıyor.** AdMob'un arama kutusu Play Store'un *genel* dizinini tarıyor;
iç testteki uygulamanın genel sayfası olmadığı için hem `com.foldera.game`
hem `Foldera Paper Fold Puzzle` aramaları boş dönüyor.

Hesaptaki diğer uygulamalar bunu doğruluyor: yayınlanmış olanlar (DualDate.AI,
Funny Block, Raccoon Bubble) "Google Play + paket adı + İnceleme iste"
gösteriyor; yayınlanmamışlar (Foldera, Bilen Kazanıyor, Master Burger)
yalnızca "Mağaza ekle" gösteriyor.

Yani sıra şu ve tersi mümkün değil:
**üretime çık → AdMob'da mağazayı bağla → inceleme iste → limit kalkar.**
## Kurulu araç zinciri

| ne | nerede |
|---|---|
| JDK 17 (Temurin) | `D:\Tools\jdk17\jdk-17.0.20.1+1` |
| Android SDK | `D:\Tools\android-sdk` — platform-tools, build-tools 36.1.0, android-36 |
| Godot export şablonları | `D:\Tools\Godot\templates\4.7.1.stable` (junction ile `%APPDATA%\Godot\export_templates`) |
| İmza anahtarları | `D:\Tools\android-keys\` — `debug.keystore`, `foldera-upload.keystore` |
| Godot ayarları | `%APPDATA%\Godot\editor_settings-4.7.tres` (JDK/SDK/keystore yolları) |

Godot 4.7 **compileSdk 36 · targetSdk 36 · buildTools 36.1.0 · minSdk 24** istiyor
(`android/build/config.gradle` içinde yazıyor).

### Kurulumdaki iki tuzak

**1. Avast HTTPS taraması Java'nın ağını kesiyordu.** `sdkmanager` ve Gradle
"PKIX path building failed" veriyordu; `curl` aynı adresten indirebiliyordu
çünkü Windows sertifika deposu araya giren CA'yı tanıyor, Java'nınki tanımıyor.

Çözüm — CA'yı JDK'nın güven deposuna almak:

```bash
keytool -importcert -trustcacerts -noprompt -alias avast-ssl-shield \
  -file corp-ca.cer -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit
```

Bu makinede **her Java aracı** aynı sorunu yaşar (Gradle, Maven, Android Studio).
Aynı belirtiyi başka bir araçta görürsen sebebi budur.

**2. `--install-android-build-template` headless çalışmıyor** (takılıp kalıyor).
Elle yapılabiliyor, zaten `android_source.zip`'i açmaktan ibaret:

```bash
unzip android_source.zip -d android/build/
printf '4.7.1.stable' > android/.build_version    # Godot bu dosyayı arıyor
```

`android/.build_version` olmadan Godot "sürüm belirtilmemiş" hatası veriyor —
`android/build/version.txt` değil, dikkat.

## AdMob

Eklenti: **poing-studios/godot-admob-plugin v5.0.0**, `addons/admob/` altında.
Google Mobile Ads SDK 24.9.0 gradle üzerinden geliyor.

Doğrulandı: APK içindeki `classes.dex` Google Mobile Ads sınıflarını,
`classes4.dex` Poing köprü sınıflarını taşıyor; App ID manifest'te.

Akış `scripts/ads/admob_ad_provider.gd` içinde. Üç savunma var, üçü de
gerçek cihazlarda yaşanan sorunlardan:

- **Watchdog (90 sn).** SDK bazen hiçbir geri çağrıyı tetiklemiyor (ağ kopması,
  uygulamanın arka plana atılması). Zaman aşımı olmasa `await` sonsuza kadar
  askıda kalır ve **oyun kilitlenir**.
- **Tek seferlik çözüm.** Aynı gösterimde hem "kapandı" hem "gösterilemedi"
  gelebiliyor; ikinci sinyal `await`'i bozar.
- **Ödül sadece `on_user_earned_reward` ile.** Reklamın kapanması tek başına
  ödül anlamına gelmez — kullanıcı erken kapatmış olabilir.

### Play Developer API ile yayınlama

```bash
node tools/play_publish.mjs --key D:/Tools/play-api/foldera-sa.json \
  --listings --images --aab D:/Temp/foldera-android/FOLDERA.aab
```

Servis hesabı: `fastlane-upload@dualdate-bd87c.iam.gserviceaccount.com`
(DualDate için kurulmuştu, Foldera'ya da yetki verildi). Anahtar
`D:\Tools\play-api\foldera-sa.json` — depoya girmiyor.

Betik `production` kanalına yüklemeyi **reddediyor**; yalnızca
internal/alpha/beta. Üretime çıkış konsoldan, insan eliyle.

**İki tuzak, ikisi de zaman aldı:**

**1. `edits:commit` 403 veriyordu.** Sebep şu izinlerin eksikliği değildi:
mağaza varlığı ve test kanalı yetkileri vardı. Eksik olan
**"Taslak uygulamaları düzenleme ve silme"** idi — uygulama hiç
yayınlanmadığı için Play onu *taslak* sayıyor ve API'nin düzenlemesine
izin vermiyor. Yönetici yetkisi vermeye gerek yok, bu tek izin yeter.
`edits.insert` ve `listings.update` çağrıları başarılı olduğu, yalnızca
`commit` patladığı için teşhis yanıltıcı.

**2. Görsel ucu toplu yüklemede 500 dönüyor.** İstekte sorun yok, tekrar
denenince geçiyor. 260 görsellik bir koşuda en az bir kez olması neredeyse
kesin; betikte 5 denemeye kadar üstel geri çekilmeli yeniden deneme var
(429/500/502/503/504).


### Mağaza tanıtım videosu

```bash
node tools/play_publish.mjs --key ... --listings --video "https://www.youtube.com/shorts/iGBr4mnpsAc"
```

Play **yalnızca** `https://www.youtube.com/watch?v=<id>` biçimini kabul ediyor;
Shorts (`/shorts/<id>`), kısa (`youtu.be/...`) ve gömme (`/embed/...`) adresleri
reddediliyor. Betik kimliği ayıklayıp doğru biçime çeviriyor, o yüzden hangi
biçimi verdiğin önemli değil.

Video **dile özel** bir alan: `--listings` her 13 dile aynı adresi yazıyor.
Bir dile ayrı video koymak gerekirse o dilin girişini elle düzenle.

Yayındaki video: `iGBr4mnpsAc` — 0:38, dikey, İngilizce arayüz.
### Uygulama ikonu

`export_presets.cfg` → `launcher_icons/*` **artık ayarlı**. Öncesinde ayarlı
değildi ve APK **Godot'un varsayılan robot ikonuyla** çıkıyordu.

```
launcher_icons/main_192x192               store/icons/launcher-192.png
launcher_icons/adaptive_foreground_432x432 store/icons/adaptive-foreground-432.png
launcher_icons/adaptive_background_432x432 store/icons/adaptive-background-432.png
launcher_icons/adaptive_monochrome_432x432 store/icons/adaptive-monochrome-432.png
```

Bu dosyaları `godot --path . -- store` üretiyor. Godot bunları dışa aktarma
sırasında `android/build/res/mipmap-*/icon*.webp` içine yazıyor; APK'da
doğrulamak için:

```bash
unzip -p FOLDERA-release.apk res/... # kaynak adları karıştırılmış olur
# daha kolayı: android/build/res/mipmap-xxxhdpi-v4/icon.webp dosyasına bak
```


### İlk üretim sürümü — yolda çıkan üç engel (2026-08-26)

**1. `edits:commit` → 400 "Only releases with status draft may be created on draft app".**
Hiç yayınlanmamış uygulamada Play yalnızca `draft` durumunda sürüm kabul ediyor.
`play_publish.mjs --taslak-surum` bunu yapıyor; sürüm sonra Console'dan incelemeye
gönderiliyor. Sonraki güncellemelerde bayrak gerekmez.

**2. `edits:commit` → 403.** Servis hesabında **"Üretim sürümüne yayınlama"**
izni yoktu (bilerek verilmemişti). Play Console → Kullanıcılar ve izinler →
servis hesabı → Foldera → Sürümler bölümünden verildi. İzin 7'den 9'a çıktı.

**3. "Uygulamayı incelemeye gönder" düğmesi kilitliydi.** Kontrol panelinde
iki eksik vardı ve ikisi de aynı sayfada: **uygulama kategorisi** (Oyun/Bulmaca)
ve **mağaza girişi iletişim e-postası**. Bunlar girilince kurulum 11/11 oldu.
Ayrıca üretim kanalında **0 ülke/bölge** seçiliydi — 177 ülke eklendi.

Sürüm notları 13 dilde `store/release_notes.json` içinde. Play'in metin
kutusuna `<dil-etiketi>` bloklarıyla yapıştırılıyor; sınır dil başına 500 karakter.
### Yayından önce ŞART olanlar

| ne | şu an | ne olmalı |
|---|---|---|
| AdMob App ID | ✅ ca-app-pub-6484682017091395~2513514048 | project.godot → admob/general/android/app_id |
| Geçiş reklamı birimi | ✅ …/6004825044 | sürüm derlemesinde canlı, hata ayıklamada test |
| Ödüllü reklam birimi | ✅ …/3223960483 | 3 ipucu ödülü, oyundaki değerle aynı |
| Satın alma doğrulama | yerel dosyada | **sunucuda** — `ads_removed` şu an düzenlenebilir |
| "Satın alımları geri yükle" | yok | Google mağaza incelemesinde arıyor |
| Gizlilik politikası URL | ✅ sites.google.com/view/foldera-privacy | metin legal/privacy.html; Play Console alanına girildi |
| Veri güvenliği formu | boş | AdMob reklam kimliği topluyor, formda beyan edilmeli |
| İçerik derecelendirme anketi | boş | Play Console üzerinden doldurulmalı |
| Çevirilerin gözden geçirilmesi | makine kalitesinde | ana dili konuşan biri — özellikle ru/uk/vi/pl |

> Test kimlikleriyle yayına çıkma. Gerçek reklam göstermez ve AdMob hesabını
> politika ihlaliyle askıya aldırabilir.

### Cihazda doğrulanması gerekenler

**Oynanış cihazda doğrulandı** (2026-08-26, debug APK): sürükle-bırak
çalışıyor. Bu, uzun süre açık kalan tek gerçek şüpheydi — düzeltme yalnızca
sentetik dokunma testleriyle doğrulanmıştı.

Hâlâ denenmemiş olanlar (hepsi gerçek reklam kimlikleri gerektiriyor, o yüzden
iç test kanalına çıkınca bakılacak):

- Reklamların gerçekten görünmesi (geçiş + ödüllü)
- UMP rıza formunun AB/İngiltere'de açılması
- Ödülün yalnızca video sonuna kadar izlenince verilmesi
- Watchdog'un ağ koptuğunda oyunu kurtarması

`adb logcat | grep -i admob` ile ilk çalıştırmada SDK günlüklerini izle.

> İç teste geçtiğinde o derleme **canlı** reklam birimlerini yükler. Kendi
> cihazını AdMob'da *test cihazı* olarak eklemeden reklamlara dokunma.
