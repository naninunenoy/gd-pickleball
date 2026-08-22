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
	failed += _expect(net_h > MatchRules.NET_HEIGHT, "standard drive clears the net")
	var drop := ShotCatalog.resolve_armed(ShotCatalog.Id.DROP, false, 1.0, true)
	failed += _expect(drop == ShotCatalog.Id.DROP, "bounce drop stays drop")
	var punch := ShotCatalog.resolve_armed(ShotCatalog.Id.VOLLEY, false, 1.0, true)
	failed += _expect(punch == ShotCatalog.Id.DRIVE, "volley after bounce becomes drive")
	var no_smash := ShotCatalog.resolve_armed(ShotCatalog.Id.SMASH, false, 2.0, true)
	failed += _expect(no_smash == ShotCatalog.Id.DRIVE, "low smash becomes drive")
	var ball := RallyBall.new()
	ball.launch(Vector2(15.0, 45.0), 2.8, Vector2(5.0, 7.5), ShotCatalog.Id.DRIVE)
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
	failed += _expect(landed, "drive serve reaches a first bounce")
	failed += _expect(MatchRules.inclusive_in_rect(ball.ground_pos, MatchRules.north_left_box()), "drive serve can land in north left box")
	ball.free()
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
