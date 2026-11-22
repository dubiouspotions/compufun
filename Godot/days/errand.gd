class_name Errand
extends Resource
## One visit on a Day: who comes in, and what is wrong with their computer this time. A customer
## who comes back on a later day brings the same computer, with that day's problem.

@export var customer: Customer
@export var problem: Problem
