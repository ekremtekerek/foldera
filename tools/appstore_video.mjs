//
// APP STORE ONIZLEME VIDEOSUNU (App Preview) 13 DILE YUKLER.
//
//   node tools/appstore_video.mjs            (hepsi)
//   node tools/appstore_video.mjs en tr      (secili diller)
//   node tools/appstore_video.mjs --durum    (yalnizca durumu yazar)
//
// NEDEN ELLE DEGIL, NEDEN fastlane DEGIL: `fastlane deliver` ekran
// goruntusu yukluyor ama ONIZLEME VIDEOSU yuklemiyor -- App Store
// Connect arayuzunden tek tek, on uc kez surukleyip birakmak gerekirdi.
// App Store Connect API'sinde ise videonun ucu da var: rezervasyon,
// parcali yukleme, onay.
//
// AKIS (Apple'in "reservation" modeli):
//   1. appPreviewSets  -> dil + cihaz ailesi icin kap
//   2. appPreviews     -> dosya adi ve boyutuyla REZERVASYON; cevapta
//                         `uploadOperations` geliyor
//   3. her operation   -> ham baytlari PUT
//   4. PATCH uploaded  -> MD5 ile kapat; Apple isliyor
//
// Anahtar deponun DISINDA duruyor ve iceriği hicbir yere basilmiyor.
//
import fs from "node:fs";
import path from "node:path";
import {
  api, jeton, varlikYukle, surumKimligi, yerellestirmeler, kapBul, dilTablosu, SURUM,
} from "./asc_api.mjs";

const KOK = path.resolve(path.dirname(new URL(import.meta.url).pathname
  .replace(/^\/([A-Za-z]:)/, "$1")), "..");

const VIDEO_DIZIN = "D:/Temp/foldera-video";

// Ekran goruntuleri APP_IPHONE_61 setinde; onizleme de ayni cihaz
// ailesine gitmeli yoksa urun sayfasinda eslesmiyor.
const ONIZLEME_TURU = "IPHONE_61";
// KAPAK KARESI. Urun sayfasinda video oynamadan once DURAN kare bu;
// varsayilan ilk karedir ve ilk karede tahta neredeyse bos.
//
// 11,00 saniye secildi: 40. bolumun acilisi. Tahta en dolu halinde
// (6x4, butun renkler, mandal ve joker gorunur) ve bir onceki bolumun
// konfetisi hala havada -- yani kare hem oyunu anlatiyor hem duragan
// durmuyor. Secim uc aday karsilastirilarak yapildi; 12,0'da kagit
// zaten katlanmis, 13,0'da neredeyse bos.
//
// AYNI AN HER DILDE AYNI KAREYE DENK GELIYOR. Senaryo belirlenimci:
// bolumler `levels/*.txt` icinde pisirilmis, hamleler `board.hint()`
// ile seciliyor ve beklemeler sabit saniye. Dil yalnizca metni
// degistiriyor, zamanlamayi degil -- 13 videonun suresi de ayni
// cikiyor. (Arcera'da durum farkliydi: oradaki uretici tohumsuz
// rastgelelik kullandigi icin ayni an her dilde baska bir goruntu
// veriyordu.)
//
// BICIM SAAT:DAKIKA:SANIYE:KARE ve ayraclarin hepsi IKI NOKTA. Noktali
// virgul ("00:00:11;00"), ondalik saniye ve duz saniye -- ucu de
// "Invalid format!" ile 409 donuyor.
const KAPAK_KARESI = "00:00:11:00";

async function durum(id) {
  const r = await api("GET", `v1/appPreviews/${id}`
    + "?fields%5BappPreviews%5D=assetDeliveryState");
  return r.data.attributes.assetDeliveryState;
}

///
/// KAPAK KARESINI YAZAR, GEREKIRSE BEKLEYEREK.
///
/// `assetDeliveryState` COMPLETE dedikten SONRA bile kapak karesi bir
/// sure reddediliyor:
///
///   409: Asset Not in Complete state! can't update Image!
///
/// Yani iki ayri islem var -- videonun teslimi ve videodan kare
/// cikarilabilmesi -- ve ikincisi daha gec bitiyor. Ilk yuklemede on uc
/// dilin HEPSI bu hatayi verdi. Beklemek disinda yapilacak bir sey yok;
/// burada bekliyoruz.
async function kapakYaz(liste) {
  console.log("\nkapak karesi");
  let kalan = liste.slice();
  for (let tur = 1; tur <= 20 && kalan.length; tur++) {
    const basarisiz = [];
    for (const [apple, id] of kalan) {
      try {
        await api("PATCH", `v1/appPreviews/${id}`, {
          data: {
            type: "appPreviews", id,
            attributes: { previewFrameTimeCode: KAPAK_KARESI },
          },
        });
        console.log(`  ${apple.padEnd(6)} ${KAPAK_KARESI}`);
      } catch (e) {
        if (!/not in complete state/i.test(e.message)) {
          console.error(`  ${apple.padEnd(6)} ${e.message}`);
          process.exitCode = 1;
          continue;
        }
        basarisiz.push([apple, id]);
      }
    }
    kalan = basarisiz;
    if (!kalan.length) break;
    console.log(`  ${kalan.length} video henuz hazir degil, 30 sn sonra yeniden`);
    await new Promise((r) => setTimeout(r, 30000));
    jeton();
  }
  if (kalan.length) {
    console.error(`  kapak karesi yazilamadi: ${kalan.map(([a]) => a).join(", ")}`);
    process.exitCode = 1;
  }
}

