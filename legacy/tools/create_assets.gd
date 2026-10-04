extends SceneTree
## Original pixel designs. Each SVG sheet has 16 x 32px frames:
## idle 0..3, walk 4..7, attack 8..11, hurt 12..13, dissolve 14..15.
const PALETTE = {"o":"141725", "s":"333955", "m":"59657b", "l":"a3b8c7", "w":"e9e9ce", "t":"4fa99a", "c":"86e0bd", "r":"ae4b54", "f":"ed8650", "y":"ffcf7b", "p":"8969b5", "v":"bd95d9"}
const DESIGNS = {
"hero": [
"........ssss........", ".......smmmms.......", "......smmllmms......", "......sllwllms......", "......slwwllms......", ".......sooyys.......", ".......smmms........", "......rrffffr.......", ".....rrffyffrr......", "....ssrffyfrsss.....", "...smmsttttsmmls....", "...slmscttcssmls....", "...smmsttttsmms.....", "....sssttttsss......", "......smssms........", "......sms.sms.......", ".....smms.smms......", ".....ssss.ssss......"],
"slime": [
"....................", "....................", ".........tt.........", "........tccct.......", "......ttccccctt.....", ".....tccwccccct.....", "....tccwwcccccct....", "...tcccccccccccct...", "...tccoocccooccct...", "...tcoyycccoyycct...", "..tcccoocccooccctt..", "..tcccccccccccccct..", "..tcccttttttccccct..", "..tttttccccccttttt..", "...tttttttttttttt...", "....tttt....tttt...."],
"wisp": [
".........pp.........", "........pvp.........", ".......pvvvp........", ".......pvwvp........", "......pvvwvp........", ".....pvvwwvvp.......", ".....pvwwwwvp.......", "....pvwwwwwwvp......", "....pvwoowwovp......", "....pvyoywyoyp......", "....pvwwwwwwvp......", ".....pvvvvvvp.......", "......pvvvvp........", ".....pvppvvp........", ".....pp..pvp........", "..........pp........"],
"sentinel": [
"......ssssssss......", ".....smmlmmlmms.....", ".....sllllllmms.....", ".....slooooools.....", ".....sloyffools.....", ".....slooooools.....", "......sllllms.......", "....ssssmmssssss....", "...smmlsffsllmms....", "...slllsyyslllls....", "...smmmsffsmmmms....", "....sssmllmssss.....", "......smllms........", "......ssssss........", ".....smmssmms.......", ".....sllsslls.......", ".....ssssssss......."],
"boss": [
"...yy....yy....yy...", "...syl..syys..lys...", "...syyllsyysllyys...", "....syyyyyyyyyys....", ".....slllllllls.....", "....slloooooolls....", "....sloryyyyorls....", "....slloooooolls....", ".....slloolllls.....", "...rrrsllllllsrrr...", "..rrffrsssssrffrrr..", ".rrffrrrsyysrrrffrr.", ".rffrrrsyyyysrrrffr.", ".rffrrrsyfyysrrrffr.", ".rrfrrrssyyssrrrfrr.", "..rrrrrrssssrrrrrr..", "...rrrrssssssrrrr...", "....rrssssssssrr....", ".....ssms..smss.....", "....sslls..sllss....", "....sssss..sssss...."]}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/sprites")
	DirAccess.make_dir_recursive_absolute("res://assets/audio")
	for name in DESIGNS:
		make_sheet(name, DESIGNS[name])
	write_file("res://assets/icon.svg", '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 32 32"><rect width="32" height="32" rx="7" fill="#101521"/><path d="M17 3v6h4v5h4v10h-4v4H10v-4H7v-9h4v-5h3V3z" fill="#ed8650"/><path d="M16 13v5h4v7H12v-7h2v-5z" fill="#ffcf7b"/><path d="M15 21h3v5h-3z" fill="#fff1cf"/></svg>')
	make_sound("hit", 180, 60, 0.10, 0.14)
	make_sound("critical", 620, 110, 0.17, 0.16)
	make_sound("coin", 880, 1320, 0.18, 0.10)
	make_sound("relic", 440, 880, 0.5, 0.13)
	make_sound("fall", 160, 35, 0.7, 0.18)
	make_sound("pulse", 110, 110, 1.7, 0.035)
	print("ASSETS_OK: five animated sheets, icon, six original synthesized sounds")
	quit()

func write_file(path: String, body: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(body)

func make_sheet(name: String, rows: Array) -> void:
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="32" shape-rendering="crispEdges">'
	for frame in range(16):
		var bob = [0, -1, -1, 0][frame % 4]
		var dx = 2 if frame in [9, 10] else (-1 if frame in [12, 13] else 0)
		var offset = Vector2i(frame * 32 + 5 + dx, 28 - rows.size() + bob)
		for y in range(rows.size()):
			for x in range(str(rows[y]).length()):
				var ch = str(rows[y])[x]
				if not PALETTE.has(ch):
					continue
				if frame >= 14 and (x + y) % (2 if frame == 14 else 3) != 0:
					continue
				var shift = (1 if (x < 10) else -1) * (1 if frame % 2 == 0 else -1) if frame in [4, 5, 6, 7] and y > rows.size() - 5 else 0
				var col: String = "ffffff" if frame == 12 else PALETTE[ch]
				svg += '<rect x="%d" y="%d" width="1" height="1" fill="#%s"/>' % [offset.x + x + shift, offset.y + y, col]
		if name == "hero" and frame < 14:
			var sx = frame * 32
			if frame in [9, 10]:
				svg += '<path d="M%d 17h8v2h-8z" fill="#e9e9ce"/><path d="M%d 16h2v4h-2z" fill="#ffcf7b"/>' % [sx + 23, sx + 23]
			else:
				svg += '<path d="M%d 10h2v12h-2z" fill="#a3b8c7"/><path d="M%d 20h6v2h-6z" fill="#ffcf7b"/>' % [sx + 26, sx + 24]
		svg += ''
	svg += '</svg>'
	write_file("res://assets/sprites/" + name + ".svg", svg)

func make_sound(name: String, start: float, finish: float, duration: float, volume: float) -> void:
	var rate = 22050
	var samples = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var phase = 0.0
	for i in range(samples):
		var t = float(i) / samples
		phase += TAU * lerpf(start, finish, t) / rate
		var wave = sin(phase) * 0.8 + sin(phase * 2) * 0.2
		var envelope = minf(t * 40, 1) * pow(1 - t, 2)
		bytes.encode_s16(i * 2, int(wave * envelope * volume * 32767))
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = rate
	audio.data = bytes
	audio.save_to_wav("res://assets/audio/" + name + ".wav")
