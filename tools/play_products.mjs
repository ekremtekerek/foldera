#!/usr/bin/env node
//
// Uygulama ici urunleri Play Console'da olusturur/gunceller.
//
//   node tools/play_products.mjs --key D:/Tools/play-api/foldera-sa.json
//   node tools/play_products.mjs --key ... --dry
//
// NEDEN BU VAR: `query_product_details` yalnizca Play'de TANIMLI urunleri
// dondurur. Urunler olmadan oyun fiyat gosteremez ve satin alma akisi
// baslatamaz -- "urun bulunamadi" hatasi verir.
//
// Urun metinleri locale/foldera.csv'den geliyor: magaza girisleriyle ayni
// 13 dili konussun ve iki yerde ayri ayri guncellenmesin diye.
//
// Fiyat TRY olarak veriliyor, diger ulkelere Play'in kendi kuru ceviriyor
// (autoConvertMissingPrices). Fiyati elle 170 ulkeye yazmak hem hatali hem
// bakimsiz olurdu.
//
import { createSign } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'

const PKG = 'com.foldera.game'
const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3'
const REGIONS_VERSION = '2022/02'

const LOCALES = {
  en: 'en-US', tr: 'tr-TR', es: 'es-ES', pt: 'pt-BR', de: 'de-DE',
  fr: 'fr-FR', it: 'it-IT', ru: 'ru-RU', pl: 'pl-PL', nl: 'nl-NL',
  id: 'id', vi: 'vi', uk: 'uk',
}

// Fiyatlar scripts/store/store_service.gd icindeki price_fallback ile ayni.
const PRODUCTS = [
  { sku: 'no_ads',   titleKey: 'IAP_NOADS_TITLE',   descKey: 'NOADS_BODY',       lira: 149, usd: 4, eur: 4 },
  { sku: 'hints_10', titleKey: 'IAP_HINTS10_TITLE', descKey: 'IAP_HINTS_DESC',   lira: 29, usd: 1, eur: 1 },
  { sku: 'hints_30', titleKey: 'IAP_HINTS30_TITLE', descKey: 'IAP_HINTS30_DESC', lira: 69, usd: 2, eur: 2 },
]

const TITLE_MAX = 55
const DESC_MAX = 200

const args = process.argv.slice(2)
const opt = (n, d = null) => { const i = args.indexOf(`--${n}`); return i >= 0 && args[i + 1] ? args[i + 1] : d }
const flag = (n) => args.includes(`--${n}`)
const die = (m) => { console.error(`\n  HATA: ${m}\n`); process.exit(1) }

// --- CSV: tirnakli alanlar ve icindeki virguller dogru ayrilmali
function parseCsv(text) {
  const rows = []
  let row = [], field = '', q = false
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if (q) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++ }
      else if (c === '"') q = false
      else field += c
    } else if (c === '"') q = true
    else if (c === ',') { row.push(field); field = '' }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = '' }
    else if (c !== '\r') field += c
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row) }
  return rows
}

const csv = parseCsv(await readFile('locale/foldera.csv', 'utf8'))
const header = csv[0]
const strings = {}
for (const r of csv.slice(1)) {
  if (!r[0]) continue
  strings[r[0]] = Object.fromEntries(header.slice(1).map((lang, i) => [lang, r[i + 1]]))
}

async function token(keyPath) {
  const sa = JSON.parse(await readFile(keyPath, 'utf8'))
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
  const now = Math.floor(Date.now() / 1000)
  const head = b64({ alg: 'RS256', typ: 'JWT' })
  const claim = b64({ iss: sa.client_email, scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 })
  const s = createSign('RSA-SHA256'); s.update(`${head}.${claim}`)
  const assertion = `${head}.${claim}.${Buffer.from(s.sign(sa.private_key)).toString('base64url')}`
  const res = await fetch('https://oauth2.googleapis.com/token', { method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }) })
  const b = await res.json()
  if (!res.ok) die(`token alinamadi: ${JSON.stringify(b)}`)
  console.log(`  kimlik: ${sa.client_email}`)
  return b.access_token
}

