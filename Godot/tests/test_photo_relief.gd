extends "res://tests/test.gd"
## The photo relief (customers/photo_relief.gd): a closed mesh from a portrait's outline, the size the
## scale asks for, with a front, a back and a back of the head.


func run() -> void:
	var person: Person = load("res://people/skater_bro/person.tres")
	var image := (person.portraits[&"neutral"] as Texture2D).get_image()
	var head := PhotoRelief.head_width(image)
	check("the head is about 28 px wide", absf(head - 28.0) <= 3.0, true)
	var scale := 0.18 / head
	var mesh := PhotoRelief.build(image, person.back.get_image(), scale, 0.12)
	check("three surfaces", mesh.get_surface_count(), PhotoRelief.Surface.size())
	for surface: int in mesh.get_surface_count():
		check("surface %d has faces" % surface, (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 30, true)
	var box := mesh.get_aabb()
	check("as tall as the portrait at the scale", absf(box.size.y - image.get_height() * scale) < 0.05, true)
	check("it bulges both ways, at most the depth", [box.position.z >= -0.12 * 0.8 - 0.001, box.end.z <= 0.12 + 0.001, box.size.z > 0.1], [true, true, true])
	check("Skater Bro has a back", person.back != null, true)
