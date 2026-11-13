extends Node2D

var columns: int = 1
var rows: int = 1
var side_length: float = 60.0

# 0 = Трикутник, 1 = Квадрат, 2 = Шестикутник
var selected_shape: int = 0

var line_color := Color.BLACK
var line_width: float = 2.0

const MAX_FPS: int = 60
const MAX_PACKAGES: int = 5000
const PHASE_STEPS: int = 5
const CM2_PER_M2: float = 10000.0

var is_settings_open: bool = true

# ==========================================
# ПАРАМЕТРИ ПАКУВАННЯ
# ==========================================

var package_width: float = 100.0
var package_length: float = 80.0

var packages_visible: bool = false
var package_count: int = 0

var package_color := Color(0.90, 0.18, 0.20, 0.85)
var package_border_color := Color(0.45, 0.03, 0.05, 1.0)

var package_rects: Array[Rect2] = []

# ==========================================
# ПОЛІГОНИ РОБОЧОГО ПРОСТОРУ ТА ПРОСТОРОВИЙ ХЕШ
# ==========================================

var pattern_polygons: Array[PackedVector2Array] = []
var pattern_polygon_bounds: Array[Rect2] = []

var spatial_grid: Dictionary = {}
var spatial_cell_size: float = 100.0

# ==========================================
# СТАТИСТИКА
# ==========================================

var hovered_package_index: int = -1

var workspace_area_cm2: float = 0.0
var workspace_area_m2: float = 0.0

var package_area_cm2: float = 0.0
var package_area_m2: float = 0.0

var total_packages_area_m2: float = 0.0
var fill_percentage: float = 0.0


# ==========================================
# READY
# ==========================================

func _ready() -> void:

	Engine.max_fps = MAX_FPS

	$Settings/SizeInput.value = side_length
	$Settings/RowsInput.value = rows
	$Settings/ColumnsInput.value = columns

	$Settings/PackageWidthInput.value = package_width
	$Settings/PackageLengthInput.value = package_length

	if not $Settings/CalculateButton.pressed.is_connected(calculate_pattern):
		$Settings/CalculateButton.pressed.connect(calculate_pattern)

	$Settings.hide()
	is_settings_open = false

	if not $SettingsButton.pressed.is_connected(_on_settings_button_pressed):
		$SettingsButton.pressed.connect(_on_settings_button_pressed)

	if not $Settings/Trinagle.pressed.is_connected(_on_triangle_pressed):
		$Settings/Trinagle.pressed.connect(_on_triangle_pressed)

	if not $Settings/Sqare.pressed.is_connected(_on_square_pressed):
		$Settings/Sqare.pressed.connect(_on_square_pressed)

	if not $Settings/Hexagon.pressed.is_connected(_on_hexagon_pressed):
		$Settings/Hexagon.pressed.connect(_on_hexagon_pressed)

	if not $Settings/PackButton.pressed.is_connected(pack_packages):
		$Settings/PackButton.pressed.connect(pack_packages)

	queue_redraw()


# ==========================================
# SETTINGS
# ==========================================

func _on_settings_button_pressed() -> void:

	if is_settings_open:
		$Settings.hide()
		is_settings_open = false
	else:
		$Settings.show()
		is_settings_open = true


# ==========================================
# ВИБІР ФІГУР
# ==========================================

func _on_triangle_pressed() -> void:

	selected_shape = 0
	packages_visible = false
	package_rects.clear()
	hovered_package_index = -1

	queue_redraw()


func _on_square_pressed() -> void:

	selected_shape = 1
	packages_visible = false
	package_rects.clear()
	hovered_package_index = -1

	queue_redraw()


func _on_hexagon_pressed() -> void:

	selected_shape = 2
	packages_visible = false
	package_rects.clear()
	hovered_package_index = -1

	queue_redraw()


# ==========================================
# СТВОРЕННЯ ПРОСТОРУ
# ==========================================

