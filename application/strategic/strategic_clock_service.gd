class_name StrategicClockService
extends RefCounted

const SPEED_PAUSED: int = 0
const SPEED_NORMAL: int = 1
const SPEED_FAST: int = 5
const SPEED_VERY_FAST: int = 20

var speed: int = SPEED_PAUSED
var _accumulated_campaign_minutes: float = 0.0


func set_speed(value: int) -> void:
	if value not in [SPEED_PAUSED, SPEED_NORMAL, SPEED_FAST, SPEED_VERY_FAST]:
		value = SPEED_PAUSED
	speed = value


func pause() -> void:
	speed = SPEED_PAUSED


func consume_tick_delta(real_delta: float) -> int:
	if speed <= 0 or real_delta <= 0.0:
		return 0
	# Normal speed advances one strategic minute per real second. Faster modes
	# batch the same authoritative minute ticks rather than changing clock rules.
	_accumulated_campaign_minutes += real_delta * float(speed)
	var whole_minutes: int = int(floor(_accumulated_campaign_minutes))
	if whole_minutes <= 0:
		return 0
	_accumulated_campaign_minutes -= float(whole_minutes)
	return whole_minutes


static func day_number(campaign_tick: int) -> int:
	return maxi(1, campaign_tick / 1440 + 1)


static func hour(campaign_tick: int) -> int:
	return posmod(campaign_tick, 1440) / 60


static func minute(campaign_tick: int) -> int:
	return posmod(campaign_tick, 60)
