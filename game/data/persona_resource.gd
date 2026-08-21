class_name PersonaResource
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var character_manifest: String = ""
@export var voice_id: String = ""

func is_valid() -> bool:
	return not id.strip_edges().is_empty() \
		and not display_name.strip_edges().is_empty() \
		and not character_manifest.strip_edges().is_empty() \
		and not voice_id.strip_edges().is_empty()
