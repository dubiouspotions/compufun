extends "res://tests/test.gd"
## A computer on the counter gets one CompuFunDB record; the record, with its marked symptoms and
## ticked repairs, survives a snapshot and a restore, and a malformed record is refused.

const CUSTOMER: String = "res://customers/skater_bro.tres"


func run() -> void:
	check("a job on the counter", game.restore({"day": 1, "arrivals": 1, "jobs": [{"customer": CUSTOMER, "order": 7}]}), "")
	var job: Job = game.jobs[0]
	check("no record yet", game.record_of(job), null)
	var record: DbRecord = game.enter_job(job, "Pierre: turns off")
	check("the record is the job's", game.record_of(job), record)
	check("the record keeps the job's order", record.job_order, 7)
	game.mark_symptom(record, "Fan clogged with dust", true)
	game.mark_symptom(record, "Fan clogged with dust", true)
	check("a symptom is marked once", record.marked_symptoms, ["Fan clogged with dust"])
	game.tick_repair(record, "Install the fan", true)
	game.tick_repair(record, "Install the fan", false)
	check("a repair unticks", record.ticked_repairs, [])
	game.tick_repair(record, "Install the fan", true)

	check("restore the snapshot", game.restore(game.snapshot()), "")
	var restored: DbRecord = game.records[0]
	check("the text survives", restored.text, "Pierre: turns off")
	check("the marks survive", restored.marked_symptoms, ["Fan clogged with dust"])
	check("the ticks survive", restored.ticked_repairs, ["Install the fan"])
	check("the job still has its record", game.record_of(game.jobs[0]), restored)

	var refused: String = game.restore({"records": [{"text": "x", "marked_symptoms": "oops"}]})
	check("a list that is not a list is refused", refused.contains("marked_symptoms of the record 'x' is not a list"), true)
	check("the refusal keeps the records", game.records[0], restored)
	check("a restore without records starts empty", game.restore({}), "")
	check("no records", game.records.size(), 0)
