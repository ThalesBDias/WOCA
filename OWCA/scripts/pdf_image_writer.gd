class_name PdfImageWriter
extends RefCounted

## Writes one or more RGB images as full-page JPEG streams in a standard A4 PDF.

const A4_WIDTH_POINTS := 595.276
const A4_HEIGHT_POINTS := 841.89


func write(path: String, pages: Array[Image], quality: float = 0.96) -> Dictionary:
	if pages.is_empty():
		return { "error": ERR_INVALID_PARAMETER, "message": "PDF needs at least one page image." }

	var page_buffers: Array[PackedByteArray] = []
	var page_sizes: Array[Vector2i] = []
	for source_image in pages:
		if source_image == null or source_image.is_empty():
			return { "error": ERR_INVALID_DATA, "message": "PDF contains an empty page image." }
		var image := source_image.duplicate() as Image
		image.convert(Image.FORMAT_RGB8)
		var jpeg := image.save_jpg_to_buffer(quality)
		if jpeg.is_empty():
			return { "error": ERR_CANT_CREATE, "message": "Could not encode a character-sheet page." }
		page_buffers.append(jpeg)
		page_sizes.append(image.get_size())

	var object_count := 2 + (pages.size() * 3)
	var object_bodies: Array[PackedByteArray] = []
	object_bodies.resize(object_count + 1)
	object_bodies[1] = _ascii("<< /Type /Catalog /Pages 2 0 R >>")

	var page_references: Array[String] = []
	for index in pages.size():
		page_references.append("%d 0 R" % (3 + index * 3))
	object_bodies[2] = _ascii("<< /Type /Pages /Count %d /Kids [%s] >>" % [pages.size(), " ".join(page_references)])

	for index in pages.size():
		var page_object := 3 + index * 3
		var content_object := page_object + 1
		var image_object := page_object + 2
		object_bodies[page_object] = _ascii("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.3f %.3f] /Resources << /ProcSet [/PDF /ImageC] /XObject << /Im%d %d 0 R >> >> /Contents %d 0 R >>" % [A4_WIDTH_POINTS, A4_HEIGHT_POINTS, index, image_object, content_object])

		var commands := "q\n%.3f 0 0 %.3f 0 0 cm\n/Im%d Do\nQ\n" % [A4_WIDTH_POINTS, A4_HEIGHT_POINTS, index]
		var command_bytes := _ascii(commands)
		object_bodies[content_object] = _stream_object("<< /Length %d >>" % command_bytes.size(), command_bytes)

		var page_size := page_sizes[index]
		var image_dictionary := "<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length %d >>" % [page_size.x, page_size.y, page_buffers[index].size()]
		object_bodies[image_object] = _stream_object(image_dictionary, page_buffers[index])

	var output := PackedByteArray()
	output.append_array(_ascii("%PDF-1.4\n"))
	output.append_array(PackedByteArray([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]))
	var offsets: Array[int] = []
	offsets.resize(object_count + 1)
	for object_id in range(1, object_count + 1):
		offsets[object_id] = output.size()
		output.append_array(_ascii("%d 0 obj\n" % object_id))
		output.append_array(object_bodies[object_id])
		output.append_array(_ascii("\nendobj\n"))

	var xref_offset := output.size()
	output.append_array(_ascii("xref\n0 %d\n" % (object_count + 1)))
	output.append_array(_ascii("0000000000 65535 f \n"))
	for object_id in range(1, object_count + 1):
		output.append_array(_ascii("%010d 00000 n \n" % offsets[object_id]))
	output.append_array(_ascii("trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [object_count + 1, xref_offset]))

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return { "error": FileAccess.get_open_error(), "message": "Could not write PDF to %s." % path }
	file.store_buffer(output)
	return { "error": OK, "message": "Exported A4 character sheet to %s." % path, "bytes": output.size(), "pages": pages.size() }


func _stream_object(dictionary: String, content: PackedByteArray) -> PackedByteArray:
	var output := _ascii(dictionary + "\nstream\n")
	output.append_array(content)
	output.append_array(_ascii("\nendstream"))
	return output


func _ascii(value: String) -> PackedByteArray:
	return value.to_ascii_buffer()
