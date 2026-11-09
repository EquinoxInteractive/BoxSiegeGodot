class_name FxRig
extends RefCounted
## Memasang efek kosmetik premium ke sebuah Player (partikel & shader skin karakter, partikel senjata).


## Skin karakter LV2+: partikel (depan / belakang); LV3: shader animasi di sprite badan. Mengembalikan node yang dibuat.
static func attach_char(body: Sprite2D, player: Node, skin: String, lv: int, k_mul: float = 2.2) -> Array:
	var made: Array = []
	if lv < 2 or not FxCatalog.has_char_fx(skin):
		return made
	var back: FxNode = FxNode.make(FxNode.Kind.CHAR_BACK, skin, lv)
	back.player = player
	back.name = "FxBack"
	back.k_mul = k_mul
	body.add_child(back)
	var front: FxNode = FxNode.make(FxNode.Kind.CHAR_FRONT, skin, lv)
	front.player = player
	front.name = "FxFront"
	front.k_mul = k_mul
	body.add_child(front)
	front.bind_body(body)
	made.append(back)
	made.append(front)
	return made


## Satu node partikel senjata: otomatis mengikuti senjata yang sedang dipegang & hanya tampil kalau skinnya LV2+.
static func attach_weapon(player: Node2D, wskins: Dictionary, wlv: Dictionary) -> Array:
	var any: bool = false
	for w in wskins:
		if int(wlv.get(w, 1)) >= 2 and FxCatalog.has_weapon_fx(String(wskins[w])):
			any = true
	if not any:
		return []
	var n: FxNode = FxNode.make(FxNode.Kind.WEAPON, "", 2)
	n.player = player
	n.name = "FxWeapon"
	player.add_child(n)
	return [n]
