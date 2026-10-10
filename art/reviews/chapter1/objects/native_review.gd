extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 var board := Node2D.new()
 board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 root.add_child(board)
 var background := Polygon2D.new()
 background.polygon=PackedVector2Array([Vector2.ZERO,Vector2(1024,0),Vector2(1024,800),Vector2(0,800)])
 background.color=Color("61793b")
 board.add_child(background)
 var args := OS.get_cmdline_user_args()
 var base: String=args[0]
 var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(base+"/game/assets/chapter1/objects/object_metadata.json"))["assets"]
 var paths: Array=["game/assets/phase0/farmhouse.png","game/assets/phase0/oak_tree.png"]
 for entry in entries: paths.append(entry["runtime_path"])
 for index in paths.size():
  var image := Image.load_from_file(base+"/"+paths[index])
  if image == null: quit(1); return
  var sprite := Sprite2D.new()
  sprite.texture=ImageTexture.create_from_image(image)
  sprite.centered=false
  sprite.position=Vector2(16+(index%6)*168,16+(index/6)*192)
  board.add_child(sprite)
  var caption := Label.new()
  caption.text=paths[index].get_file().get_basename()
  caption.position=Vector2(sprite.position.x,sprite.position.y+156)
  caption.add_theme_font_size_override("font_size",12)
  board.add_child(caption)
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 var error := image.save_png(args[1])
 print("Native object capture ",image.get_size()," result ",error)
 quit(0 if error == OK else 1)
