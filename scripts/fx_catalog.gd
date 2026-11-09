class_name FxCatalog
extends RefCounted
## Katalog EFEK kosmetik premium (skin karakter berlevel, skin senjata berlevel + finisher, aksesoris beranimasi).
## Harga & rarity ada di cosmetics_data.gd (dihasilkan tools/gen_all.py). Di sini hanya tampilan efeknya:
##   - Skin karakter : LV1 = sprite saja | LV2 = + partikel | LV3 = + animasi (shader + aura / objek yang mengorbit)
##   - Skin senjata  : LV1 = sprite saja | LV2 = + partikel di senjata & jejak peluru | LV3 = + FINISHER kill terakhir
##   - Aksesoris     : tidak berlevel, langsung beranimasi

const CHAR := {
	"storm_caller": {"c1": "5fb8ff", "c2": "ffe84a", "c3": "ffffff", "a": "storm", "add": true,
		"l2": "Electric sparks and mini arcs crackle around your fighter",
		"l3": "Living thunderstorm: strobing flashes, jumping bolts, orbiting plasma"},
	"spirit_bloom": {"c1": "ff9ac8", "c2": "3fe0b0", "c3": "fff0a0", "a": "spirit", "add": true,
		"l2": "Cherry petals and spirit lights drift around your fighter",
		"l3": "Breathing spirit aura: swaying skin, orbiting wisps with comet trails"},
	"prismatic": {"c1": "ff6ad0", "c2": "6ad8ff", "c3": "ffffff", "a": "holo", "add": true,
		"l2": "Rainbow glitter twinkles and trails off your fighter",
		"l3": "Holographic skin: color-cycling shimmer, rotating light rays, orbiting prisms"},
	"solar_flare": {"c1": "ffb21f", "c2": "ff5a1a", "c3": "fff6c0", "a": "solar", "add": true,
		"l2": "Rising embers and flare sparks burn off your fighter",
		"l3": "Mini sun: heat-wave skin, rotating corona, dancing flames"},
	"void_walker": {"c1": "a040ff", "c2": "ff40d0", "c3": "e8c8ff", "a": "void", "add": false,
		"l2": "Void motes spiral in and dark wisps trail your fighter",
		"l3": "Gravity well: rippling skin, accretion ring, inward shockwaves"},
}

## Keluarga efek senjata: warna utama (c1) & aksen (c2). Dipakai partikel (LV2) dan finisher (LV3).
const FAM := {
	"void": {"c1": "a040ff", "c2": "ff40d0"},
	"storm": {"c1": "5fb8ff", "c2": "ffe84a"},
	"dragon": {"c1": "ffb21f", "c2": "ff5a1a"},
	"cyber": {"c1": "2ff0ff", "c2": "ff2fd0"},
	"crystal": {"c1": "9be8ff", "c2": "ffffff"},
	"holy": {"c1": "ffe27a", "c2": "ffffff"},
	"blossom": {"c1": "ff9ac8", "c2": "ffe8f0"},
	"nova": {"c1": "4fe8ff", "c2": "ff4fd8"},
	"venom": {"c1": "b6ff1a", "c2": "6aff3a"},
	"jackpot": {"c1": "ffd23f", "c2": "fff6b0"},
	"prism": {"c1": "ff6ad0", "c2": "ffffff"},
	"magma": {"c1": "ff7a10", "c2": "ffd23f"},
	# ---- keluarga baru (gelombang 2)
	"meteor": {"c1": "ff7a1a", "c2": "ffd23f"},
	"tsunami": {"c1": "3fb8ff", "c2": "e8fbff"},
	"reaper": {"c1": "5affb0", "c2": "c8ffe8"},
	"portal": {"c1": "a050ff", "c2": "ff9a3a"},
	"sands": {"c1": "e8c068", "c2": "20e0d0"},
	"firework": {"c1": "ff5ad0", "c2": "ffd23f"},
	"orbital": {"c1": "ff2a2a", "c2": "ffb0a0"},
	"hex": {"c1": "d04aff", "c2": "ff3a8a"},
	"balloon": {"c1": "ff6ab8", "c2": "5ae0ff"},
	"ufo": {"c1": "7aff5a", "c2": "e8ffd8"},
}