const keyPath = opt('key')
if (!keyPath) die('--key <servis-hesabi.json> gerekli')
if (!existsSync(keyPath)) die(`anahtar bulunamadi: ${keyPath}`)

console.log(`\nFOLDERA -> uygulama ici urunler  (${PKG})`)
const tok = await token(keyPath)
const H = { authorization: `Bearer ${tok}`, 'content-type': 'application/json' }

for (const p of PRODUCTS) {
  const listings = {}
  for (const [dir, lang] of Object.entries(LOCALES)) {
    const title = (strings[p.titleKey]?.[dir] ?? '').trim()
    const desc = (strings[p.descKey]?.[dir] ?? '').trim()
    if (!title || !desc) die(`${p.sku}: ${dir} dilinde metin eksik`)
    if ([...title].length > TITLE_MAX) die(`${p.sku}/${dir}: baslik ${[...title].length} karakter (en fazla ${TITLE_MAX})`)
    if ([...desc].length > DESC_MAX) die(`${p.sku}/${dir}: aciklama ${[...desc].length} karakter (en fazla ${DESC_MAX})`)
    listings[lang] = { title, description: desc }
  }


console.log('\n  Bitti. Urunler Play Console > Uygulama ici urunler altinda.\n')
  // YENI API. `inappproducts` ucu artik 403 "Please migrate to the new
  // publishing API" donuyor; yerine monetization.onetimeproducts geldi.
  // Google'in kendi yollarinda buyuk/kucuk harf tutarsiz: patch kucuk harfli
  // `onetimeproducts`, list/get camelCase `oneTimeProducts` istiyor.
  //
  // `legacyCompatible: true` SART: eklenti `purchase(product_id)` diye sade
  // cagri yapiyor, satin alma secenegi kimligi vermiyor. Bu bayrak olmadan
  // urun o akista satin alinamaz.
  const listingArr = Object.entries(LOCALES).map(([dir, lang]) => ({
    languageCode: lang,
    title: strings[p.titleKey][dir].trim(),
    description: strings[p.descKey][dir].trim(),
  }))
  const price = { currencyCode: 'TRY', units: String(p.lira), nanos: 0 }

  const body = {
    packageName: PKG,
    productId: p.sku,
    listings: listingArr,
    purchaseOptions: [{
      purchaseOptionId: 'base',
      state: 'ACTIVE',
      buyOption: { legacyCompatible: true, multiQuantityEnabled: false },
      regionalPricingAndAvailabilityConfigs: [
        { regionCode: 'TR', price, availability: 'AVAILABLE' },
      ],
      // Google ileride yeni ulke eklerse urun fiyatsiz kalmasin.
      newRegionsConfig: {
        usdPrice: { currencyCode: 'USD', units: String(p.usd), nanos: 0 },
        eurPrice: { currencyCode: 'EUR', units: String(p.eur), nanos: 0 },
        availability: 'AVAILABLE',
      },
    }],
  }

  if (flag('dry')) {
    console.log(`  [kuru] ${p.sku.padEnd(10)} TRY ${p.lira}  ${listingArr.length} dil  "${listingArr[0].title}"`)
    continue
  }

  const qs = new URLSearchParams({
    updateMask: 'listings,purchaseOptions',
    allowMissing: 'true',
    'regionsVersion.version': REGIONS_VERSION,
  })
  const res = await fetch(`${API}/applications/${PKG}/onetimeproducts/${p.sku}?${qs}`,
    { method: 'PATCH', headers: H, body: JSON.stringify(body) })
  if (!res.ok) die(`${p.sku}: ${res.status} ${(await res.text()).slice(0, 500)}`)
  console.log(`  ${p.sku.padEnd(10)} TRY ${p.lira}  ${listingArr.length} dil  yazildi`)
}

console.log('\n  Bitti. Fiyat yalnizca TR icin yazildi -- diger ulkeler Play')
console.log('  Console > Urunler > fiyat donusturme ile doldurulmali.\n')
