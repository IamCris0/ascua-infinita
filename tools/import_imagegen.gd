extends SceneTree
## Register regions and pivots only. The generated PNG files stay unmodified.
const ROOT = "res://assets/art/imagegen/"

func _initialize() -> void:
	var data = {}
	var heights = {"hero": 155.0, "slime": 105.0, "wisp": 125.0, "sentinel": 175.0, "boss": 215.0}
	for key in heights:
		var path = ROOT + key + "-v3.png"
		if not FileAccess.file_exists(path):
			continue
		var img = Image.new()
		assert(img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
		assert(img.get_size() == Vector2i(1536, 1024))
		var frames = []
		for row in range(4):
			var cuts = [0, 256, 512, 768, 1024, 1280, 1536]
			if key == "hero" and row == 2:
				cuts = [0, 256, 512, 768, 1056, 1355, 1536]
			var top = row * 256
			if key == "sentinel" and row == 2:
				top = 486 # Raised hammer extends into the empty gutter above this row.
			for col in range(6):
				var bottom = 486 if key == "sentinel" and row == 1 else (row + 1) * 256
				if key == "boss" and row == 2:
					bottom = 736
				var cell = Rect2i(cuts[col], top, cuts[col + 1] - cuts[col], bottom - top)
				var used = img.get_region(cell).get_used_rect()
				assert(used.has_area())
				used.position += cell.position
				var foot_y = row * 256 + 232
				if key == "hero":
					foot_y = [240, 490, 752, 989][row]
				elif key == "slime":
					foot_y = [237, 491, 746, 981][row]
				elif key == "sentinel":
					foot_y = [232, 482, 741, 989][row]
				elif key == "boss":
					foot_y = [240, 479, 722, 981][row]
				frames.append([used.position.x, used.position.y, used.size.x, used.size.y,
					col * 256 + (90 if key == "boss" else 128) - used.position.x, foot_y - used.position.y])
		var animations = {
			"idle": {"frames": [0, 1, 2, 3, 4, 5], "fps": 8, "loop": true},
			"walk": {"frames": [6, 7, 8, 9, 10, 11], "fps": 12, "loop": true},
			"attack": {"frames": [12, 13, 14, 15, 16, 17], "fps": 18 if key == "hero" else 10, "loop": false},
			"hurt": {"frames": [18, 19, 20], "fps": 12, "loop": false},
			"death": {"frames": [21, 22, 23], "fps": 5, "loop": false}}
		if key == "slime":
			# Exclude two poses where the generator reversed the eyes to the right.
			animations.attack.frames = [13, 14, 15, 17]
		data[key] = {"texture": path, "frames": frames, "animations": animations, "scale": heights[key] / frames[0][3]}
		if key == "hero":
			data[key].portrait = [105, 30, 82, 84]
			data[key].parts = {}
			data[key].animations.attack.frames = [12, 13, 14, 15, 16, 0]
			data[key].parts["15"] = [[768, 512, 288, 135, 128, 240], [768, 647, 256, 121, 128, 105]]
			for index in [16, 17]:
				var regions = [Rect2i(1056, 512, 224, 188), Rect2i(1056, 700, 299, 68)] if index == 16 else [Rect2i(1280, 512, 256, 188), Rect2i(1355, 700, 181, 68)]
				var parts = []
				for region in regions:
					parts.append([region.position.x, region.position.y, region.size.x, region.size.y,
						(index % 6) * 256 + 128 - region.position.x, 752 - region.position.y])
				data[key].parts[str(index)] = parts
		if key == "boss":
			# The blast occupies the upper gutter of its neighbour's cell. Split
			# drawing regions along empty space, without editing any pixels.
			data[key].parts = {}
			for index in [14, 15]:
				var regions = [Rect2i(512, 512, 202, 98), Rect2i(512, 610, 256, 126)] if index == 14 else [Rect2i(714, 512, 310, 98), Rect2i(768, 610, 256, 126)]
				var parts = []
				for region in regions:
					parts.append([region.position.x, region.position.y, region.size.x, region.size.y,
						(index % 6) * 256 + 90 - region.position.x, 722 - region.position.y])
				data[key].parts[str(index)] = parts
	var file = FileAccess.open(ROOT + "characters.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t") + "\n")
	print("Registered %d ImageGen character sheets" % data.size())
	quit()
