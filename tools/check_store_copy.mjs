#!/usr/bin/env node
//
// Magaza metinlerini yayindan ONCE denetler.
//
//   node tools/check_store_copy.mjs
//
// NEDEN AYRI BIR ARAC: oyun ici cevirileri `tests/test_logic.gd` denetliyor,
// ama magaza metinleri (baslik, kisa/tam aciklama) o tablonun disinda ve hic
// kontrol edilmiyordu. Play bunlari yayin aninda reddediyor; o noktada
// ogrenmek gec, cunku `play_publish.mjs` ilk hatada duruyor ve geri kalan
// dilleri hic denemiyor. Burasi hepsini birden gosteriyor.
//
import { readFile } from 'node:fs/promises'

const LIMITS = { title: 30, short: 80, full: 4000 }
const BASE = 'en'

const copy = JSON.parse(await readFile('store/copy.json', 'utf8'))
const langs = Object.keys(copy).sort()
const problems = []
const warnings = []

for (const lang of langs) {
  for (const [field, max] of Object.entries(LIMITS)) {
    const text = copy[lang]?.[field]
    if (typeof text !== 'string' || text.trim() === '') {
      problems.push(`${lang}.${field}: eksik veya bos`)
      continue
    }
    // Play karakter sayiyor, bayt degil. Emoji/aksanli harf bir karakter.
    const n = [...text].length
    if (n > max) problems.push(`${lang}.${field}: ${n} karakter (en fazla ${max})`)

    // Bastaki/sondaki bosluk Play'de goze batiyor ve sessizce kirpilmiyor.
    if (text !== text.trim()) problems.push(`${lang}.${field}: basta/sonda bosluk var`)
  }

  // Ingilizceyle BIREBIR ayni metin, cogu zaman atlanmis ceviridir. Marka
  // adi gecen basliklarda dogal olabilir, o yuzden bu bir UYARI.
  if (lang !== BASE) {
    for (const field of Object.keys(LIMITS)) {
      if (copy[lang]?.[field] && copy[lang][field] === copy[BASE][field]) {
        warnings.push(`${lang}.${field}: ingilizceyle birebir ayni -- ceviri atlanmis olabilir`)
      }
    }
  }
}

// Baslikta urun adi gecmeli: ASO'da marka aramasi bunun uzerinden geliyor.
for (const lang of langs) {
  const t = copy[lang]?.title ?? ''
  if (!t.toLowerCase().includes('foldera')) {
    problems.push(`${lang}.title: urun adi "Foldera" gecmiyor`)
  }
}

const width = Math.max(...langs.map((l) => l.length))
console.log('\nMagaza metni denetimi\n')
for (const lang of langs) {
  const c = copy[lang] ?? {}
  const n = (f) => String([...(c[f] ?? '')].length).padStart(4)
  console.log(`  ${lang.padEnd(width)}  baslik ${n('title')}/30   kisa ${n('short')}/80   tam ${n('full')}/4000`)
}

if (warnings.length) {
  console.log('\nUYARI:')
  for (const w of warnings) console.log(`  - ${w}`)
}
if (problems.length) {
  console.log('\nHATA:')
  for (const p of problems) console.log(`  - ${p}`)
  console.log(`\n${problems.length} sorun bulundu.\n`)
  process.exit(1)
}
console.log(`\n${langs.length} dil, sorun yok.\n`)