## skin senjata premium -> keluarga (+ warna khusus kalau perlu)
const WEAPON := {
	"void_reaper": {"fam": "void"}, "thunder_god": {"fam": "storm"}, "solar_dragon": {"fam": "dragon"},
	"cyber_ronin": {"fam": "cyber"}, "crystal_king": {"fam": "crystal"},
	"nova_lance": {"fam": "nova"}, "holy_judgment": {"fam": "holy"}, "blood_moon": {"fam": "magma", "c1": "ff1f2e", "c2": "ff7a10"},
	"matrix_code": {"fam": "cyber", "c1": "40ff90", "c2": "2ff0ff"}, "glacier_fang": {"fam": "crystal", "c1": "5cc8ff"},
	"phoenix_rebirth": {"fam": "magma"}, "golden_jackpot": {"fam": "jackpot"}, "plague_doctor": {"fam": "venom"},
	"spirit_lantern": {"fam": "blossom"}, "void_furnace": {"fam": "void", "c2": "ff7a10"},
	"cosmic_choir": {"fam": "nova"}, "storm_siren": {"fam": "storm", "c1": "9be8ff"}, "sakura_requiem": {"fam": "blossom", "c1": "ff2f7a"},
	"neon_static": {"fam": "cyber", "c1": "ffe91f"}, "frozen_aria": {"fam": "crystal"},
	"jackpot_king": {"fam": "jackpot"}, "phantom_void": {"fam": "void"}, "dragon_breath": {"fam": "dragon", "c1": "ff6a00"},
	"angel_judge": {"fam": "holy", "c1": "bff4ff"}, "toxic_viper": {"fam": "venom", "c1": "ff9a1a"},
	"prism_slicer": {"fam": "prism"}, "shadow_fang": {"fam": "void", "c1": "9b3dff"}, "thunder_edge": {"fam": "storm"},
	"blossom_edge": {"fam": "blossom"}, "venom_shiv": {"fam": "venom"},
	# ---- gelombang 2 (finisher baru)
	"meteor_crash": {"fam": "meteor"}, "tidal_wrath": {"fam": "tsunami"}, "grim_harvest": {"fam": "reaper"},
	"orbital_lance": {"fam": "orbital"}, "sands_of_ra": {"fam": "sands"},
	"rift_breaker": {"fam": "portal"}, "first_contact": {"fam": "ufo"}, "grand_finale": {"fam": "firework"},
	"hexed_sigil": {"fam": "hex"}, "bubble_trouble": {"fam": "balloon"},
	"doomsday_comet": {"fam": "meteor", "c1": "ffcf1f", "c2": "ff5a1a"}, "soul_burner": {"fam": "reaper", "c1": "60e0ff", "c2": "d8f4ff"},
	"pyro_festival": {"fam": "firework", "c1": "ff6a00", "c2": "ffe84a"}, "hellfire_sigil": {"fam": "hex", "c1": "ff3a1a", "c2": "ffb21f"},
	"desert_mirage": {"fam": "sands", "c1": "ff9a3a", "c2": "ffd23f"},
	"echo_dimension": {"fam": "portal", "c1": "4fe8ff", "c2": "ff4fd8"}, "siren_tide": {"fam": "tsunami", "c1": "20d0c0", "c2": "ff4fd8"},
	"alien_anthem": {"fam": "ufo", "c1": "5aff8a", "c2": "d8fff0"}, "pop_diva": {"fam": "balloon", "c1": "ffe91f", "c2": "ff4fd8"},
	"satellite_scream": {"fam": "orbital", "c1": "40a0ff", "c2": "d0ecff"},
	"shooting_star": {"fam": "meteor", "c1": "ffe27a", "c2": "7ad8ff"}, "rift_runner": {"fam": "portal", "c1": "40ff90", "c2": "2fd0ff"},
	"ufo_hunter": {"fam": "ufo", "c1": "ff4fd8", "c2": "ffd0f0"}, "splash_blaster": {"fam": "tsunami", "c1": "3fe0e0", "c2": "f0ffff"},
	"gumball_gun": {"fam": "balloon", "c1": "ff4fa0", "c2": "5aff9a"},
	"death_scythe": {"fam": "reaper", "c1": "ff1f2e", "c2": "ffb0b0"}, "sandstorm": {"fam": "sands", "c1": "e8a050", "c2": "20e0d0"},
	"sky_burst": {"fam": "firework", "c1": "ff3a6a", "c2": "5ae0ff"}, "orbital_blade": {"fam": "orbital", "c1": "ffb21f", "c2": "fff0c0"},
	"cursed_talisman": {"fam": "hex", "c1": "ff3a8a", "c2": "ffd0e8"},
}

