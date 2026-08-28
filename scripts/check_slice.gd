extends SceneTree

func _init() -> void:
	var failed := 0
	failed += _expect(MatchRules.is_in_court(Vector2(0, 0)), "left-top corner is in")
	failed += _expect(MatchRules.is_in_court(Vector2(20, 44)), "right-bottom corner is in")
	failed += _expect(not MatchRules.is_in_court(Vector2(-0.1, 10)), "outside left is out")
	failed += _expect(MatchRules.is_in_nvz(Vector2(10, 22)), "net is inside NVZ")
	failed += _expect(not MatchRules.is_in_nvz(Vector2(10, 14.9)), "above NVZ is not kitchen")
	failed += _expect(MatchRules.volley_legal(3), "3rd incoming shot can be volleyed")
	failed += _expect(not MatchRules.volley_legal(2), "return cannot be volleyed")
	failed += _expect(MatchRules.serve_from_screen_right(true, 0), "human even serves from right")
	failed += _expect(not MatchRules.serve_from_screen_right(true, 1), "human odd serves from left")
	failed += _expect(not MatchRules.serve_from_screen_right(false, 0), "cpu even serves from screen left")
	failed += _expect(MatchRules.serve_from_screen_right(false, 1), "cpu odd serves from screen right")
	var human_even := MatchRules.serve_target_box(true, 0)
	failed += _expect(MatchRules.inclusive_in_rect(Vector2(5, 7), human_even), "human even targets north left")
	failed += _expect(not MatchRules.inclusive_in_rect(Vector2(15, 7), human_even), "human even does not target north right")
	var cpu_even := MatchRules.serve_target_box(false, 0)
	failed += _expect(MatchRules.inclusive_in_rect(Vector2(15, 36), cpu_even), "cpu even targets south right")
	var serve_land := MatchRules.serve_land_point(true, 0)
	failed += _expect(MatchRules.inclusive_in_rect(serve_land, MatchRules.north_left_box()), "prescribed serve is in north left")
	var serve_net := MatchRules.height_at_net(Vector2(15.0, 45.0), serve_land, 2.8, 0.0, 3.1)
	failed += _expect(serve_net > MatchRules.NET_HEIGHT, "prescribed serve clears the net")
	failed += _expect(MatchRules.crosses_net(Vector2(10, 40), Vector2(10, 8)), "south to north crosses net")
	failed += _expect(not MatchRules.crosses_net(Vector2(10, 40), Vector2(12, 32)), "same side does not cross")
	var net_h := MatchRules.height_at_net(Vector2(10, 40), Vector2(10, 8), 2.8, 0.0, 3.1)
	failed += _expect(net_h > MatchRules.NET_HEIGHT, "standard hard ball clears the net")
	var kitchen := MatchRules.zone_rect(0, 2)
	failed += _expect(MatchRules.inclusive_in_rect(Vector2(5, 18), kitchen), "kitchen left zone")
	failed += _expect(not MatchRules.inclusive_in_rect(Vector2(15, 18), kitchen), "kitchen left is not right")
	var deep_right := MatchRules.zone_center(1, 0)
	failed += _expect(deep_right.x > 10.0 and deep_right.y < 7.5, "deep right center")
	failed += _expect(ShotCatalog.flight_time(ShotCatalog.Id.SOFT) > ShotCatalog.flight_time(ShotCatalog.Id.HARD), "soft is slower than hard")
	var volley_net := MatchRules.height_at_net(Vector2(10.0, 40.6), Vector2(10.0, 8.0), 2.8, 0.0, ShotCatalog.apex_extra(ShotCatalog.Id.HARD, true, 2.8))
	failed += _expect(volley_net > MatchRules.NET_HEIGHT, "hard volley from baseline clears the net")
	var ball := RallyBall.new()
	ball.launch(Vector2(15.0, 45.0), 2.8, Vector2(5.0, 7.5), ShotCatalog.Id.HARD)
	var frames := 0
	var landed := false
	while frames < 180 and ball.stage != RallyBall.Stage.DEAD:
		ball.advance(1.0 / 60.0)
		frames += 1
		if ball.just_net:
			break
		if ball.just_first_bounce:
			landed = true
			break
	failed += _expect(landed, "hard serve reaches a first bounce")
	failed += _expect(MatchRules.inclusive_in_rect(ball.ground_pos, MatchRules.north_left_box()), "drive serve can land in north left box")
	ball.free()
	failed += _expect(KitchenOccupancy.is_on_line(Vector2(5.0, 30.2), true), "human home_nvz is on the kitchen line")
	failed += _expect(not KitchenOccupancy.is_on_line(Vector2(5.0, 40.6), true), "human baseline is not on the kitchen line")
	failed += _expect(KitchenOccupancy.in_front_view(Vector2(5.0, 30.2), true), "human at the line uses kitchen camera")
	failed += _expect(not KitchenOccupancy.in_front_view(Vector2(5.0, 40.6), true), "human baseline uses back camera")
	failed += _expect(KitchenOccupancy.is_on_line(Vector2(5.0, 13.8), false), "cpu home_nvz is on the kitchen line")
	failed += _expect(KitchenOccupancy.is_set_on_line(Vector2(5.0, 30.2), true, 0.2), "stopped on the line is set")
	failed += _expect(not KitchenOccupancy.is_set_on_line(Vector2(5.0, 30.2), true, 8.0), "running on the line is not set")
	failed += _expect(KitchenOccupancy.in_front_view(Vector2(5.0, 26.0), true), "inside NVZ keeps kitchen camera")
	var back := CameraRig.compose(Vector2(15.0, 40.6), Vector3(10.0, 3.0, 8.0), 0.0)
	var kit := CameraRig.compose(Vector2(15.0, 30.2), Vector3(10.0, 2.5, 20.0), 1.0)
	failed += _expect(kit.pos.y + 1.5 < back.pos.y, "kitchen camera sits lower")
	failed += _expect((kit.pos.z - 30.2) + 3.0 < (back.pos.z - 40.6), "kitchen camera pulls in behind the player")
	failed += _expect(kit.fov < back.fov, "kitchen camera FOV is tighter")
	failed += _expect(absf(back.look.z - MatchRules.NVZ_SOUTH) < 12.0, "pulled-back camera looks toward the kitchen")
	failed += _expect(back.look.y > 2.2 and kit.look.y > 2.2, "both cameras look at 3D play height")
	failed += _expect(CameraRig.follow_speed(1.0, true) > CameraRig.follow_speed(0.0, false), "set camera locks faster")
	var hit: Variant = CourtMap.ray_ground(Vector3(10.0, 10.0, 50.0), Vector3(0.0, -1.0, -2.0).normalized())
	failed += _expect(hit is Vector2, "ground ray hits the court plane")
	if hit is Vector2:
		failed += _expect((hit as Vector2).y < 50.0, "ground ray lands in front of the camera")
	failed += _expect(CourtMap.ray_ground(Vector3(10.0, 10.0, 50.0), Vector3(0.0, 1.0, 0.0)) == null, "upward ray misses the ground")
	failed += _expect(CourtMap.to_world(Vector2(10.0, 22.0), 3.0) == Vector3(10.0, 3.0, 22.0), "court maps x to x and y to z")
	var clamped := CourtMap.clamp_aim(Vector2(40.0, 40.0))
	failed += _expect(clamped.x <= 22.0 and clamped.y < MatchRules.NET_Y, "aim clamp stays north of the net")
	var map_top := Minimap.local_to_court(Vector2(8.0 + 72.0, 8.0), Vector2(160.0, 264.0))
	failed += _expect(absf(map_top.x - 10.0) < 0.05 and absf(map_top.y) < 0.05, "minimap top-center is north baseline")
	var map_bot := Minimap.local_to_court(Vector2(8.0 + 72.0, 264.0 - 8.0), Vector2(160.0, 264.0))
	failed += _expect(absf(map_bot.y - MatchRules.COURT_LENGTH) < 0.05, "minimap bottom-center is south baseline")
	if failed == 0:
		print("check_slice: ok")
		quit(0)
	else:
		print("check_slice: %d failed" % failed)
		quit(1)


func _expect(cond: bool, label: String) -> int:
	if cond:
		return 0
	print("FAIL: ", label)
	return 1