func calculate_pattern() -> void:

	side_length = $Settings/SizeInput.value
	columns = int($Settings/ColumnsInput.value)
	rows = int($Settings/RowsInput.value)

	if side_length <= 0 or columns <= 0 or rows <= 0:
		return

	if columns >= 100 or rows >= 100:
		return

	packages_visible = false
	package_rects.clear()
	package_count = 0
	hovered_package_index = -1

	build_pattern_polygons()
	update_workspace_area()
	update_package_statistics()

	queue_redraw()


# ==========================================
# МАЛЮВАННЯ
# ==========================================

func _draw() -> void:

	if columns <= 0 or rows <= 0 or side_length <= 0:
		return

	match selected_shape:

		0:
			draw_triangles()

		1:
			draw_squares()

		2:
			draw_hexagons()

	if packages_visible:
		draw_packages()

	draw_statistics()

	if hovered_package_index >= 0:
		draw_package_tooltip()


# ==========================================
# ТРИКУТНИКИ
# ==========================================

func draw_triangles() -> void:

	var s: float = side_length
	var h: float = s * sqrt(3.0) / 2.0

	var total_width: float = (columns + 1) * s / 2.0
	var total_height: float = rows * h

	var start_x: float = (get_viewport_rect().size.x - total_width) / 2.0
	var start_y: float = (get_viewport_rect().size.y - total_height) / 2.0

	for row in range(rows):

		for col in range(columns):

			var x: float = start_x + col * s / 2.0
			var y: float = start_y + row * h

			var points := PackedVector2Array()

			if (row + col) % 2 == 0:

				points.append(Vector2(x + s / 2.0, y))
				points.append(Vector2(x, y + h))
				points.append(Vector2(x + s, y + h))

			else:

				points.append(Vector2(x, y))
				points.append(Vector2(x + s, y))
				points.append(Vector2(x + s / 2.0, y + h))

			points.append(points[0])

			draw_polyline(points, line_color, line_width, true)


# ==========================================
# КВАДРАТИ
# ==========================================

func draw_squares() -> void:

	var s: float = side_length

	var total_width: float = columns * s
	var total_height: float = rows * s

	var start_x: float = (get_viewport_rect().size.x - total_width) / 2.0
	var start_y: float = (get_viewport_rect().size.y - total_height) / 2.0

	for row in range(rows):

		for col in range(columns):

			var x: float = start_x + col * s
			var y: float = start_y + row * s

			draw_rect(
				Rect2(x, y, s, s),
				line_color,
				false,
				line_width
			)


# ==========================================
# ШЕСТИКУТНИКИ
# ==========================================

func draw_hexagons() -> void:

	var s: float = side_length

	var hex_width: float = sqrt(3.0) * s
	var hex_height: float = 2.0 * s

	var step_x: float = hex_width
	var step_y: float = hex_height * 0.75

	var total_width: float = columns * step_x

	if rows > 1:
		total_width += hex_width / 2.0

	var total_height: float = hex_height + (rows - 1) * step_y

	var start_x: float = (get_viewport_rect().size.x - total_width) / 2.0
	var start_y: float = (get_viewport_rect().size.y - total_height) / 2.0

	for row in range(rows):

		for col in range(columns):

			var x: float = start_x + col * step_x
			var y: float = start_y + row * step_y

			if row % 2 == 1:
				x += hex_width / 2.0

			var points := PackedVector2Array()

			for i in range(6):

				var angle: float = deg_to_rad(30.0 + i * 60.0)

				var point := Vector2(
					x + hex_width / 2.0 + s * cos(angle),
					y + s + s * sin(angle)
				)

				points.append(point)

			points.append(points[0])

			draw_polyline(points, line_color, line_width, true)


# ==========================================
# МЕЖІ РОБОЧОГО ПРОСТОРУ
# ==========================================

