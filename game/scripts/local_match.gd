class_name LocalMatch
extends RefCounted

## Scene-independent rules. The controller reacts to phase changes.
enum Phase { LOBBY, COUNTDOWN, PLAYING, GOAL, FINISHED }
const MATCH_SECONDS := 90.0
const WIN_SCORE := 5
const COUNTDOWN_SECONDS := 3.0
const GOAL_SECONDS := 1.8

var phase: Phase = Phase.LOBBY
var player_count := 2
var scores: Array[int] = [0, 0]
var time_left := MATCH_SECONDS
var phase_left := 0.0

func start(count: int) -> void:
	player_count = clampi(count, 1, 4)
	scores = [0, 0]
	time_left = MATCH_SECONDS
	_begin_countdown()

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	match phase:
		Phase.COUNTDOWN, Phase.GOAL:
			phase_left = maxf(0.0, phase_left - delta)
			if phase_left > 0.0:
				return
			if phase == Phase.COUNTDOWN:
				phase = Phase.PLAYING
			elif player_count > 1 and (scores.max() >= WIN_SCORE or time_left <= 0.0):
				phase = Phase.FINISHED
			else:
				_begin_countdown()
		Phase.PLAYING:
			if player_count > 1:
				time_left = maxf(0.0, time_left - delta)
				if time_left <= 0.0:
					phase = Phase.FINISHED

func award_goal(defending_team: int) -> bool:
	if phase != Phase.PLAYING or defending_team < 0 or defending_team > 1:
		return false
	scores[1 - defending_team] += 1
	phase = Phase.GOAL
	phase_left = GOAL_SECONDS
	return true

func winner() -> int:
	if scores[0] == scores[1]:
		return -1
	return 0 if scores[0] > scores[1] else 1

func _begin_countdown() -> void:
	phase = Phase.COUNTDOWN
	phase_left = COUNTDOWN_SECONDS
