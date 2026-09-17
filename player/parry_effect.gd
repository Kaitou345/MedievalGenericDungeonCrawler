extends CPUParticles2D

func _ready() -> void:
	# Shrink the entire particle effect size (adjust 0.4 to make it smaller or larger)
	scale = Vector2(0.4, 0.4)

	# Generate a tiny 8x8 white dot texture procedurally
	if not texture:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		texture = ImageTexture.create_from_image(img)
	
	emitting = true
	await get_tree().create_timer(lifetime).timeout
	queue_free()
