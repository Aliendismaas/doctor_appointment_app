import 'dart:convert';
import 'package:doctor/admin/game/sport/cart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final supabase = Supabase.instance.client;

  Map<String, double> quantities = {};
  bool isAdding = false;
  bool isAdmin = false;

  int _currentImageIndex = 0; // Track which image is showing

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  Future<void> checkAdmin() async {
    final currentUser = supabase.auth.currentUser;
    final userEmail = currentUser?.email ?? '';
    if (currentUser == null) return;

    try {
      final res = await supabase
          .from('Users')
          .select('role')
          .eq('email', userEmail)
          .maybeSingle();

      setState(() {
        isAdmin = res?['role'] == 'admin';
      });
    } catch (e) {
      setState(() => isAdmin = false);
    }
  }

  void _incrementQuantity(String productId) {
    setState(() {
      double current = quantities[productId] ?? 0.0;
      current += 1;
      quantities[productId] = double.parse(current.toStringAsFixed(2));
    });
  }

  void _decrementQuantity(String productId) {
    setState(() {
      double current = quantities[productId] ?? 0.0;
      if (current > 1) {
        current -= 1;
        quantities[productId] = double.parse(current.toStringAsFixed(2));
      } else {
        quantities[productId] = 0.0;
      }
    });
  }

  Future<void> addToCart() async {
    // Handle images
    List<String> images = [];
    if (widget.product['images'] != null) {
      if (widget.product['images'] is String) {
        try {
          images = List<String>.from(jsonDecode(widget.product['images']));
        } catch (_) {
          images = [];
        }
      } else if (widget.product['images'] is List) {
        images = List<String>.from(widget.product['images']);
      }
    }

    final productId = widget.product['id'].toString();
    final name = widget.product['title'] ?? '';
    final image = images.isNotEmpty
        ? images[_currentImageIndex]
        : ''; // ✅ use current image
    final pricePerKg =
        double.tryParse(widget.product['price_range'] ?? '0') ?? 0;
    final quantity = quantities[productId] ?? 0.0;

    if (quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a quantity')));
      return;
    }

    final currentUser = supabase.auth.currentUser;
    final userEmail = currentUser?.email ?? '';

    setState(() => isAdding = true);

    try {
      final totalPrice = quantity * pricePerKg;

      await supabase.from('cart').insert({
        'product_id': productId,
        'name': name,
        'image_url': image, // ✅ only current image
        'quantity': quantity.toString(),
        'price': totalPrice.toString(),
        'createdby': userEmail,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to cart')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isAdding = false);
    }
  }

  void _onMenuSelected(String choice) async {
    if (choice == 'edit') {
      // navigate to edit page
    } else if (choice == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await supabase
              .from('products')
              .delete()
              .eq('id', widget.product['id']);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Product deleted')));
          Navigator.pop(context, true);
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting product: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle images array
    List<String> images = [];
    if (widget.product['images'] != null) {
      if (widget.product['images'] is String) {
        try {
          images = List<String>.from(jsonDecode(widget.product['images']));
        } catch (_) {
          images = [];
        }
      } else if (widget.product['images'] is List) {
        images = List<String>.from(widget.product['images']);
      }
    }
    final imageUrlFallback = 'https://via.placeholder.com/300';

    // Handle colors array
    List<String> colors = [];
    if (widget.product['color'] != null) {
      if (widget.product['color'] is String) {
        try {
          colors = List<String>.from(jsonDecode(widget.product['color']));
        } catch (_) {
          colors = [];
        }
      } else if (widget.product['color'] is List) {
        colors = List<String>.from(widget.product['color']);
      }
    }

    final title = widget.product['title'] ?? '';
    final price = widget.product['price_range'] ?? '';
    final brand = widget.product['brand'] ?? '';
    final size = widget.product['size'] ?? '';
    final rating = (widget.product['rating'] ?? 0).toDouble();
    final description = widget.product['description'] ?? '';
    final productId = widget.product['id'].toString();
    final quantity = quantities[productId] ?? 0;

    // Inside Scaffold body
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(
          0xFF3C47A5,
        ), // Matches drawer start gradient
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              );
            },
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: _onMenuSelected,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3C47A5), Color(0xFFEAECEA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image slider
                if (images.isNotEmpty) ...[
                  CarouselSlider(
                    items: images
                        .map(
                          (img) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              img,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                        .toList(),
                    options: CarouselOptions(
                      height: 250,
                      viewportFraction: 1.0,
                      enableInfiniteScroll: false,
                      onPageChanged: (index, _) =>
                          setState(() => _currentImageIndex = index),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: images.asMap().entries.map((entry) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == entry.key
                              ? Colors.white
                              : Colors.grey.shade400,
                        ),
                      );
                    }).toList(),
                  ),
                ] else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrlFallback,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 16),

                // Title & Price Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8FA5FF), Color(0xFF3C47A5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tsh: $price',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            rating.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Brand: $brand',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Colors, Size, Description (similar gradient cards)
                if (colors.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8FA5FF), Color(0xFF3C47A5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 8,
                      children: colors
                          .map(
                            (c) => Chip(
                              label: Text(c),
                              backgroundColor: Colors.white70,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  "Description",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),
                // Quantity selector gradient card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8FA5FF), Color(0xFF3C47A5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white,
                        ),
                        onPressed: () => _decrementQuantity(productId),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        quantity.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                        ),
                        onPressed: () => _incrementQuantity(productId),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Add to Cart Button Gradient
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: addToCart,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text(
                      "Add to Cart",
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: const Color(
                        0xFF3C47A5,
                      ), // fallback solid
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
