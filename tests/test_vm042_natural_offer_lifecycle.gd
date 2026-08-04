extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const TEST_SEEDS := [401, 1701, 4202]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyors: Array[ConveyorPrototype] = []
	var directors: Array[CollectibleDirector] = []
	for seed in TEST_SEEDS:
		var conveyor := scene.instantiate() as ConveyorPrototype
		conveyor.left_failure_enabled = false
		var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		director.placement_seed = seed
		root.add_child(conveyor)
		await physics_frame
		conveyor.player.position = Vector2(640.0, 420.0)
		conveyor.player.collision_layer = 0
		conveyor.player.set_physics_process(false)
		conveyors.append(conveyor)
		directors.append(director)

	while conveyors[0].survival_time < 59.95:
		await physics_frame
		for director in directors:
			for coin in director.active_collectibles():
				coin._resolve(true)

	var offered_totals: Array[int] = []
	for index in range(directors.size()):
		var director := directors[index]
		var accepted: Array[Dictionary] = []
		var templates := PackedInt32Array()
		var ground_count := 0
		var air_count := 0
		var unknown_count := 0
		var phases := PackedInt32Array()
		var phase_offer_counts := [0, 0, 0, 0]
		var phase_coin_counts := [0, 0, 0, 0]
		var last_spawn := -1.0
		var measured_longest_gap := 0.0
		var maximum_consecutive_template_repeats := 0
		var consecutive_template_repeats := 0
		var previous_template := -1
		for entry in director.offer_log():
			if entry.event != "attempt":
				continue
			if entry.accepted:
				accepted.append(entry)
				templates.append(int(entry.template))
				if int(entry.template) == previous_template:
					consecutive_template_repeats += 1
				else:
					consecutive_template_repeats = 0
				previous_template = int(entry.template)
				maximum_consecutive_template_repeats = maxi(
					maximum_consecutive_template_repeats,
					consecutive_template_repeats
				)
				if not phases.has(int(entry.phase)):
					phases.append(int(entry.phase))
				phase_offer_counts[int(entry.phase)] += 1
				phase_coin_counts[int(entry.phase)] += int(entry.ground_count) + int(entry.air_count)
				ground_count += int(entry.ground_count)
				air_count += int(entry.air_count)
				if last_spawn >= 0.0:
					measured_longest_gap = maxf(measured_longest_gap, float(entry.time) - last_spawn)
				last_spawn = float(entry.time)
			elif entry.rejection_reason == CollectibleDirector.REJECTION_UNKNOWN:
				unknown_count += 1
		var offered := ground_count + air_count
		offered_totals.append(offered)
		_check(accepted.size() >= 2, "Seed %d produces multiple natural offers" % TEST_SEEDS[index])
		_check(
			accepted[0].template == CollectibleDirector.OfferTemplate.GROUND_SINGLE
			and float(accepted[0].time) >= 1.5
			and float(accepted[0].time) <= 2.0,
			"Seed %d naturally teaches a ground offer at 1.5–2.0 seconds" % TEST_SEEDS[index]
		)
		_check(
			accepted[1].template == CollectibleDirector.OfferTemplate.LOW_AIR_ARC
			and float(accepted[1].time) <= 6.0
			and int(accepted[1].air_count) >= 2,
			"Seed %d naturally guarantees the low-air offer by six seconds" % TEST_SEEDS[index]
		)
		for template in range(CollectibleDirector.OfferTemplate.size()):
			_check(templates.has(template), "Seed %d naturally launches %s" % [TEST_SEEDS[index], director.template_name(template)])
		for phase in range(4):
			_check(phases.has(phase), "Seed %d naturally launches an offer in phase %d" % [TEST_SEEDS[index], phase + 1])
		_check(
			offered >= 40 and offered <= 60,
			"Seed %d offers 40–60 coins during the real 60-second lifecycle" % TEST_SEEDS[index]
		)
		_check(
			measured_longest_gap <= director.maximum_offer_free_gap + 0.05,
			"Seed %d stays within the maximum offer-start gap" % TEST_SEEDS[index]
		)
		_check(unknown_count == 0, "Seed %d has no unknown rejection category" % TEST_SEEDS[index])
		_check(
			maximum_consecutive_template_repeats <= 1,
			"Seed %d never selects the same authored route three times consecutively" % TEST_SEEDS[index]
		)
		_check(
			accepted[0].has("spawn_timestamp")
			and accepted[0].has("resolve_timestamp")
			and accepted[0].has("intended_ground_count")
			and accepted[0].has("intended_low_air_count")
			and accepted[0].has("active_offer_state"),
			"Seed %d log exposes required spawn, resolve, composition, and active-state fields" % TEST_SEEDS[index]
		)
		print(
			"VM042_SEED_METRICS seed=%d offered=%d ground=%d air=%d offers=%d phase_offers=%s phase_coins=%s first=%.3f second=%.3f longest_gap=%.3f rejections=%s"
			% [TEST_SEEDS[index], offered, ground_count, air_count, accepted.size(), phase_offer_counts, phase_coin_counts, float(accepted[0].time), float(accepted[1].time), measured_longest_gap, director.rejection_counts()]
		)

	offered_totals.sort()
	print(
		"VM042_MULTI_SEED_TOTALS min=%d median=%d max=%d"
		% [offered_totals[0], offered_totals[1], offered_totals[2]]
	)
	for conveyor in conveyors:
		conveyor.queue_free()
	await process_frame
	print("VM042_NATURAL_LIFECYCLE_FAILURES=%d" % _failures)
	quit(_failures)
