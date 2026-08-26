extends RefCounted
##
## Magaza metinleri. Oyunun ICINDE kullanilmiyor -- bu yuzden locale/foldera.csv
## icine konmadi, `tools/` altinda duruyor ve surume hic girmiyor.
##
## ASO notlari (Google Play):
##   * baslik      : en fazla 30 karakter, anahtar kelime ICERMELI
##   * kisa aciklama: en fazla 80 karakter -- siralamada en agir metin alani
##   * ekran gorseli yazilari: kucuk kucuk resimde okunmali -> 2 satir, kisa
##   * ilk IKI ekran gorseli tiklanma oranini belirler; en guclu iki iddia orada
##
## Ceviriler makine kalitesinde; yayin oncesi ana dili konusan biri gozden
## gecirmeli. Ozellikle ru/uk/vi/pl icin.
##

## Ekran gorseli basliklari. Her dil icin 6 kare, sirasi ONEMLI.
##   0 mekanik/marka  1 ozgunluk  2 cikmaz yok  3 cevrimdisi+icerik
##   4 uc yildiz      5 baskisizlik
const SHOTS := {
"en": [
	{"h": "Fold the paper,\npop the pairs", "s": "One gesture. That is the whole game."},
	{"h": "One fold mirrors\nthe whole board", "s": "Not two tiles. Everything moves at once."},
	{"h": "You can never\nget stuck", "s": "Every level is verified solvable. Always."},
	{"h": "500 levels,\nzero internet", "s": "No account, no wifi, no downloads."},
	{"h": "Three stars means\nthe shortest path", "s": "Finishing is easy. Perfection is not."},
	{"h": "No timers,\nno pressure", "s": "Think at your own pace. The paper waits."},
],
"tr": [
	{"h": "Kâğıdı katla,\neşleri patlat", "s": "Tek jest. Oyunun tamamı bu."},
	{"h": "Bir katlama\ntüm tahtayı aynalar", "s": "İki taş değil. Her şey aynı anda oynar."},
	{"h": "Asla çıkmaza\ndüşemezsin", "s": "Her seviye çözülebilir olarak doğrulandı."},
	{"h": "500 seviye,\nsıfır internet", "s": "Hesap yok, wifi yok, indirme yok."},
	{"h": "Üç yıldız\nen kısa çözüm demek", "s": "Bitirmek kolay. Kusursuzluk değil."},
	{"h": "Süre yok,\nbaskı yok", "s": "Kendi hızında düşün. Kâğıt bekler."},
],
"es": [
	{"h": "Dobla el papel,\nrevienta las parejas", "s": "Un gesto. Ese es todo el juego."},
	{"h": "Un doblez refleja\ntodo el tablero", "s": "No dos fichas. Todo se mueve a la vez."},
	{"h": "Nunca puedes\nquedarte atascado", "s": "Cada nivel está verificado como resoluble."},
	{"h": "500 niveles,\ncero internet", "s": "Sin cuenta, sin wifi, sin descargas."},
	{"h": "Tres estrellas es\nla solución más corta", "s": "Terminar es fácil. La perfección no."},
	{"h": "Sin tiempo,\nsin presión", "s": "Piensa a tu ritmo. El papel espera."},
],
"pt": [
	{"h": "Dobre o papel,\nestoure os pares", "s": "Um gesto. É o jogo inteiro."},
	{"h": "Uma dobra espelha\no tabuleiro todo", "s": "Não duas peças. Tudo se move junto."},
	{"h": "Você nunca\nfica preso", "s": "Cada nível é verificado como solucionável."},
	{"h": "500 níveis,\nzero internet", "s": "Sem conta, sem wifi, sem downloads."},
	{"h": "Três estrelas é\na solução mais curta", "s": "Terminar é fácil. Perfeição não é."},
	{"h": "Sem tempo,\nsem pressão", "s": "Pense no seu ritmo. O papel espera."},
],
"de": [
	{"h": "Falte das Papier,\nlöse die Paare", "s": "Eine Geste. Das ist das ganze Spiel."},
	{"h": "Eine Faltung spiegelt\ndas ganze Feld", "s": "Nicht zwei Steine. Alles bewegt sich."},
	{"h": "Du kannst nie\nfeststecken", "s": "Jedes Level ist als lösbar geprüft."},
	{"h": "500 Level,\nnull Internet", "s": "Kein Konto, kein WLAN, kein Download."},
	{"h": "Drei Sterne heißt\nkürzester Weg", "s": "Schaffen ist leicht. Perfekt nicht."},
	{"h": "Keine Zeit,\nkein Druck", "s": "Denk in deinem Tempo. Papier wartet."},
],
"fr": [
	{"h": "Plie le papier,\nfais éclater les paires", "s": "Un geste. C'est tout le jeu."},
	{"h": "Un pli reflète\ntout le plateau", "s": "Pas deux tuiles. Tout bouge d'un coup."},
	{"h": "Tu ne peux jamais\nte bloquer", "s": "Chaque niveau est vérifié comme soluble."},
	{"h": "500 niveaux,\nzéro internet", "s": "Sans compte, sans wifi, sans téléchargement."},
	{"h": "Trois étoiles,\nc'est le chemin le plus court", "s": "Finir est facile. Être parfait non."},
	{"h": "Pas de minuteur,\npas de pression", "s": "Réfléchis à ton rythme. Le papier attend."},
],
"it": [
	{"h": "Piega la carta,\nfai scoppiare le coppie", "s": "Un gesto. È tutto il gioco."},
	{"h": "Una piega specchia\ntutta la griglia", "s": "Non due tessere. Si muove tutto."},
	{"h": "Non puoi mai\nrestare bloccato", "s": "Ogni livello è verificato risolvibile."},
	{"h": "500 livelli,\nzero internet", "s": "Nessun account, niente wifi, niente download."},
	{"h": "Tre stelle è\nla via più corta", "s": "Finire è facile. La perfezione no."},
	{"h": "Niente timer,\nniente pressione", "s": "Pensa con calma. La carta aspetta."},
],
"ru": [
	{"h": "Сложи бумагу,\nсхлопни пары", "s": "Один жест. В этом вся игра."},
	{"h": "Один сгиб зеркалит\nвсё поле", "s": "Не две фишки. Двигается всё сразу."},
	{"h": "Ты никогда\nне застрянешь", "s": "Каждый уровень проверен на решаемость."},
	{"h": "500 уровней,\nноль интернета", "s": "Без аккаунта, без wifi, без загрузок."},
	{"h": "Три звезды —\nсамый короткий путь", "s": "Пройти легко. Идеально — нет."},
	{"h": "Без таймера,\nбез давления", "s": "Думай в своём темпе. Бумага подождёт."},
],
"pl": [
	{"h": "Złóż papier,\nrozbij pary", "s": "Jeden gest. To cała gra."},
	{"h": "Jedno złożenie\nodbija całą planszę", "s": "Nie dwa kafelki. Rusza się wszystko."},
	{"h": "Nigdy nie\nutkniesz", "s": "Każdy poziom sprawdzony jako rozwiązywalny."},
	{"h": "500 poziomów,\nzero internetu", "s": "Bez konta, bez wifi, bez pobierania."},
	{"h": "Trzy gwiazdki to\nnajkrótsza droga", "s": "Ukończyć łatwo. Perfekcyjnie nie."},
	{"h": "Bez czasu,\nbez presji", "s": "Myśl we własnym tempie. Papier poczeka."},
],
"nl": [
	{"h": "Vouw het papier,\nknal de paren", "s": "Eén gebaar. Dat is het hele spel."},
	{"h": "Eén vouw spiegelt\nhet hele bord", "s": "Niet twee tegels. Alles beweegt tegelijk."},
	{"h": "Je kunt nooit\nvastlopen", "s": "Elk level is geverifieerd oplosbaar."},
	{"h": "500 levels,\nnul internet", "s": "Geen account, geen wifi, geen downloads."},
	{"h": "Drie sterren is\nde kortste weg", "s": "Uitspelen is makkelijk. Perfect niet."},
	{"h": "Geen timer,\ngeen druk", "s": "Denk op je eigen tempo. Papier wacht."},
],
"id": [
	{"h": "Lipat kertasnya,\nledakkan pasangan", "s": "Satu gerakan. Itu seluruh permainannya."},
	{"h": "Satu lipatan\nmencerminkan seluruh papan", "s": "Bukan dua ubin. Semua bergerak sekaligus."},
	{"h": "Kamu tidak akan\npernah buntu", "s": "Setiap level terverifikasi bisa diselesaikan."},
	{"h": "500 level,\nnol internet", "s": "Tanpa akun, tanpa wifi, tanpa unduhan."},
	{"h": "Tiga bintang berarti\njalur terpendek", "s": "Menyelesaikan mudah. Sempurna tidak."},
	{"h": "Tanpa waktu,\ntanpa tekanan", "s": "Berpikir sesuai temponya. Kertas menunggu."},
],
"vi": [
	{"h": "Gấp tờ giấy,\nnổ các cặp đôi", "s": "Một thao tác. Đó là cả trò chơi."},
	{"h": "Một nếp gấp\nphản chiếu cả bàn", "s": "Không phải hai ô. Tất cả cùng dịch chuyển."},
	{"h": "Bạn không bao giờ\nbị kẹt", "s": "Mỗi màn đều được kiểm chứng là giải được."},
	{"h": "500 màn chơi,\nkhông cần mạng", "s": "Không tài khoản, không wifi, không tải thêm."},
	{"h": "Ba sao nghĩa là\nđường đi ngắn nhất", "s": "Hoàn thành thì dễ. Hoàn hảo thì không."},
	{"h": "Không đếm giờ,\nkhông áp lực", "s": "Nghĩ theo nhịp của bạn. Giấy vẫn đợi."},
],
"uk": [
	{"h": "Склади папір,\nрозбий пари", "s": "Один жест. У цьому вся гра."},
	{"h": "Один згин дзеркалить\nусе поле", "s": "Не дві фішки. Рухається все одразу."},
	{"h": "Ти ніколи\nне застрягнеш", "s": "Кожен рівень перевірено на розв'язність."},
	{"h": "500 рівнів,\nнуль інтернету", "s": "Без акаунта, без wifi, без завантажень."},
	{"h": "Три зірки —\nнайкоротший шлях", "s": "Пройти легко. Ідеально — ні."},
	{"h": "Без таймера,\nбез тиску", "s": "Думай у своєму темпі. Папір зачекає."},
],
}


