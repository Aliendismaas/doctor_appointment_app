import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';

class PostProductPage extends StatefulWidget {
  const PostProductPage({super.key});

  @override
  State<PostProductPage> createState() => _PostProductPageState();
}

class _PostProductPageState extends State<PostProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceRangeController = TextEditingController();
  final _brandController = TextEditingController();
  final _sizeController = TextEditingController();
  final _descriptionController = TextEditingController();

  final picker = ImagePicker();
  double _rating = 3.0;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  final List<String> _allColors = [
    "Red",
    "Blue",
    "Black",
    "White",
    "Green",
    "Yellow",
    "Purple",
    "Orange",
    "Grey",
    "Pink",
    "Brown",
  ];
  bool _showDropdown = false;
  List<String> _selectedColors = [];
  List<Uint8List> _imageBytesList = [];

  void _toggleColor(String color) {
    setState(() {
      if (_selectedColors.contains(color)) {
        _selectedColors.remove(color);
      } else {
        _selectedColors.add(color);
      }
    });
  }

  Future<void> _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null) {
      for (var image in images) {
        Uint8List bytes = await image.readAsBytes();
        setState(() {
          _imageBytesList.add(bytes);
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageBytesList.removeAt(index);
    });
  }

  Future<void> _postProduct() async {
    if (!_formKey.currentState!.validate() || _imageBytesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields and add at least one image"),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final uuid = const Uuid().v4();
      List<String> imageUrls = [];

      for (var imageBytes in _imageBytesList) {
        final path =
            "products/$uuid/${DateTime.now().millisecondsSinceEpoch}.jpg";
        await supabase.storage
            .from("avatars")
            .uploadBinary(
              path,
              imageBytes,
              fileOptions: const FileOptions(contentType: "image/jpeg"),
            );
        final url = supabase.storage.from("avatars").getPublicUrl(path);
        imageUrls.add(url);
      }

      await supabase.from("products").insert({
        "images": imageUrls,
        "title": _titleController.text.trim(),
        "rating": _rating,
        "price_range": _priceRangeController.text.trim(),
        "brand": _brandController.text.trim(),
        "color": _selectedColors,
        "size": _sizeController.text.trim(),
        "description": _descriptionController.text.trim(),
        "posted_by": "admin",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Product posted successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade200, Colors.indigo.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 2)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post Product"),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.indigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pick Images Button
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text("Pick Images"),
                  ),
                ),
                const SizedBox(height: 10),

                // Image Preview
                if (_imageBytesList.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_imageBytesList.length, (index) {
                        return Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade200,
                                    Colors.deepPurple.shade100,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                image: DecorationImage(
                                  image: MemoryImage(_imageBytesList[index]),
                                  fit: BoxFit.cover,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeImage(index),
                              child: const CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 14,
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                const SizedBox(height: 20),

                // Inputs
                _buildTextInput(
                  controller: _titleController,
                  label: "Title",
                  validator: (value) => value == null || value.trim().length < 3
                      ? "Enter a valid title"
                      : null,
                ),
                _buildTextInput(
                  controller: _priceRangeController,
                  label: "Price Range (e.g. \$50 - \$100)",
                  validator: (value) => value == null || !value.contains("-")
                      ? "Enter valid price range"
                      : null,
                ),
                _buildTextInput(
                  controller: _brandController,
                  label: "Brand",
                  validator: (value) => value == null || value.trim().isEmpty
                      ? "Enter brand"
                      : null,
                ),

                // Colors Dropdown
                GestureDetector(
                  onTap: () => setState(() => _showDropdown = !_showDropdown),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade200,
                          Colors.indigo.shade200,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedColors.isEmpty
                                ? "Select Colors"
                                : _selectedColors.join(", "),
                            style: TextStyle(
                              color: _selectedColors.isEmpty
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                        ),
                        Icon(
                          _showDropdown
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: Colors.deepPurple,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showDropdown)
                  Wrap(
                    spacing: 8,
                    children: _allColors.map((color) {
                      final isSelected = _selectedColors.contains(color);
                      return FilterChip(
                        label: Text(
                          color,
                          style: const TextStyle(color: Colors.white),
                        ),
                        selected: isSelected,
                        onSelected: (_) => _toggleColor(color),
                        selectedColor: Colors.deepPurple.shade400,
                        backgroundColor: Colors.deepPurple.shade200,
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),

                _buildTextInput(
                  controller: _sizeController,
                  label: "Size",
                  validator: (value) => value == null || value.trim().isEmpty
                      ? "Enter size"
                      : null,
                ),
                _buildTextInput(
                  controller: _descriptionController,
                  label: "Description",
                  maxLines: 3,
                  validator: (value) =>
                      value == null || value.trim().length < 10
                      ? "Enter at least 10 chars"
                      : null,
                ),

                const SizedBox(height: 20),

                // Rating
                Row(
                  children: [
                    const Text(
                      "Rating:",
                      style: TextStyle(color: Colors.white),
                    ),
                    Expanded(
                      child: Slider(
                        value: _rating,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        activeColor: Colors.amber,
                        label: _rating.toString(),
                        onChanged: (value) => setState(() => _rating = value),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Post Button
                Center(
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.purple,
                                Colors.deepPurple,
                                Colors.indigo,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 14,
                              ),
                            ),
                            onPressed: _postProduct,
                            child: const Text(
                              "Post Product",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
