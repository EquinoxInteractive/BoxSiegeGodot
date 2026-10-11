class_name NavMap
extends RefCounted
## Peta navigasi musuh (campaign): permukaan platform = simpul, lompat / turun = sisi.
## Dibangun sekali per level dari data map (solids, platforms, crumble, moving, bounce).
## Angka jangkauan dihitung dari fisika pemain: lompat maks ~144 px, lari 340 px/detik, gravitasi 2000.
##
## Simpul : {x0, x1, y, solid, mp (MovingPlatform / null), w, ux0, ux1}  (ux = rentang gerak gabungan untuk platform bergerak)
## Sisi   : {to, kind, pad_x}
##   kind "up"           lompat naik ke platform yang lebih tinggi
##   kind "gap"          lompat menyeberang celah di ketinggian yang sama
##   kind "drop_through" tekan BAWAH di platform tipis supaya jatuh ke platform di bawahnya
##   kind "drop_side"    berjalan keluar dari tepi platform lalu jatuh (boleh sambil melompat kalau celahnya lebar)
##   kind "pad"          naik lewat jamur pantul (pad_x = tengah jamur)

const JUMP_UP := 136.0

var nodes: Array = []
var edges: Array = []          # edges[i] = Array[Dictionary]


static func reach_up(rise: float) -> float:
	return 0.78 * (340.0 * (0.38 + sqrt(maxf(144.0 - rise, 0.0) / 1000.0)) - 20.0)


static func reach_drop(d: float) -> float:
	return 0.78 * (340.0 * (0.38 + sqrt((144.0 + d) / 1000.0)) - 20.0)


func build(map: Dictionary, moving: Array) -> void:
	nodes.clear()
	edges.clear()
	for r in map["solids"]:
		_add_static(r, true)
	for r in map["platforms"]:
		_add_static(r, false)
	for r in map.get("crumble", []):
		_add_static(r, false, true)
	var mdefs: Array = map.get("moving", [])
	for i in mdefs.size():
		var d: Dictionary = mdefs[i]
		var rect: Rect2 = d["rect"]
		var mv: Vector2 = d["move"]
		nodes.append({"x0": rect.position.x, "x1": rect.end.x, "y": rect.position.y, "solid": false,
			"mp": moving[i] if i < moving.size() else null, "w": rect.size.x,
			"ux0": rect.position.x - absf(mv.x), "ux1": rect.end.x + absf(mv.x)})
	for i in nodes.size():
		edges.append([])
	for i in nodes.size():
		for j in nodes.size():
			if i != j:
				_link(i, j)
	for d in map.get("bounce", []):
		_link_pad(d)


func _add_static(r: Rect2, solid: bool, crumble: bool = false) -> void:
	nodes.append({"x0": r.position.x, "x1": r.end.x, "y": r.position.y, "solid": solid, "mp": null, "w": r.size.x,
		"ux0": r.position.x, "ux1": r.end.x, "crumble": crumble, "h": r.size.y})


func _link(i: int, j: int) -> void:
	var a: Dictionary = nodes[i]
	var b: Dictionary = nodes[j]
	var rise: float = float(a["y"]) - float(b["y"])
	var gx: float = maxf(maxf(float(b["ux0"]) - float(a["ux1"]), float(a["ux0"]) - float(b["ux1"])), 0.0)
	if rise > 4.0:
		if rise <= JUMP_UP and gx <= reach_up(rise):
			(edges[i] as Array).append({"to": j, "kind": "up"})
	elif rise >= -4.0:
		if gx > 0.0 and gx <= reach_up(0.0):
			(edges[i] as Array).append({"to": j, "kind": "gap"})
	else:
		var d: float = -rise
		if gx <= 0.0:
			if not bool(a["solid"]):
				(edges[i] as Array).append({"to": j, "kind": "drop_through"})
			(edges[i] as Array).append({"to": j, "kind": "drop_side"})
		elif gx <= reach_drop(d):
			(edges[i] as Array).append({"to": j, "kind": "drop_side"})


