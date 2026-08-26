class_name Tiles
## Tas kodlamasi:  code = kind * 16 + color   (0 == bos)

const EMPTY   := 0
const ILLEGAL := -1

const K_EMPTY  := 0
const K_NORMAL := 1
const K_LOCK   := 2   # mandal: uzerine hicbir sey katlanamaz, asla temizlenmez
const K_WILD   := 3   # joker: her renkle patlar

const LOCK := 32      # K_LOCK * 16
const WILD := 48      # K_WILD * 16

const COLOR_COUNT := 6


static func make(kind_: int, color_: int) -> int:
	return kind_ * 16 + color_


static func kind(code: int) -> int:
	return code >> 4


static func color(code: int) -> int:
	return code & 15


static func is_clearable(code: int) -> bool:
	## Seviyeyi bitirmek icin temizlenmesi gereken taslar
	var k := kind(code)
	return k == K_NORMAL or k == K_WILD


## Ust uste gelen iki hucrenin sonucu. ILLEGAL -> katlama reddedilir.
static func merge(a: int, b: int) -> int:
	if a == EMPTY:
		return b
	if b == EMPTY:
		return a
	var ka := kind(a)
	var kb := kind(b)
	if ka == K_LOCK or kb == K_LOCK:
		return ILLEGAL
	if ka == K_WILD or kb == K_WILD:
		return EMPTY          # joker her seyi patlatir
	if color(a) == color(b):
		return EMPTY          # ayni renk -> POP
	return ILLEGAL            # farkli renk -> kagit ust uste binemez
