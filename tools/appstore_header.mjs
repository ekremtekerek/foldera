//
// URUN SAYFASI BASLIGI + ARAMA SONUCU GORSELI -- 13 dil.
//
//   godot --path . -- store header           (gorselleri uretir)
//   node tools/appstore_header.mjs           (yukler)
//   node tools/appstore_header.mjs --durum
//
// NE BUNLAR: App Store urun sayfasinin en ustunde duran gorsel ve
// arama sonuclarinda uygulamanin yaninda cikan gorsel. Ikisi de
// ISTEGE BAGLI -- konmazsa Apple ekran goruntulerini ve onizleme
// videosunu gosteriyor. Konursa urun sayfasi markali bir kapakla
// aciliyor.
//
// TEK DOSYA IKI YERE GIDIYOR. Apple'in referans verisinde
// 5244x2950 PNG (16:9) "universalAsset" ve compatiblePlacementTypes
// hem PRODUCT_PAGE_HEADER_ASSET hem APP_STORE_SEARCH_RESULTS_ASSET
// sayiyor; o yuzden dil basina tek gorsel yukleyip iki yerlesim
// aciyoruz.
//
// GUVENLI ALAN: Apple bu kareyi baska oranlara kirpiyor (21:9
// ustten-alttan, 3:2 yanlardan). Kesisim hesabi ve butun yerlesim
// store_poster.gd icindeki `_draw_header()` fonksiyonunda.
//
// AKIS ekran goruntusununkinden FARKLI: gorsel once uygulamanin
// VARLIK KUTUPHANESINE giriyor (surume degil uygulamaya bagli),
// sonra her dil icin bir "placement" o gorseli surum diline
// bagliyor.
//
import fs from "node:fs";
import path from "node:path";
import {
  api, jeton, kutuphaneGorseliYukle, surumKimligi, yerellestirmeler, dilTablosu,
} from "./asc_api.mjs";

const KOK = path.resolve(path.dirname(new URL(import.meta.url).pathname
  .replace(/^\/([A-Za-z]:)/, "$1")), "..");

const PROMO_BASE = "D:/Temp/foldera-promo";
const DOSYA = "appstore-header-5244x2950.png";

const TURLER = ["PRODUCT_PAGE_HEADER_ASSET", "APP_STORE_SEARCH_RESULTS_ASSET"];

const diller = dilTablosu(KOK);
const argv = process.argv.slice(2);
const yalnizDurum = argv.includes("--durum");
const istenen = argv.filter((a) => !a.startsWith("--"));
const liste = istenen.length ? istenen : Object.keys(diller);

const surum = await surumKimligi();
console.log(`surum 1.0 (${surum.attributes.appStoreState})`);
const yerel = await yerellestirmeler(surum.id);

async function yerlesimler(yerelId) {
  const r = await api("GET",
    `v1/appStoreVersionLocalizations/${yerelId}/placements?limit=50`
    + `&filter%5BplacementType%5D=${TURLER.join(",")}`);
  return r.data;
}

const acilan = [];
for (const dil of liste) {
  const apple = diller[dil]?.apple;
  const yerelId = yerel.get(apple);
  if (!yerelId) { console.error(`  ${dil}: surumde yok`); process.exitCode = 1; continue; }

  if (yalnizDurum) {
    const v = await yerlesimler(yerelId);
    const d = v.map((x) => `${x.attributes.placementType.replace("_ASSET", "")}:`
      + `${x.attributes.state}`).join(" ") || "bos";
    console.log(`  ${apple.padEnd(6)} ${d}`);
    continue;
  }

  const dosya = `${PROMO_BASE}/${dil}/${DOSYA}`;
  if (!fs.existsSync(dosya)) {
    console.error(`  ${apple}: gorsel yok (${dosya})`);
    process.exitCode = 1;
    continue;
  }

  // Eskiler once kaldiriliyor; yoksa ayni dilde iki baslik birikiyor.
  for (const x of await yerlesimler(yerelId)) {
    await api("DELETE", `v1/appAssetLibraryPlacements/${x.id}`);
  }

  const gorselId = await kutuphaneGorseliYukle(dosya);

  // Gorsel islenmeden yerlesim kabul edilmiyor. Bu kaynakta
  // `assetDeliveryState` YOK (400: "is not a valid field name");
  // islenmenin isareti `imageAsset` alaninin dolmasi -- olculeri de
  // orada donuyor, yani yanlis boyut da burada yakalaniyor.
  let hazir = false;
  for (let i = 0; i < 30; i++) {
    const r = await api("GET", `v1/appAssetLibraryImages/${gorselId}`);
    const a = r.data.attributes;
    if (a.stateDetails?.errors?.length) {
      throw new Error(`${apple}: ${JSON.stringify(a.stateDetails.errors)}`);
    }
    if (a.imageAsset) {
      if (a.imageAsset.width !== 5244 || a.imageAsset.height !== 2950) {
        throw new Error(`${apple}: beklenmeyen olcu `
          + `${a.imageAsset.width}x${a.imageAsset.height}`);
      }
      hazir = true;
      break;
    }
    await new Promise((r2) => setTimeout(r2, 5000));
  }
  if (!hazir) { console.error(`  ${apple}: gorsel islenmedi`); process.exitCode = 1; continue; }

  for (const tur of TURLER) {
    await api("POST", "v1/appAssetLibraryPlacements", {
      data: {
        type: "appAssetLibraryPlacements",
        attributes: { placementType: tur },
        relationships: {
          appStoreVersionLocalization: {
            data: { type: "appStoreVersionLocalizations", id: yerelId },
          },
          image: { data: { type: "appAssetLibraryImages", id: gorselId } },
        },
      },
    });
  }
  acilan.push(apple);
  console.log(`  ${apple.padEnd(6)} baslik + arama sonucu`);
  jeton();
}

if (!yalnizDurum) console.log(`\n${acilan.length} dil tamam`);