const diller = dilTablosu(KOK);
// ----------------------------------------------------------------- ana

const argv = process.argv.slice(2);
const yalnizDurum = argv.includes("--durum");
// Yuklemeyi atlayip YALNIZCA kapak karesini yazar. Kapak, video
// islendikten bir sure sonra kabul edildigi icin ilk kosuda
// basarisiz olabiliyor; o zaman bu kipte tekrarlaniyor.
const yalnizKapak = argv.includes("--kapak");
const istenen = argv.filter((a) => !a.startsWith("--"));
const liste = istenen.length ? istenen : Object.keys(diller);

const surum = await surumKimligi();
console.log(`surum ${SURUM} (${surum.attributes.appStoreState})`);
const yerel = await yerellestirmeler(surum.id);

const yuklenen = [];
for (const dil of liste) {
  const apple = diller[dil]?.apple;
  if (!apple) { console.error(`  ${dil}: appstore.json'da yok`); process.exitCode = 1; continue; }
  const yerelId = yerel.get(apple);
  if (!yerelId) { console.error(`  ${apple}: surumde yok`); process.exitCode = 1; continue; }

  const kapId = await kapBul(yerelId, "appPreviewSet", "previewType", ONIZLEME_TURU);

  if (yalnizDurum) {
    const r = await api("GET", `v1/appPreviewSets/${kapId}/appPreviews?limit=10`
      + "&fields%5BappPreviews%5D=assetDeliveryState,fileName");
    const d = r.data.map((x) => `${x.attributes.fileName}:`
      + `${x.attributes.assetDeliveryState?.state}`).join(" ") || "bos";
    console.log(`  ${apple.padEnd(6)} ${d}`);
    continue;
  }

  if (yalnizKapak) {
    const r = await api("GET", `v1/appPreviewSets/${kapId}/appPreviews?limit=10`);
    for (const x of r.data) yuklenen.push([apple, x.id]);
    if (!r.data.length) {
      console.error(`  ${apple}: yuklu video yok`);
      process.exitCode = 1;
    }
    continue;
  }

  const dosya = `${VIDEO_DIZIN}/ios-${dil}.mp4`;
  if (!fs.existsSync(dosya)) {
    console.error(`  ${apple}: video yok (${dosya})`);
    process.exitCode = 1;
    continue;
  }

  const eski = await api("GET", `v1/appPreviewSets/${kapId}/appPreviews?limit=10`);
  for (const x of eski.data) await api("DELETE", `v1/appPreviews/${x.id}`);
  const silinen = eski.data.length;
  const id = await varlikYukle("appPreviews", "appPreviewSet", kapId, dosya);
  yuklenen.push([apple, id]);
  console.log(`  ${apple.padEnd(6)} yuklendi${silinen ? ` (${silinen} eski silindi)` : ""}`);
  jeton();   // uzun kosularda jeton eskiyor
}

if (yalnizDurum || !yuklenen.length) process.exit(process.exitCode || 0);

if (yalnizKapak) {
  await kapakYaz(yuklenen);
  process.exit(process.exitCode || 0);
}

// Apple videoyu isliyor; COMPLETE olmadan gonderim yapilamaz.
console.log("\nisleme bekleniyor");
for (let tur = 0; tur < 40; tur++) {
  await new Promise((r) => setTimeout(r, 15000));
  jeton();
  const durumlar = [];
  for (const [apple, id] of yuklenen) durumlar.push([apple, await durum(id)]);
  const bekleyen = durumlar.filter(([, d]) => d?.state !== "COMPLETE");
  const hatali = durumlar.filter(([, d]) => (d?.errors || []).length || (d?.warnings || []).length);
  for (const [apple, d] of hatali) {
    console.error(`  ${apple}: ${JSON.stringify(d.errors || d.warnings)}`);
  }
  console.log(`  ${durumlar.length - bekleyen.length}/${durumlar.length} hazir`);
  if (!bekleyen.length) break;
}

await kapakYaz(yuklenen);