func get_pattern_bounds() -> Rect2:

	var total_width: float = 0.0
	var total_height: float = 0.0

	match selected_shape:

		0:

			var h: float = side_length * sqrt(3.0) / 2.0

			total_width = (columns + 1) * side_length / 2.0
			total_height = rows * h

		1:

			total_width = columns * side_length
			total_height = rows * side_length

		2:

			var hex_width: float = sqrt(3.0) * side_length
			var hex_height: float = 2.0 * side_length

			total_width = columns * hex_width

			if rows > 1:
				total_width += hex_width / 2.0

			total_height = hex_height + (rows - 1) * hex_height * 0.75

	var viewport_size: Vector2 = get_viewport_rect().size

	var start_x: float = (viewport_size.x - total_width) / 2.0
	var start_y: float = (viewport_size.y - total_height) / 2.0

	return Rect2(
		Vector2(start_x, start_y),
		Vector2(total_width, total_height)
	)


# ==========================================
# ПОБУДОВА ПОЛІГОНІВ РОБОЧОГО ПРОСТОРУ ТА ХЕШУВАННЯ
# ==========================================

func add_pattern_polygon(points: PackedVector2Array) -> void:

	if points.size() < 3:
		return

	var poly_idx: int = pattern_polygons.size()
	pattern_polygons.append(points)

	var min_x: float = points[0].x
	var min_y: float = points[0].y
	var max_x: float = points[0].x
	var max_y: float = points[0].y

	for point in points:

		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)

		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)

	var bound_rect := Rect2(
		Vector2(min_x, min_y),
		Vector2(max_x - min_x, max_y - min_y)
	)
	pattern_polygon_bounds.append(bound_rect)

	# Реєстрація полігона у просторовій сітці (Spatial Hash)
	var start_cx: int = int(floor((min_x - 0.1) / spatial_cell_size))
	var end_cx: int = int(floor((max_x + 0.1) / spatial_cell_size))
	var start_cy: int = int(floor((min_y - 0.1) / spatial_cell_size))
	var end_cy: int = int(floor((max_y + 0.1) / spatial_cell_size))

	for cx in range(start_cx, end_cx + 1):
		for cy in range(start_cy, end_cy + 1):
			var key := Vector2i(cx, cy)
			if not spatial_grid.has(key):
				spatial_grid[key] = PackedInt32Array()
			spatial_grid[key].append(poly_idx)


# ==========================================
# ПЛОЩА ПОЛІГОНА
# ==========================================

func get_polygon_area(points: PackedVector2Array) -> float:

	var area: float = 0.0

	for i in range(points.size()):

		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]

		area += a.x * b.y - b.x * a.y

	return absf(area) / 2.0


# ==========================================
# ОБЧИСЛЕННЯ ПЛОЩІ РОБОЧОГО ПРОСТОРУ
# ==========================================

func update_workspace_area() -> void:

	workspace_area_cm2 = 0.0

	for polygon in pattern_polygons:
		workspace_area_cm2 += get_polygon_area(polygon)

	workspace_area_m2 = workspace_area_cm2 / CM2_PER_M2


# ==========================================
# СТАТИСТИКА ПАКУНКІВ
# ==========================================

func update_package_statistics() -> void:

	package_area_cm2 = package_width * package_length
	package_area_m2 = package_area_cm2 / CM2_PER_M2

	total_packages_area_m2 = package_area_m2 * package_count

	if workspace_area_m2 > 0.0:

		fill_percentage = (
			total_packages_area_m2 / workspace_area_m2
		) * 100.0

	else:

		fill_percentage = 0.0


# ==========================================
# СТВОРЕННЯ ПОЛІГОНІВ
# ==========================================

