class_name CityFeedback
extends RefCounted

static var muted := false
static var _sounds: Dictionary = {}
static var _drop: SphereMesh

static func clear_cache() -> void:
	_sounds.clear()
	_drop = null

static func burst(parent: Node3D, at: Vector3, color: Color, water: bool = false, small: bool = false) -> void:
	# All transient visuals live under the match's effects root and have a strict cap.
	if parent.get_child_count() >= 42:
		return
	var particles := CPUParticles3D.new()
	particles.position = at + Vector3.UP * 0.07
	particles.amount = 10 if small else 24
	particles.lifetime = 0.48 if small else 0.75
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 65
	particles.gravity = Vector3(0, -9, 0)
	particles.initial_velocity_min = 0.8 if small else 1.6
	particles.initial_velocity_max = 1.5 if small else 4.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.8 if water or small else 1.3
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.55 if water else 0.14
	if not _drop:
		_drop = SphereMesh.new()
		_drop.radius = 0.065
		_drop.height = 0.13
		_drop.radial_segments = 8
		_drop.rings = 4
	particles.mesh = _drop
	particles.material_override = CityArt.material(color, 0.2 if water else 0.45)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
	particles.emitting = true
	particles.create_tween().tween_interval(particles.lifetime + 0.2).finished.connect(particles.queue_free)

static func sound(parent: Node3D, at: Vector3, kind: String, volume: float = -17) -> void:
	if muted or parent.get_child_count() >= 42:
		return
	if not _sounds.has(kind):
		_sounds[kind] = _synthesize(kind)
	var player := AudioStreamPlayer3D.new()
	player.position = at
	player.stream = _sounds[kind]
	player.volume_db = volume
	player.unit_size = 5.0
	player.max_distance = 30.0
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

static func _synthesize(kind: String) -> AudioStreamWAV:
	var durations := {"step": 0.13, "throw": 0.24, "splat": 0.3, "brush": 0.2, "flush": 1.65, "eat": 0.14}
	var duration: float = durations.get(kind, 0.2)
	var rate := 22050
	var samples := int(duration * rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var low := 0.0
	for index in samples:
		var t := float(index) / rate
		var u := t / duration
		var raw := rng.randf_range(-1, 1)
		low = lerpf(low, raw, 0.14 if kind == "flush" else 0.35)
		var sample := low
		match kind:
			"step": sample = (low * 0.65 + sin(t * TAU * 95) * 0.3) * exp(-u * 7)
			"throw": sample = low * sin(PI * u) * 0.65
			"splat": sample = (low * 0.65 + sin(t * TAU * (140 - 90 * u)) * 0.3) * exp(-u * 5)
			"brush": sample = raw * 0.22 * sin(PI * u)
			"flush": sample = (low * 1.4 + sin(t * TAU * (80 - 35 * u)) * 0.08) * sin(PI * pow(u, 0.7))
			"eat": sample = low * 0.4 * exp(-u * 5)
		data.encode_s16(index * 2, clampi(int(sample * 24000), -32767, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
