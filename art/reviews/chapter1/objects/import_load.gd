extends SceneTree
func _initialize() -> void:
 var files := DirAccess.get_files_at("res://import_assets")
 var count := 0
 for file_name in files:
  if not file_name.ends_with(".png"):continue
  var texture = load("res://import_assets/"+file_name)
  if not (texture is Texture2D) or texture.get_width() <= 0 or texture.get_height() <= 0:
   push_error("Cannot load imported texture: "+file_name)
   quit(1)
   return
  count+=1
 print("Imported Texture2D resources loaded: ",count)
 quit(0 if count==29 else 1)