func build_pattern_polygons() -> void:

	pattern_polygons.clear()
	pattern_polygon_bounds.clear()
	spatial_grid.clear()
	spatial_cell_size = maxf(20.0, side_length * 1.5)

	var bounds: Rect2 = get_pattern_bounds()

	match selected_shape:

		# ТРИКУТНИКИ
		0:

			var s: float = side_length
			var h: float = s * sqrt(3.0) / 2.0

			for row in range(rows):

				for col in range(columns):

					var x: float = bounds.position.x + col * s / 2.0
					var y: float = bounds.position.y + row * h

					var points := PackedVector2Array()

					if (row + col) % 2 == 0:

						points.append(Vector2(x + s / 2.0, y))
						points.append(Vector2(x, y + h))
						points.append(Vector2(x + s, y + h))

					else:

						points.append(Vector2(x, y))
						points.append(Vector2(x + s, y))
						points.append(Vector2(x + s / 2.0, y + h))

					add_pattern_polygon(points)

		# КВАДРАТИ
		1:

			var s: float = side_length

			for row in range(rows):

				for col in range(columns):

					var x: float = bounds.position.x + col * s
					var y: float = bounds.position.y + row * s

					var points := PackedVector2Array([
						Vector2(x, y),
						Vector2(x + s, y),
						Vector2(x + s, y + s),
						Vector2(x, y + s)
					])

					add_pattern_polygon(points)

		# ШЕСТИКУТНИКИ
		2:

			var s: float = side_length

			var hex_width: float = sqrt(3.0) * s
			var step_y: float = s * 1.5

			for row in range(rows):

				for col in range(columns):

					var x: float = col * hex_width
					var y: float = row * step_y

					if row % 2 == 1:
						x += hex_width / 2.0

					var points := PackedVector2Array()

					for i in range(6):

						var angle: float = deg_to_rad(30.0 + i * 60.0)

						var point := Vector2(
							x + hex_width / 2.0 + s * cos(angle),
							y + s + s * sin(angle)
						) + bounds.position

						points.append(point)

					add_pattern_polygon(points)


# ==========================================
# ПЕРЕВІРКА ТОЧКИ ВСЕРЕДИНІ ПРОСТОРУ (Через Spatial Hash)
# ==========================================

func is_point_inside_pattern(point: Vector2) -> bool:

	var key := Vector2i(
		int(floor(point.x / spatial_cell_size)),
		int(floor(point.y / spatial_cell_size))
	)

	if not spatial_grid.has(key):
		return false

	var candidates: PackedInt32Array = spatial_grid[key]

	for i in candidates:

		var polygon_bounds: Rect2 = pattern_polygon_bounds[i]

		if (
			point.x < polygon_bounds.position.x - 0.01
			or point.x > polygon_bounds.end.x + 0.01
			or point.y < polygon_bounds.position.y - 0.01
			or point.y > polygon_bounds.end.y + 0.01
		):
			continue

		if Geometry2D.is_point_in_polygon(
			point,
			pattern_polygons[i]
		):
			return true

	return false


# ==========================================
# ПЕРЕВІРКА ПОВНОГО РОЗМІЩЕННЯ ПАКУНКА
# ==========================================

func can_place_package(rect: Rect2) -> bool:

	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false

	var steps_x: int = maxi(1, int(ceil(rect.size.x / 4.0)))
	var steps_y: int = maxi(1, int(ceil(rect.size.y / 4.0)))

	# Верхня та нижня сторони
	for i in range(steps_x + 1):

		var x: float = rect.position.x + rect.size.x * float(i) / steps_x

		var top_point := Vector2(x, rect.position.y)
		var bottom_point := Vector2(x, rect.end.y)

		if not is_point_inside_pattern(top_point):
			return false

		if not is_point_inside_pattern(bottom_point):
			return false

	# Ліва та права сторони
	for i in range(steps_y + 1):

		var y: float = rect.position.y + rect.size.y * float(i) / steps_y

		var left_point := Vector2(rect.position.x, y)
		var right_point := Vector2(rect.end.x, y)

		if not is_point_inside_pattern(left_point):
			return false

		if not is_point_inside_pattern(right_point):
			return false

	# Внутрішні точки
	for y_index in range(1, 4):

		for x_index in range(1, 4):

			var point := Vector2(
				rect.position.x + rect.size.x * float(x_index) / 4.0,
				rect.position.y + rect.size.y * float(y_index) / 4.0
			)

			if not is_point_inside_pattern(point):
				return false

	return true


# ==========================================
# ПОШУК НАЙКРАЩОГО РОЗТАШУВАННЯ (Асинхронний з паузами)
# ==========================================