const FAM_L2 := {
	"void": "Void motes get sucked toward the weapon; bullets leave dark wisps",
	"storm": "Sparks jump along the weapon; bullets crackle with electricity",
	"dragon": "Embers float off the weapon; bullets burn with a flame trail",
	"cyber": "Glitching pixels spill off the weapon; bullets leave data bits",
	"crystal": "Crystal glints twinkle on the weapon; bullets shed ice sparkles",
	"holy": "Golden feathers and light float off the weapon; bullets shine",
	"blossom": "Petals fall from the weapon; bullets scatter petals",
	"nova": "Stars twinkle around the weapon; bullets leave star dust",
	"venom": "Toxic bubbles rise off the weapon; bullets drip poison",
	"jackpot": "Golden coins glint off the weapon; bullets shed gold dust",
	"prism": "Rainbow glints dance on the blade; the cut leaves color trails",
	"magma": "Lava embers rise off the weapon; bullets trail fire",
	"meteor": "Burning rock chips and embers orbit the weapon; bullets streak like comets",
	"tsunami": "Water droplets and foam bubble off the weapon; bullets leave a splash trail",
	"reaper": "Soul wisps drift off the weapon; bullets leave ghostly flames",
	"portal": "Mini rifts spark on the weapon; bullets leave swirling portal rings",
	"sands": "Golden sand grains blow off the weapon; bullets trail sand",
	"firework": "Sparklers fizz on the weapon; bullets burst into colorful sparks",
	"orbital": "Targeting lasers and data pings sweep over the weapon; bullets leave red pings",
	"hex": "Cursed runes float around the weapon; bullets leave glowing sigils",
	"balloon": "Little bubbles and confetti float off the weapon; bullets leave bubble trails",
	"ufo": "Alien lights blink and tiny sparks lift off the weapon; bullets leave green orbs",
}

