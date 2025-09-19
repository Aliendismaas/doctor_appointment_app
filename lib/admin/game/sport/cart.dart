// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'dart:math';

// class CartPage extends StatefulWidget {
//   const CartPage({super.key});

//   @override
//   State<CartPage> createState() => _CartPageState();
// }

// class _CartPageState extends State<CartPage> {
//   final supabase = Supabase.instance.client;
//   List<Map<String, dynamic>> cartItems = [];
//   bool isLoading = true;
//   bool isCheckingOut = false;

//   String generateSaleCode() {
//     final random = Random();
//     int number = random.nextInt(9999) + 1; // 1 to 9999
//     return 'tam${number.toString().padLeft(4, '0')}';
//   }

//   @override
//   void initState() {
//     super.initState();
//     fetchCartItems();
//   }

//   Future<void> fetchCartItems() async {
//     setState(() => isLoading = true);

//     try {
//       final currentUser = supabase.auth.currentUser;
//       final userEmail = currentUser?.email ?? '';
//       final res = await supabase
//           .from('cart')
//           .select()
//           .eq('createdby', userEmail)
//           .order('created_at', ascending: false);

//       if (res != null) {
//         cartItems = List<Map<String, dynamic>>.from(res);
//       }
//     } catch (e) {
//       debugPrint('Error fetching cart: $e');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Failed to load cart items: $e')));
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> removeItem(String cartId) async {
//     try {
//       await supabase.from('cart').delete().eq('id', cartId);
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Item removed from cart')));
//       await fetchCartItems();
//     } catch (e) {
//       debugPrint('Error removing item: $e');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Failed to remove item: $e')));
//     }
//   }

//   double getTotalPrice() {
//     double total = 0;
//     for (var item in cartItems) {
//       final priceRaw = item['price'];
//       final price = priceRaw is num
//           ? priceRaw.toDouble()
//           : double.tryParse(priceRaw.toString()) ?? 0.0;
//       total += price;
//     }
//     return total;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Make order', style: GoogleFonts.pacifico()),
//         backgroundColor: const Color.fromARGB(255, 9, 34, 143),
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : cartItems.isEmpty
//           ? const Center(child: Text('No Order yet'))
//           : Column(
//               children: [
//                 Expanded(
//                   child: ListView.builder(
//                     itemCount: cartItems.length,
//                     itemBuilder: (context, index) {
//                       final item = cartItems[index];
//                       final quantityRaw = item['quantity'];
//                       final quantity = quantityRaw is num
//                           ? quantityRaw.toDouble()
//                           : double.tryParse(quantityRaw.toString()) ?? 0.0;
//                       final priceRaw = item['price'];
//                       final price = priceRaw is num
//                           ? priceRaw.toDouble()
//                           : double.tryParse(priceRaw.toString()) ?? 0.0;

//                       return Card(
//                         margin: const EdgeInsets.symmetric(
//                           horizontal: 16,
//                           vertical: 8,
//                         ),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: ListTile(
//                           leading: ClipRRect(
//                             borderRadius: BorderRadius.circular(8),
//                             child: Image.network(
//                               item['image_url'],
//                               width: 60,
//                               height: 60,
//                               fit: BoxFit.cover,
//                               errorBuilder: (context, error, stackTrace) =>
//                                   Container(
//                                     width: 60,
//                                     height: 60,
//                                     color: Colors.grey[300],
//                                     child: const Icon(
//                                       Icons.broken_image,
//                                       color: Color.fromARGB(255, 82, 79, 79),
//                                     ),
//                                   ),
//                             ),
//                           ),
//                           title: Text(
//                             item['name'],
//                             style: const TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                           subtitle: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   IconButton(
//                                     icon: const Icon(
//                                       Icons.remove_circle_outline,
//                                     ),
//                                     onPressed: () async {
//                                       if (quantity > 1) {
//                                         final unitPrice =
//                                             price /
//                                             quantity; // 🔑 calculate price per unit
//                                         final newQty = quantity - 1;
//                                         final newPrice = unitPrice * newQty;

//                                         // Update in Supabase
//                                         await supabase
//                                             .from('cart')
//                                             .update({
//                                               'quantity': newQty.toString(),
//                                               'price': newPrice.toString(),
//                                             })
//                                             .eq('id', item['id']);

//                                         // Update in UI without reloading entire page
//                                         setState(() {
//                                           cartItems[index]['quantity'] = newQty;
//                                           cartItems[index]['price'] = newPrice;
//                                         });
//                                       } else {
//                                         await removeItem(item['id'].toString());
//                                       }
//                                     },
//                                   ),
//                                   Text(
//                                     quantity.toStringAsFixed(0),
//                                     style: const TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                   IconButton(
//                                     icon: const Icon(Icons.add_circle_outline),
//                                     onPressed: () async {
//                                       double newQty = quantity + 1;
//                                       await supabase
//                                           .from('cart')
//                                           .update({
//                                             'quantity': newQty.toString(),
//                                           })
//                                           .eq('id', item['id']);
//                                       await fetchCartItems();
//                                     },
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 'Tsh: ${price.toStringAsFixed(0)}',
//                                 style: const TextStyle(
//                                   color: Color.fromARGB(255, 76, 83, 175),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           trailing: IconButton(
//                             icon: const Icon(Icons.cancel, color: Colors.red),
//                             onPressed: () => removeItem(item['id'].toString()),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 12,
//                   ),
//                   color: Colors.grey.shade100,
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         'Total:',
//                         style: GoogleFonts.poppins(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Text(
//                         'Tsh${getTotalPrice().toStringAsFixed(0)}',
//                         style: GoogleFonts.poppins(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: const Color.fromARGB(255, 231, 232, 236),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 10),

//                 // Checkout Button
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 8,
//                   ),
//                   child: ElevatedButton.icon(
//                     icon: isCheckingOut
//                         ? const SizedBox(
//                             width: 24,
//                             height: 24,
//                             child: CircularProgressIndicator(
//                               color: Colors.white,
//                               strokeWidth: 2,
//                             ),
//                           )
//                         : const Icon(Icons.check_circle_outline),
//                     label: Text(
//                       isCheckingOut ? 'Processing...' : 'Checkout',
//                       style: const TextStyle(fontSize: 18),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color.fromARGB(255, 9, 22, 143),
//                       minimumSize: const Size.fromHeight(50),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     onPressed: () {},
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> cartItems = [];
  bool isLoading = true;
  bool isCheckingOut = false;

  // Stripe Configuration - Replace with your actual keys
  static const String stripePublishableKey = 'pk_test_51OLLxYIsidHSAe6gli3Y0pA7E7HEcSNY0Q6q4Gf2BHx0hsl5a5I9mPE6h4riDJtETjUjSx53IpyL2YoblUkLAY4v000s5BvAKf';
  static const String stripeSecretKey = 'sk_test_51OLLxYIsidHSAe6gP9uNr5J2wHmWnc4ZEdIHWi8B71tMBgJp1982PPLGbNz4vtdsgLMMtt9czgAwt3J3YomJKcwX00rLM4qKFr';

  String generateSaleCode() {
    final random = Random();
    int number = random.nextInt(9999) + 1;
    return 'tam${number.toString().padLeft(4, '0')}';
  }

  @override
  void initState() {
    super.initState();
    // Initialize Stripe
    Stripe.publishableKey = stripePublishableKey;
    fetchCartItems();
  }

  Future<void> fetchCartItems() async {
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      final userEmail = currentUser?.email ?? '';
      final res = await supabase
          .from('cart')
          .select()
          .eq('createdby', userEmail)
          .order('created_at', ascending: false);

      if (res != null) {
        cartItems = List<Map<String, dynamic>>.from(res);
      }
    } catch (e) {
      debugPrint('Error fetching cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load cart items: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> removeItem(String cartId) async {
    try {
      await supabase.from('cart').delete().eq('id', cartId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removed from cart')),
      );
      await fetchCartItems();
    } catch (e) {
      debugPrint('Error removing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove item: $e')),
      );
    }
  }

  double getTotalPrice() {
    double total = 0;
    for (var item in cartItems) {
      final priceRaw = item['price'];
      final price = priceRaw is num
          ? priceRaw.toDouble()
          : double.tryParse(priceRaw.toString()) ?? 0.0;
      total += price;
    }
    return total;
  }

  // Create Payment Intent on your backend
  Future<Map<String, dynamic>?> createPaymentIntent(double amount) async {
    try {
      // Convert amount to cents (Stripe uses cents)
      int amountInCents = (amount * 100).round();
      
      // This should be your backend endpoint
      // For now, we'll create it directly (NOT RECOMMENDED for production)
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amountInCents.toString(),
          'currency': 'usd', // Change to 'tzs' for Tanzanian Shilling if supported
          'automatic_payment_methods[enabled]': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to create payment intent: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating payment intent: $e');
      return null;
    }
  }

  Future<void> processPayment() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    setState(() => isCheckingOut = true);

    try {
      final totalAmount = getTotalPrice();
      
      // Create payment intent
      final paymentIntentData = await createPaymentIntent(totalAmount);
      
      if (paymentIntentData == null) {
        throw Exception('Failed to create payment intent');
      }

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['client_secret'],
          merchantDisplayName: 'Doctor Appointment App',
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            email: supabase.auth.currentUser?.email,
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment successful
      await processSuccessfulPayment();
      
    } on StripeException catch (e) {
      debugPrint('Stripe error: ${e.error.localizedMessage}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.error.localizedMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('Payment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isCheckingOut = false);
    }
  }

  Future<void> processSuccessfulPayment() async {
    try {
      final saleCode = generateSaleCode();
      final currentUser = supabase.auth.currentUser;
      final userEmail = currentUser?.email ?? '';

      // Create order record
      await supabase.from('orders').insert({
        'sale_code': saleCode,
        'user_email': userEmail,
        'total_amount': getTotalPrice(),
        'status': 'completed',
        'payment_method': 'stripe',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Move cart items to order_items
      for (var item in cartItems) {
        await supabase.from('order_items').insert({
          'sale_code': saleCode,
          'product_name': item['name'],
          'quantity': item['quantity'],
          'price': item['price'],
          'image_url': item['image_url'],
        });
      }

      // Clear cart
      await supabase.from('cart').delete().eq('createdby', userEmail);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful! Order #$saleCode created'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate back or to order confirmation page
      Navigator.of(context).pop();
      
    } catch (e) {
      debugPrint('Error processing successful payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful but order processing failed: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Make order', style: GoogleFonts.pacifico()),
        backgroundColor: const Color.fromARGB(255, 9, 34, 143),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cartItems.isEmpty
              ? const Center(child: Text('No Order yet'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final quantityRaw = item['quantity'];
                          final quantity = quantityRaw is num
                              ? quantityRaw.toDouble()
                              : double.tryParse(quantityRaw.toString()) ?? 0.0;
                          final priceRaw = item['price'];
                          final price = priceRaw is num
                              ? priceRaw.toDouble()
                              : double.tryParse(priceRaw.toString()) ?? 0.0;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['image_url'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Color.fromARGB(255, 82, 79, 79),
                                        ),
                                      ),
                                ),
                              ),
                              title: Text(
                                item['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed: () async {
                                          if (quantity > 1) {
                                            final unitPrice = price / quantity;
                                            final newQty = quantity - 1;
                                            final newPrice = unitPrice * newQty;

                                            await supabase
                                                .from('cart')
                                                .update({
                                                  'quantity': newQty.toString(),
                                                  'price': newPrice.toString(),
                                                })
                                                .eq('id', item['id']);

                                            setState(() {
                                              cartItems[index]['quantity'] = newQty;
                                              cartItems[index]['price'] = newPrice;
                                            });
                                          } else {
                                            await removeItem(item['id'].toString());
                                          }
                                        },
                                      ),
                                      Text(
                                        quantity.toStringAsFixed(0),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () async {
                                          double newQty = quantity + 1;
                                          await supabase
                                              .from('cart')
                                              .update({
                                                'quantity': newQty.toString(),
                                              })
                                              .eq('id', item['id']);
                                          await fetchCartItems();
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tsh: ${price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color.fromARGB(255, 76, 83, 175),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => removeItem(item['id'].toString()),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: Colors.grey.shade100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tsh${getTotalPrice().toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 9, 34, 143),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Checkout Button with Stripe
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ElevatedButton.icon(
                        icon: isCheckingOut
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.payment, color: Colors.white),
                        label: Text(
                          isCheckingOut ? 'Processing...' : 'Pay with Stripe',
                          style: const TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 9, 22, 143),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isCheckingOut ? null : processPayment,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
    );
  }
}