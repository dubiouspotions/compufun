extends "res://tests/test.gd"
## The symptoms and repairs that the player marks in CompuFunDB belong to the job: they survive a
## snapshot and a restore, and a malformed list is refused.

const CUSTOMER: String = "res://customers/pierre.tres"


func run() -> void:
	check("restore a job", game.restore({"day": 1, "arrivals": 1, "jobs": [{"customer": CUSTOMER}]}), "")
	var job: Job = game.jobs[0]
	var symptom: String = job.problem.symptoms[0]
	game.mark_symptom(job, symptom, true)
	game.mark_symptom(job, symptom, true)
	check("a symptom is marked once", job.marked_symptoms, [symptom])
	game.tick_repair(job, "Unmute", true)
	game.tick_repair(job, "Unmute", false)
	check("a repair unticks", job.ticked_repairs, [])
	game.tick_repair(job, "Unmute", true)

	check("restore the snapshot", game.restore(game.snapshot()), "")
	check("the marks survive", game.jobs[0].marked_symptoms, [symptom])
	check("the ticks survive", game.jobs[0].ticked_repairs, ["Unmute"])

	var refused: String = game.restore({"jobs": [{"customer": CUSTOMER, "marked_symptoms": "oops"}]})
	check("a list that is not a list is refused", refused.contains("marked_symptoms is not a list"), true)
	check("the refusal keeps the state", game.jobs[0].ticked_repairs, ["Unmute"])