## Finisher (LV3): nama + penjelasan. Dipakai panel preview.
const FIN := {
	"blackhole": {"name": "EVENT HORIZON", "desc": "A black hole opens and swallows the last victim"},
	"lightning": {"name": "WRATH OF STORM", "desc": "A giant thunderbolt strikes the last victim down"},
	"inferno": {"name": "BURN TO ASH", "desc": "A fire pillar turns the last victim into ash"},
	"glitch": {"name": "SYSTEM CRASH", "desc": "The last victim glitches and shuts down like old TV"},
	"shatter": {"name": "FLASH FREEZE", "desc": "The last victim freezes solid and shatters"},
	"ascend": {"name": "ASCENSION", "desc": "A holy light lifts the last victim to the sky"},
	"petals": {"name": "PETAL STORM", "desc": "The last victim turns into a vortex of petals"},
	"cosmic": {"name": "SUPERNOVA", "desc": "The last victim becomes stars and explodes"},
	"toxic": {"name": "MELTDOWN", "desc": "The last victim melts into a toxic puddle"},
	"jackpot": {"name": "JACKPOT!", "desc": "The last victim bursts into a fountain of gold"},
	"slice": {"name": "PRISM CUT", "desc": "Two rainbow slashes cut the last victim apart"},
	"meteor": {"name": "METEOR STRIKE", "desc": "A flaming meteor crashes down and flattens the last victim"},
	"tsunami": {"name": "TIDAL CRASH", "desc": "A giant wave crashes over the arena and washes the last victim away"},
	"reaper": {"name": "SOUL HARVEST", "desc": "A spectral scythe rips out the last victim's soul and leaves a gravestone"},
	"portal": {"name": "DIMENSION RIFT", "desc": "A rift tears open under the last victim and swallows them whole"},
	"sands": {"name": "SANDS OF TIME", "desc": "A giant hourglass turns and the last victim crumbles into sand"},
	"firework": {"name": "GRAND FINALE", "desc": "The last victim is launched like a rocket and bursts into fireworks"},
	"orbital": {"name": "ORBITAL STRIKE", "desc": "A satellite locks on and fires a death beam from orbit"},
	"hex": {"name": "CURSED SEAL", "desc": "A cursed seal binds the last victim in chains and crushes them into a sigil"},
	"balloon": {"name": "POP!", "desc": "The last victim inflates like a balloon, floats away and bursts into confetti"},
	"ufo": {"name": "ABDUCTION", "desc": "A UFO beams the last victim up and blasts off into the sky"},
}

## Aksesoris beranimasi: id -> [warna1, warna2, deskripsi animasi]
const ACC := {
	"starfall_crown": ["ffcf2a", "4fd8ff", "Floating stars orbit the crown and twinkle"],
	"hellfire_horns": ["ff6a1f", "ffb21f", "Flames flicker on the horns and embers rise"],
	"storm_cloud": ["8ab4ff", "ffe84a", "A tiny storm: rain falls and lightning flashes"],
	"scan_visor": ["40f0ff", "ffffff", "A scanning beam sweeps across the visor"],
	"love_struck": ["ff3d8f", "ffd0e4", "Heartbeat pulse and hearts float up"],
	"arc_core": ["40d8ff", "e8ffff", "Pulsing reactor core with spinning ring and sparks"],
	"comet_scarf": ["2fc4d8", "fff6b0", "The scarf waves and sheds stardust"],
	"spirit_wings": ["7af0ff", "c490ff", "The wings flap slowly and shed glowing feathers"],
	"event_horizon": ["a040ff", "ff9a3a", "A swirling accretion ring with orbiting matter"],
	"rocket_pack": ["ffb21f", "ff5a1a", "Rocket thrusters burn with flame and sparks"],
}


static func col(h: String) -> Color:
	return Color(h)


static func has_char_fx(sid: String) -> bool:
	return CHAR.has(sid)


static func char_info(sid: String) -> Dictionary:
	return CHAR.get(sid, {})


static func char_colors(sid: String) -> Array:
	var d: Dictionary = CHAR.get(sid, {})
	if d.is_empty():
		return [Color.WHITE, Color.WHITE, Color.WHITE]
	return [Color(String(d["c1"])), Color(String(d["c2"])), Color(String(d["c3"]))]


static func has_weapon_fx(sid: String) -> bool:
	return WEAPON.has(sid)


## {"fam": id, "c1": Color, "c2": Color}
static func weapon_info(sid: String) -> Dictionary:
	var w: Dictionary = WEAPON.get(sid, {})
	if w.is_empty():
		return {}
	var fam: String = String(w["fam"])
	var f: Dictionary = FAM[fam]
	return {"fam": fam, "c1": Color(String(w.get("c1", f["c1"]))), "c2": Color(String(w.get("c2", f["c2"])))}


static func has_acc_fx(aid: String) -> bool:
	return ACC.has(aid)


static func acc_colors(aid: String) -> Array:
	var a: Array = ACC.get(aid, ["ffffff", "ffffff", ""])
	return [Color(String(a[0])), Color(String(a[1]))]
