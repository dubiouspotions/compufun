extends "res://tests/test.gd"
## The committed story files load as the week that the wiki's Storyline times: seven days, each with
## its errands by code and customer, and a problem for every computer left on the counter.

const WEEK: Array = [
	["0101 middle_manager", "0102 skater_bro", "0103 retired_accountant", "0104 activist_guy"],
	["0201 nice_lady", "0202 young_entrepreneur", "0203 retired_accountant"],
	["0301 office_girl", "0302 hat_guy", "0303 retired_accountant"],
	["0401 young_entrepreneur", "0402 attractive_guy", "0403 skater_bro"],
	["0501 hat_guy", "0502 office_girl", "0503 nice_guy"],
	["0601 young_entrepreneur", "0602 top_hat_man", "0603 activist_guy"],
	["0701 hat_guy", "0702 office_girl", "0702 young_entrepreneur", "0703 skater_bro"],
]
## The hat guy's computer has no parts (corruption, not a problem), and the activist leaves his computer for good.
const NO_PROBLEM_YET: Array[String] = ["0603 activist_guy"]


func run() -> void:
	var week := StoryFiles.load_week()
	check("no errors", week.errors, PackedStringArray())
	check("7 days", week.days.size(), 7)
	for day: Day in week.days:
		var errands: Array[String] = []
		var left_without_problem: Array[String] = []
		for errand: Errand in day.errands:
			var name := "%s %s" % [errand.code, errand.customer.resource_path.get_file().get_basename() if errand.customer != null else "?"]
			errands.append(name)
			if errand.brings == Errand.Brings.LEAVES and errand.problem == null and name not in NO_PROBLEM_YET:
				left_without_problem.append(name)
		check("day %d's errands" % day.number, errands, WEEK[day.number - 1] if day.number <= WEEK.size() else [])
		check("day %d: every computer left on the counter has a problem" % day.number, left_without_problem, [] as Array[String])
