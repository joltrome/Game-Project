class_name OverloadScore
extends RefCounted

const FORMULA_ID := "survival100_refund250_v1"


static func calculate(
	survival_seconds: float,
	refunds: int,
	survival_points_per_second: int = 100,
	refund_points: int = 250
) -> int:
	return (
		floori(maxf(survival_seconds, 0.0) * float(maxi(survival_points_per_second, 0)))
		+ maxi(refunds, 0) * maxi(refund_points, 0)
	)


static func format_score(value: int) -> String:
	var digits := str(maxi(value, 0))
	var formatted := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return formatted