func pack_packages() -> void:

	package_width = $Settings/PackageWidthInput.value
	package_length = $Settings/PackageLengthInput.value

	package_rects.clear()
	package_count = 0
	packages_visible = false
	hovered_package_index = -1

	if package_width <= 0.0 or package_length <= 0.0:

		print("Помилка: неправильні розміри пакунка.")
		update_package_statistics()
		queue_redraw()
		return

	build_pattern_polygons()
	update_workspace_area()

	if pattern_polygons.is_empty():

		print("Помилка: простір не створений.")
		update_package_statistics()
		queue_redraw()
		return

	var bounds: Rect2 = get_pattern_bounds()
	var best_rects: Array[Rect2] = []

	# Перевіряємо звичайне та повернуте розташування
	for rotation_index in range(2):

		var current_width: float
		var current_height: float

		if rotation_index == 0:
			current_width = package_width
			current_height = package_length
		else:
			current_width = package_length
			current_height = package_width

		# Різні зміщення сітки
		for phase_x_index in range(PHASE_STEPS):

			for phase_y_index in range(PHASE_STEPS):

				# Плавний асинхронний рядок: звільняємо процесор між ітераціями фаз, запобігаючи лагам
				await get_tree().process_frame

				var phase_x: float = current_width * float(phase_x_index) / PHASE_STEPS
				var phase_y: float = current_height * float(phase_y_index) / PHASE_STEPS

				# Звичайна сітка та шахове зміщення
				for stagger_index in range(2):

					var use_stagger: bool = stagger_index == 1
					var candidate_rects: Array[Rect2] = []

					var y: float = bounds.position.y + phase_y
					var row_index: int = 0

					while y + current_height <= bounds.end.y + 0.001:

						var row_offset: float = 0.0

						if use_stagger and row_index % 2 == 1:
							row_offset = current_width / 2.0

						var x: float = bounds.position.x + phase_x + row_offset

						while x + current_width <= bounds.end.x + 0.001:

							var package_rect := Rect2(
								x,
								y,
								current_width,
								current_height
							)

							if can_place_package(package_rect):

								candidate_rects.append(package_rect)

								if candidate_rects.size() >= MAX_PACKAGES:
									break

							x += current_width

						if candidate_rects.size() >= MAX_PACKAGES:
							break

						y += current_height
						row_index += 1

					# Зберігаємо найкращий знайдений варіант
					if candidate_rects.size() > best_rects.size():
						best_rects = candidate_rects.duplicate()

	# Результат
	package_rects = best_rects
	package_count = package_rects.size()

	packages_visible = package_count > 0

	update_package_statistics()

	print("==============================")
	print("PACKLAB - PACKING RESULT")
	print("==============================")
	print("Розміщено пакунків: ", package_count)
	print("Розмір пакунка: %.1f × %.1f см" % [
		package_width,
		package_length
	])
	print("Площа одного пакунка: %.4f м²" % package_area_m2)
	print("Площа робочого простору: %.4f м²" % workspace_area_m2)
	print("Загальна площа пакунків: %.4f м²" % total_packages_area_m2)
	print("Заповнення простору: %.2f%%" % fill_percentage)
	print("==============================")

	queue_redraw()


# ==========================================
# ВІДСТЕЖЕННЯ КУРСОРА
# ==========================================

func _process(_delta: float) -> void:

	var mouse_position: Vector2 = get_local_mouse_position()
	var new_hovered_index: int = -1

	if packages_visible:

		for i in range(package_rects.size()):

			if package_rects[i].has_point(mouse_position):

				new_hovered_index = i
				break

	if new_hovered_index != hovered_package_index:

		hovered_package_index = new_hovered_index
		queue_redraw()


# ==========================================
# МАЛЮВАННЯ ПАКУНКІВ
# ==========================================