## Ozellik grafigi (1024x500) uzerindeki tek satirlik slogan.
const FEATURE := {
	"en": "Fold the paper, pop the pairs",
	"tr": "Kâğıdı katla, eşleri patlat",
	"es": "Dobla el papel, revienta las parejas",
	"pt": "Dobre o papel, estoure os pares",
	"de": "Falte das Papier, löse die Paare",
	"fr": "Plie le papier, fais éclater les paires",
	"it": "Piega la carta, fai scoppiare le coppie",
	"ru": "Сложи бумагу, схлопни пары",
	"pl": "Złóż papier, rozbij pary",
	"nl": "Vouw het papier, knal de paren",
	"id": "Lipat kertasnya, ledakkan pasangan",
	"vi": "Gấp tờ giấy, nổ các cặp đôi",
	"uk": "Склади папір, розбий пари",
}


## Play Console metinleri.  title <= 30, short <= 80 karakter.
const LISTING := {
"en": {
	"title": "Foldera: Paper Fold Puzzle",
	"short": "Fold the paper, pop the pairs. Offline logic puzzle you can never lose.",
	"full": """Foldera is a paper folding puzzle. Drag across the board and the paper folds — every tile mirrors at once. Matching pairs meet and pop.

WHY IT IS DIFFERENT
• One gesture moves the whole board, not two tiles.
• You can never get stuck. Every level is machine verified: whatever order you fold in, the board stays solvable.
• Three stars means you found the shortest solution. Finishing is easy, perfection is not.

WHAT IS INSIDE
• 500 handcrafted levels
• Fully offline — no account, no wifi, no timers
• Pins, jokers and shrinking paper add new rules as you go
• 13 languages
• Free to play

No countdown, no lives, no pressure. Just paper, folds and a quiet click when a pair pops.""",
},
"tr": {
	"title": "Foldera: Kâğıt Katlama Bulmaca",
	"short": "Kâğıdı katla, eşleri patlat. Çevrimdışı, çıkmazı olmayan zekâ bulmacası.",
	"full": """Foldera bir kâğıt katlama bulmacası. Tahtanın üzerinde parmağını kaydır, kâğıt katlanır — bütün taşlar aynı anda aynalanır. Kavuşan eşler patlar.

NEDEN FARKLI
• Tek jest iki taşı değil, tüm tahtayı oynatır.
• Asla çıkmaza düşemezsin. Her seviye makineyle doğrulandı: hangi sırayla katlarsan katla, tahta çözülebilir kalır.
• Üç yıldız en kısa çözümü bulduğun anlamına gelir. Bitirmek kolay, kusursuzluk değil.

İÇİNDE NE VAR
• 500 elden geçmiş seviye
• Tamamen çevrimdışı — hesap yok, wifi yok, süre yok
• Mandallar, jokerler ve küçülen kâğıt ilerledikçe yeni kurallar getirir
• 13 dil
• Ücretsiz

Geri sayım yok, can yok, baskı yok. Sadece kâğıt, katlar ve bir eş patladığında duyulan o küçük ses.""",
},
"es": {
	"title": "Foldera: Puzzle de Papel",
	"short": "Dobla el papel, revienta las parejas. Puzzle offline sin callejones sin salida.",
	"full": """Foldera es un puzzle de papel doblado. Desliza por el tablero y el papel se dobla: todas las fichas se reflejan a la vez. Las parejas que se encuentran revientan.

POR QUÉ ES DIFERENTE
• Un gesto mueve todo el tablero, no dos fichas.
• Nunca puedes quedarte atascado. Cada nivel está verificado: dobles en el orden que dobles, el tablero sigue teniendo solución.
• Tres estrellas significa que encontraste la solución más corta. Terminar es fácil, la perfección no.

QUÉ INCLUYE
• 500 niveles cuidados uno a uno
• Totalmente offline: sin cuenta, sin wifi, sin cronómetro
• Clavos, comodines y papel que encoge añaden reglas nuevas
• 13 idiomas
• Gratis

Sin cuenta atrás, sin vidas, sin presión. Solo papel, dobleces y un clic suave cuando una pareja revienta.""",
},
"pt": {
	"title": "Foldera: Quebra-Cabeça Papel",
	"short": "Dobre o papel, estoure os pares. Quebra-cabeça offline sem becos sem saída.",
	"full": """Foldera é um quebra-cabeça de dobrar papel. Arraste pelo tabuleiro e o papel dobra — todas as peças espelham de uma vez. Os pares que se encontram estouram.

POR QUE É DIFERENTE
• Um gesto move o tabuleiro inteiro, não duas peças.
• Você nunca fica preso. Cada nível é verificado: dobre na ordem que dobrar, o tabuleiro continua tendo solução.
• Três estrelas significa que você achou a solução mais curta. Terminar é fácil, perfeição não é.

O QUE TEM DENTRO
• 500 níveis feitos um a um
• Totalmente offline — sem conta, sem wifi, sem cronômetro
• Pinos, curingas e papel que encolhe trazem regras novas
• 13 idiomas
• Grátis

Sem contagem regressiva, sem vidas, sem pressão. Só papel, dobras e um clique suave quando um par estoura.""",
},
"de": {
	"title": "Foldera: Papier Faltpuzzle",
	"short": "Falte das Papier, löse die Paare. Offline Logikpuzzle ohne Sackgassen.",
	"full": """Foldera ist ein Papierfalt-Puzzle. Zieh über das Feld und das Papier faltet sich — alle Steine spiegeln auf einmal. Passende Paare treffen sich und lösen sich auf.

WARUM ES ANDERS IST
• Eine Geste bewegt das ganze Feld, nicht zwei Steine.
• Du kannst nie feststecken. Jedes Level ist maschinell geprüft: egal in welcher Reihenfolge du faltest, das Feld bleibt lösbar.
• Drei Sterne heißt, du hast den kürzesten Weg gefunden. Schaffen ist leicht, perfekt sein nicht.

WAS DRIN IST
• 500 handgeprüfte Level
• Komplett offline — kein Konto, kein WLAN, keine Zeitbegrenzung
• Nadeln, Joker und schrumpfendes Papier bringen neue Regeln
• 13 Sprachen
• Kostenlos

Kein Countdown, keine Leben, kein Druck. Nur Papier, Faltungen und ein leises Klicken, wenn ein Paar verschwindet.""",
},
"fr": {
	"title": "Foldera : Puzzle de Pliage",
	"short": "Plie le papier, fais éclater les paires. Puzzle hors ligne sans impasse.",
	"full": """Foldera est un puzzle de pliage de papier. Glisse sur le plateau et le papier se plie — toutes les tuiles se reflètent d'un coup. Les paires qui se rejoignent éclatent.

POURQUOI C'EST DIFFÉRENT
• Un geste déplace tout le plateau, pas deux tuiles.
• Tu ne peux jamais te bloquer. Chaque niveau est vérifié : quel que soit l'ordre des plis, le plateau reste soluble.
• Trois étoiles veut dire que tu as trouvé la solution la plus courte. Finir est facile, être parfait non.

CE QU'IL Y A DEDANS
• 500 niveaux vérifiés un par un
• Entièrement hors ligne — sans compte, sans wifi, sans chrono
• Épingles, jokers et papier qui rétrécit ajoutent des règles
• 13 langues
• Gratuit

Pas de compte à rebours, pas de vies, pas de pression. Juste du papier, des plis et un petit clic quand une paire éclate.""",
},
"it": {
	"title": "Foldera: Puzzle di Carta",
	"short": "Piega la carta, fai scoppiare le coppie. Puzzle offline senza vicoli ciechi.",
	"full": """Foldera è un puzzle di carta piegata. Trascina sulla griglia e la carta si piega — tutte le tessere si specchiano insieme. Le coppie che si incontrano scoppiano.

PERCHÉ È DIVERSO
• Un gesto muove tutta la griglia, non due tessere.
• Non puoi mai restare bloccato. Ogni livello è verificato: in qualunque ordine pieghi, la griglia resta risolvibile.
• Tre stelle vuol dire che hai trovato la soluzione più corta. Finire è facile, la perfezione no.

COSA C'È DENTRO
• 500 livelli curati uno a uno
• Completamente offline — nessun account, niente wifi, niente timer
• Spilli, jolly e carta che si restringe portano regole nuove
• 13 lingue
• Gratis

Nessun conto alla rovescia, nessuna vita, nessuna pressione. Solo carta, pieghe e un piccolo clic quando una coppia scoppia.""",
},
"ru": {
	"title": "Foldera: Бумажная головоломка",
	"short": "Сложи бумагу, схлопни пары. Офлайн головоломка без тупиков.",
	"full": """Foldera — головоломка со складыванием бумаги. Проведи пальцем по полю, и бумага сложится: все фишки зеркалятся разом. Совпавшие пары схлопываются.

ЧЕМ ОНА ОТЛИЧАЕТСЯ
• Один жест двигает всё поле, а не две фишки.
• Ты никогда не застрянешь. Каждый уровень проверен машиной: в каком бы порядке ты ни складывал, поле остаётся решаемым.
• Три звезды значит, что ты нашёл самое короткое решение. Пройти легко, сделать идеально — нет.

ЧТО ВНУТРИ
• 500 отобранных уровней
• Полностью офлайн — без аккаунта, без wifi, без таймера
• Булавки, джокеры и уменьшающаяся бумага добавляют новые правила
• 13 языков
• Бесплатно

Ни обратного отсчёта, ни жизней, ни давления. Только бумага, сгибы и тихий щелчок, когда пара исчезает.""",
},
"pl": {
	"title": "Foldera: Papierowa Łamigłówka",
	"short": "Złóż papier, rozbij pary. Łamigłówka offline bez ślepych zaułków.",
	"full": """Foldera to łamigłówka ze składaniem papieru. Przeciągnij po planszy, a papier się złoży — wszystkie kafelki odbijają się naraz. Pasujące pary spotykają się i znikają.

DLACZEGO JEST INNA
• Jeden gest rusza całą planszę, nie dwa kafelki.
• Nigdy nie utkniesz. Każdy poziom jest sprawdzony maszynowo: w jakiej kolejności byś nie składał, plansza zostaje rozwiązywalna.
• Trzy gwiazdki znaczą, że znalazłeś najkrótsze rozwiązanie. Ukończyć łatwo, zrobić to idealnie już nie.

CO JEST W ŚRODKU
• 500 dopracowanych poziomów
• Całkowicie offline — bez konta, bez wifi, bez zegara
• Szpilki, jokery i kurczący się papier dokładają nowe zasady
• 13 języków
• Za darmo

Bez odliczania, bez żyć, bez presji. Tylko papier, zagięcia i cichy klik, gdy para znika.""",
},
"nl": {
	"title": "Foldera: Papieren Puzzel",
	"short": "Vouw het papier, knal de paren. Offline puzzel zonder doodlopende wegen.",
	"full": """Foldera is een papiervouw-puzzel. Sleep over het bord en het papier vouwt — alle tegels spiegelen tegelijk. Paren die elkaar vinden knallen weg.

WAAROM HET ANDERS IS
• Eén gebaar beweegt het hele bord, niet twee tegels.
• Je kunt nooit vastlopen. Elk level is machinaal geverifieerd: in welke volgorde je ook vouwt, het bord blijft oplosbaar.
• Drie sterren betekent dat je de kortste oplossing vond. Uitspelen is makkelijk, perfect zijn niet.

WAT ERIN ZIT
• 500 stuk voor stuk gecontroleerde levels
• Volledig offline — geen account, geen wifi, geen klok
• Pinnen, jokers en krimpend papier voegen nieuwe regels toe
• 13 talen
• Gratis

Geen aftelklok, geen levens, geen druk. Alleen papier, vouwen en een zachte klik als een paar wegknalt.""",
},
"id": {
	"title": "Foldera: Teka-Teki Lipat",
	"short": "Lipat kertasnya, ledakkan pasangan. Teka-teki offline tanpa jalan buntu.",
	"full": """Foldera adalah teka-teki melipat kertas. Geser di atas papan dan kertas akan terlipat — semua ubin tercermin sekaligus. Pasangan yang bertemu akan meledak.

KENAPA BERBEDA
• Satu gerakan menggerakkan seluruh papan, bukan dua ubin.
• Kamu tidak akan pernah buntu. Setiap level diverifikasi mesin: dalam urutan apa pun kamu melipat, papan tetap bisa diselesaikan.
• Tiga bintang berarti kamu menemukan solusi terpendek. Menyelesaikan itu mudah, sempurna tidak.

ISINYA
• 500 level yang disaring satu per satu
• Sepenuhnya offline — tanpa akun, tanpa wifi, tanpa timer
• Pin, joker, dan kertas yang menyusut menambah aturan baru
• 13 bahasa
• Gratis

Tanpa hitung mundur, tanpa nyawa, tanpa tekanan. Hanya kertas, lipatan, dan bunyi klik pelan saat sepasang meledak.""",
},
"vi": {
	"title": "Foldera: Xếp Giấy Giải Đố",
	"short": "Gấp tờ giấy, nổ các cặp đôi. Game giải đố offline không bao giờ bí.",
	"full": """Foldera là trò giải đố gấp giấy. Kéo tay trên bàn cờ và tờ giấy sẽ gấp lại — mọi ô đều được phản chiếu cùng lúc. Các cặp gặp nhau sẽ nổ.

ĐIỀU KHÁC BIỆT
• Một thao tác làm dịch chuyển cả bàn cờ, không phải hai ô.
• Bạn không bao giờ bị kẹt. Mỗi màn đều được máy kiểm chứng: gấp theo thứ tự nào thì bàn cờ vẫn giải được.
• Ba sao nghĩa là bạn đã tìm ra lời giải ngắn nhất. Hoàn thành thì dễ, hoàn hảo thì không.

BÊN TRONG CÓ GÌ
• 500 màn chơi được chọn lọc từng cái một
• Hoàn toàn offline — không tài khoản, không wifi, không đồng hồ
• Ghim, lá joker và tờ giấy co lại mang tới luật mới
• 13 ngôn ngữ
• Miễn phí

Không đếm ngược, không mạng sống, không áp lực. Chỉ có giấy, nếp gấp và một tiếng tách nhẹ khi một cặp biến mất.""",
},
"uk": {
	"title": "Foldera: Паперова головоломка",
	"short": "Склади папір, розбий пари. Офлайн головоломка без глухих кутів.",
	"full": """Foldera — головоломка зі складанням паперу. Проведи пальцем по полю, і папір складеться: усі фішки дзеркаляться одразу. Пари, що зустрілися, зникають.

ЧИМ ВОНА ІНША
• Один жест рухає все поле, а не дві фішки.
• Ти ніколи не застрягнеш. Кожен рівень перевірено машиною: у якому б порядку ти не складав, поле лишається розв'язним.
• Три зірки означають, що ти знайшов найкоротший розв'язок. Пройти легко, зробити ідеально — ні.

ЩО ВСЕРЕДИНІ
• 500 відібраних рівнів
• Повністю офлайн — без акаунта, без wifi, без таймера
• Шпильки, джокери та папір, що зменшується, додають нові правила
• 13 мов
• Безкоштовно

Ні зворотного відліку, ні життів, ні тиску. Лише папір, згини й тихий клац, коли пара зникає.""",
},
}