func _link_pad(d: Dictionary) -> void:
	var pr: Rect2 = d["rect"]
	var power: float = absf(float(d["power"]))
	var height: float = power * power / 4000.0 * 0.88
	var pad_x: float = pr.position.x + pr.size.x * 0.5
	var base: int = node_at(Vector2(pad_x, pr.end.y), -1)
	if base < 0:
		return
	var by: float = float((nodes[base] as Dictionary)["y"])
	for j in nodes.size():
		if j == base:
			continue
		var b: Dictionary = nodes[j]
		var rise: float = by - float(b["y"])
		if rise < 20.0 or rise > height:
			continue
		var gx: float = maxf(maxf(float(b["ux0"]) - pad_x, pad_x - float(b["ux1"])), 0.0)
		if gx <= 190.0:
			(edges[base] as Array).append({"to": j, "kind": "pad", "pad_x": pad_x})


## Rect permukaan sekarang (platform bergerak mengikuti posisinya saat ini). x0, x1, y.
func cur(i: int) -> Dictionary:
	var n: Dictionary = nodes[i]
	var mp: Variant = n["mp"]
	if mp != null and is_instance_valid(mp):
		var px: float = (mp as Node2D).position.x
		return {"x0": px, "x1": px + float(n["w"]), "y": (mp as Node2D).position.y}
	return {"x0": n["x0"], "x1": n["x1"], "y": n["y"]}


## Simpul tempat kaki berada. Kalau melayang: simpul terdekat DI BAWAH kaki. -1 kalau tidak ada.
func node_at(feet: Vector2, prefer: int = -1) -> int:
	var best: int = -1
	var best_dy: float = 1e9
	for i in nodes.size():
		var c: Dictionary = cur(i)
		if feet.x < float(c["x0"]) - 14.0 or feet.x > float(c["x1"]) + 14.0:
			continue
		var dy: float = float(c["y"]) - feet.y          # >= 0 berarti permukaan ada di bawah kaki
		if dy < -16.0:
			continue
		if dy < best_dy:
			best_dy = dy
			best = i
	if best < 0:
		return prefer
	return best


## Sisi pertama menuju simpul `to` (atau simpul terdekat yang bisa dicapai kalau `to` tidak terjangkau).
## Mengembalikan {} kalau sudah di tujuan / tidak ada jalan.
func next_edge(from: int, to: int, goal: Vector2) -> Dictionary:
	if from < 0 or to < 0 or from == to:
		return {}
	var n: int = nodes.size()
	var prev: Array[int] = []
	var first: Array = []
	var seen: Array[bool] = []
	for i in n:
		prev.append(-1)
		first.append({})
		seen.append(false)
	var queue: Array[int] = [from]
	seen[from] = true
	var head: int = 0
	while head < queue.size():
		var u: int = queue[head]
		head += 1
		for e in edges[u]:
			var v: int = int(e["to"])
			if seen[v]:
				continue
			seen[v] = true
			prev[v] = u
			first[v] = e if u == from else first[u]
			queue.append(v)
	var dest: int = to
	if not seen[to]:
		var best: float = 1e12
		dest = from
		for i in n:
			if not seen[i]:
				continue
			var c: Dictionary = cur(i)
			var cx: float = clampf(goal.x, float(c["x0"]), float(c["x1"]))
			var score: float = absf(cx - goal.x) + 2.0 * absf(float(c["y"]) - goal.y)
			if score < best:
				best = score
				dest = i
	if dest == from:
		return {}
	return first[dest]


## Titik berdiri acak di atas sebuah platform (bukan platform bergerak) - dipakai spawn & warp.
func stand_points(avoid: Array[Rect2], margin: float = 50.0) -> Array[Vector2]:
	var res: Array[Vector2] = []
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		if n["mp"] != null or bool(n.get("crumble", false)):
			continue
		var x0: float = float(n["x0"]) + margin
		var x1: float = float(n["x1"]) - margin
		if x1 < x0:
			continue
		var steps: int = maxi(int((x1 - x0) / 90.0), 1)
		for k in steps + 1:
			var x: float = x0 + (x1 - x0) * float(k) / float(steps)
			var ok: bool = true
			for r in avoid:
				if r.grow(10.0).has_point(Vector2(x, float(n["y"]) - 4.0)):
					ok = false
			# ruang berdiri harus kosong: tidak boleh berada di dalam / menempel blok solid lain (mis. anak tangga piramida)
			var body := Rect2(x - 27.0, float(n["y"]) - 66.0, 54.0, 62.0)
			for j in nodes.size():
				var o: Dictionary = nodes[j]
				if j == i or not bool(o["solid"]):
					continue
				if body.intersects(Rect2(float(o["x0"]), float(o["y"]), float(o["w"]), float(o.get("h", 40.0)))):
					ok = false
					break
			if ok:
				res.append(Vector2(x, float(n["y"])))
	return res
