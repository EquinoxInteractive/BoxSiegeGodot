class_name CosmeticsData
extends RefCounted
## DIHASILKAN oleh tools/gen_all.py - jangan edit tangan (ubah generatornya lalu jalankan ulang).

const RARITY_ORDER := ["common", "rare", "epic", "legendary"]
const EYE_Y := [75, 40, 40, 45, 65, 40, 45, 40, 55, 45, 60, 50, 78, 45, 60, 70, 65, 60, 70, 85, 80, 90, 70, 70]
## Tema skin karakter: [id, nama, rarity, harga]  (dipakai untuk SEMUA 24 karakter)
const CHAR_SKINS := [
	["gold_rush", "GOLD RUSH", "legendary", 1400],
	["cosmic", "COSMIC", "legendary", 1400],
	["neon_pulse", "NEON PULSE", "epic", 700],
	["inferno", "INFERNO", "epic", 700],
	["glitch", "GLITCH", "epic", 700],
	["frostbite", "FROSTBITE", "rare", 350],
	["toxic", "TOXIC", "rare", 350],
	["shadow", "SHADOW", "rare", 350],
	["sakura", "SAKURA", "common", 150],
	["pixel8", "8-BIT", "common", 150],
]
## Skin senjata per senjata: [id, nama, rarity, harga, warna_peluru_hex]
const WEAPON_SKINS := {
	"smith": [
		["golden_age", "GOLDEN AGE", "legendary", 2400, "d4142a"],
		["obsidian", "OBSIDIAN", "epic", 1200, "18e0ff"],
		["permafrost", "PERMAFROST", "rare", 600, "5cc8ff"],
		["magma_core", "MAGMA CORE", "epic", 1200, "ff7a10"],
		["venomous", "VENOMOUS", "rare", 600, "b6ff1a"],
	],
	"kurval": [
		["royal_guard", "ROYAL GUARD", "epic", 1200, "ffc828"],
		["jungle_camo", "JUNGLE CAMO", "common", 250, "ff8a1a"],
		["carbon_red", "CARBON RED", "rare", 600, "ff1f2e"],
		["sakura_blade", "SAKURA", "common", 250, "ff3d8f"],
		["prism", "PRISM", "legendary", 2400, "ff5ad0"],
	],
	"flamer": [
		["dragon_fire", "DRAGON FIRE", "epic", 1200, "ffcf1f"],
		["cosmic_flare", "COSMIC FLARE", "legendary", 2400, "ff4fd8"],
		["solar", "SOLAR", "epic", 1200, "ff6a00"],
		["toxic_waste", "TOXIC WASTE", "rare", 600, "ff9a1a"],
		["nightshade", "NIGHTSHADE", "common", 250, "b04dff"],
	],
	"scream": [
		["banshee", "BANSHEE", "epic", 1200, "ff3fd0"],
		["arctic_howl", "ARCTIC HOWL", "rare", 600, "9be8ff"],
		["voltage", "VOLTAGE", "epic", 1200, "ffe91f"],
		["sakura_scream", "SAKURA SCREAM", "common", 250, "ff2f7a"],
		["cosmic_echo", "COSMIC ECHO", "legendary", 2400, "4fe8ff"],
	],
	"pistol": [
		["golden_eagle", "GOLDEN EAGLE", "legendary", 2400, "ffd23f"],
		["desert_camo", "DESERT CAMO", "common", 250, "ff5a1a"],
		["neon_punk", "NEON PUNK", "epic", 1200, "ff2fd0"],
		["candy", "CANDY POP", "rare", 600, "3fe0ff"],
		["storm", "STORM", "rare", 600, "3f8fff"],
	],
	"knife": [
		["golden_blade", "GOLDEN BLADE", "legendary", 2400, "d4142a"],
		["frozen_fang", "FROZEN FANG", "rare", 600, "5cc8ff"],
		["magma_edge", "MAGMA EDGE", "epic", 1200, "ff7a10"],
		["toxic_shiv", "TOXIC SHIV", "rare", 600, "b6ff1a"],
		["prism_edge", "PRISM EDGE", "legendary", 2400, "ff5ad0"],
	],
}
## Aksesoris: [id, nama, slot, harga, rarity, layer]   slot: head/face/neck/back
const ACCESSORIES := [
	["crown", "ROYAL CROWN", "head", 900, "legendary", "front"],
	["tophat", "TOP HAT", "head", 300, "common", "front"],
	["party_hat", "PARTY HAT", "head", 150, "common", "front"],
	["halo", "HOLY HALO", "head", 700, "epic", "front"],
	["devil_horns", "DEVIL HORNS", "head", 450, "rare", "front"],
	["cowboy_hat", "COWBOY HAT", "head", 300, "common", "front"],
	["wizard_hat", "WIZARD HAT", "head", 600, "rare", "front"],
	["viking_helm", "VIKING HELM", "head", 550, "rare", "front"],
	["cat_ears", "CAT EARS", "head", 350, "common", "front"],
	["chef_hat", "CHEF HAT", "head", 250, "common", "front"],
	["sunglasses", "COOL SHADES", "face", 250, "common", "front"],
	["nerd_glasses", "NERD GLASSES", "face", 200, "common", "front"],
	["monocle", "GENTLE MONOCLE", "face", 400, "rare", "front"],
	["glasses_3d", "3D GLASSES", "face", 300, "common", "front"],
	["mustache", "BIG MUSTACHE", "face", 250, "common", "front"],
	["heart_glasses", "HEART SHADES", "face", 450, "rare", "front"],
	["cyber_visor", "CYBER VISOR", "face", 800, "epic", "front"],
	["clown_nose", "CLOWN NOSE", "face", 150, "common", "front"],
	["bandage", "BATTLE PATCH", "face", 150, "common", "front"],
	["scarf", "RED SCARF", "neck", 300, "common", "front"],
	["bowtie", "BOW TIE", "neck", 250, "common", "front"],
	["gold_chain", "GOLD CHAIN", "neck", 750, "epic", "front"],
	["hero_medal", "HERO MEDAL", "neck", 500, "rare", "front"],
	["bell_collar", "BELL COLLAR", "neck", 200, "common", "front"],
	["dog_tag", "DOG TAG", "neck", 350, "rare", "front"],
	["hero_cape", "HERO CAPE", "back", 650, "epic", "back"],
	["angel_wings", "ANGEL WINGS", "back", 1200, "legendary", "back"],
	["bat_wings", "BAT WINGS", "back", 900, "epic", "back"],
	["flame_aura", "FLAME AURA", "back", 1000, "legendary", "back"],
	["frost_aura", "FROST SPIKES", "back", 800, "epic", "back"],
	["thunder_aura", "THUNDER AURA", "back", 850, "epic", "back"],
]