func draw_packages() -> void:

	for package_rect in package_rects:

		draw_rect(
			package_rect,
			package_color,
			true
		)

		draw_rect(
			package_rect,
			package_border_color,
			false,
			1.5
		)

	# Виділяємо пакунок, на який наведений курсор
	if hovered_package_index >= 0 and hovered_package_index < package_rects.size():

		draw_rect(
			package_rects[hovered_package_index],
			Color(1.0, 0.85, 0.25, 0.18),
			true
		)

		draw_rect(
			package_rects[hovered_package_index],
			Color(1.0, 0.85, 0.25, 1.0),
			false,
			3.0
		)


# ==========================================
# ПІДКАЗКА ПАКУНКА
# ==========================================

func draw_package_tooltip() -> void:

	if hovered_package_index < 0:
		return

	if hovered_package_index >= package_rects.size():
		return

	var package_rect: Rect2 = package_rects[hovered_package_index]

	var font: Font = ThemeDB.fallback_font

	var area_m2: float = (
		package_rect.size.x * package_rect.size.y / CM2_PER_M2
	)

	var tooltip_width: float = 220.0
	var tooltip_height: float = 86.0
	var padding: float = 10.0

	var tooltip_position := Vector2(
		package_rect.get_center().x - tooltip_width / 2.0,
		package_rect.position.y - tooltip_height - 12.0
	)

	if tooltip_position.y < 5.0:
		tooltip_position.y = package_rect.end.y + 12.0

	tooltip_position.x = clampf(
		tooltip_position.x,
		5.0,
		get_viewport_rect().size.x - tooltip_width - 5.0
	)

	var tooltip_rect := Rect2(
		tooltip_position,
		Vector2(tooltip_width, tooltip_height)
	)

	draw_rect(
		tooltip_rect,
		Color(0.055, 0.075, 0.10, 0.97),
		true
	)

	draw_rect(
		tooltip_rect,
		Color(0.10, 0.85, 0.80, 1.0),
		false,
		2.0
	)

	var text_color := Color(0.92, 0.96, 1.0)
	var accent_color := Color(0.20, 0.95, 0.85)

	var text_x: float = tooltip_position.x + padding
	var text_y: float = tooltip_position.y + 21.0

	draw_string(
		font,
		Vector2(text_x, text_y),
		"Пакунок №" + str(hovered_package_index + 1),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		accent_color
	)

	draw_string(
		font,
		Vector2(text_x, text_y + 22.0),
		"Розмір: %.1f × %.1f см" % [
			package_rect.size.x,
			package_rect.size.y
		],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		text_color
	)

	draw_string(
		font,
		Vector2(text_x, text_y + 43.0),
		"Площа: %.4f м²" % area_m2,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		text_color
	)


# ==========================================
# ЗАГАЛЬНА СТАТИСТИКА PACKLAB
# ==========================================

func draw_statistics() -> void:

	var font: Font = ThemeDB.fallback_font

	var panel_position := Vector2(20.0, 20.0)
	var panel_size := Vector2(285.0, 135.0)

	var panel_rect := Rect2(
		panel_position,
		panel_size
	)

	draw_rect(
		panel_rect,
		Color(0.035, 0.055, 0.075, 0.92),
		true
	)

	draw_rect(
		panel_rect,
		Color(0.10, 0.75, 0.72, 0.9),
		false,
		2.0
	)

	var x: float = panel_position.x + 12.0
	var y: float = panel_position.y + 25.0

	var main_color := Color(0.25, 0.95, 0.85)
	var normal_color := Color(0.90, 0.94, 0.98)

	draw_string(
		font,
		Vector2(x, y),
		"PACKLAB — СТАТИСТИКА",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		main_color
	)

	draw_string(
		font,
		Vector2(x, y + 25.0),
		"Площа простору: %.4f м²" % workspace_area_m2,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		normal_color
	)

	draw_string(
		font,
		Vector2(x, y + 47.0),
		"Пакунків розміщено: %d" % package_count,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		normal_color
	)

	draw_string(
		font,
		Vector2(x, y + 69.0),
		"Загальна площа: %.4f м²" % total_packages_area_m2,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		normal_color
	)

	draw_string(
		font,
		Vector2(x, y + 91.0),
		"Заповнення: %.2f%%" % fill_percentage,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		main_color
	)
