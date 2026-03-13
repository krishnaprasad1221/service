import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:serviceprovider/login_screen.dart';
import 'package:serviceprovider/shop_catalog_store.dart';

class ShopManagerDashboard extends StatefulWidget {
  const ShopManagerDashboard({super.key});

  @override
  State<ShopManagerDashboard> createState() => _ShopManagerDashboardState();
}

class _ShopManagerDashboardState extends State<ShopManagerDashboard> {
  final ShopCatalogStore _store = ShopCatalogStore.instance;
  static const List<String> _orderFlow = [
    'order_placed',
    'payment_confirmed',
    'processing',
    'packed',
    'shipped',
    'out_for_delivery',
    'delivered',
  ];

  int _totalItems(List<ShopCategory> categories) {
    int total = 0;
    for (final category in categories) {
      total += category.items.length;
    }
    return total;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'order_placed':
        return 'Order Placed';
      case 'payment_confirmed':
        return 'Payment Confirmed';
      case 'processing':
        return 'Processing';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'Shipped';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  String _normalizeOrderStatus(Map<String, dynamic> data) {
    final String? delivery = (data['deliveryStatus'] as String?)?.trim();
    if (delivery != null && delivery.isNotEmpty) return delivery;
    final String legacy = (data['orderStatus'] as String?)?.toLowerCase() ?? '';
    if (legacy == 'delivered') return 'delivered';
    return 'payment_confirmed';
  }

  int _statusIndex(String status) {
    final index = _orderFlow.indexOf(status);
    return index >= 0 ? index : 0;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Color _statusColor(String status) {
    if (status == 'delivered') return Colors.green;
    if (status == 'out_for_delivery') return Colors.orange;
    if (status == 'shipped' || status == 'packed' || status == 'processing') {
      return Colors.deepPurple;
    }
    return Colors.blueGrey;
  }

  String _formatMs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.day.toString().padLeft(2, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Map<String, int> _timelineTimes(Map<String, dynamic> data) {
    final Map<String, int> out = {};
    final timeline = data['statusTimeline'];
    if (timeline is List) {
      for (final row in timeline) {
        if (row is Map) {
          final key = row['status'];
          final at = row['atMs'];
          if (key is String) {
            final int atMs = _asInt(at, fallback: 0);
            if (atMs > 0) out[key] = atMs;
          }
        }
      }
    }
    final int createdMs = _asInt(data['createdAtLocalMs'], fallback: 0);
    if (createdMs > 0 && !out.containsKey('order_placed')) {
      out['order_placed'] = createdMs;
    }
    if (createdMs > 0 && !out.containsKey('payment_confirmed')) {
      out['payment_confirmed'] = createdMs;
    }
    return out;
  }

  Future<void> _moveOrderToNextStep(
    String orderDocId,
    Map<String, dynamic> orderData,
  ) async {
    final String current = _normalizeOrderStatus(orderData);
    final int index = _statusIndex(current);
    if (index >= _orderFlow.length - 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order is already delivered.')),
      );
      return;
    }

    final String next = _orderFlow[index + 1];
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String actor = FirebaseAuth.instance.currentUser?.uid ?? 'shop';
    final Map<String, dynamic> updates = {
      'deliveryStatus': next,
      'lastStatusUpdateMs': nowMs,
      'orderStatus': next == 'delivered'
          ? 'delivered'
          : ((orderData['orderStatus'] as String?) ?? 'paid'),
      'statusTimeline': FieldValue.arrayUnion([
        {
          'status': next,
          'label': _statusLabel(next),
          'atMs': nowMs,
          'by': actor,
        }
      ]),
    };

    try {
      await FirebaseFirestore.instance
          .collection('shopOrders')
          .doc(orderDocId)
          .update(updates);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order: $e')),
      );
      return;
    }

    final String customerId = (orderData['customerId'] as String?) ?? '';
    if (customerId.isNotEmpty) {
      bool synced = false;
      final String orderId = (orderData['orderId'] as String?) ?? orderDocId;
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .collection('shopOrders')
            .doc(orderId)
            .update(updates);
        synced = true;
      } catch (_) {}

      if (!synced) {
        final userOrdersRef = FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .collection('shopOrders');
        final String orderCode = (orderData['orderCode'] as String?) ?? '';
        final String paymentId = (orderData['paymentId'] as String?) ?? '';
        QuerySnapshot<Map<String, dynamic>>? snap;
        if (orderCode.isNotEmpty) {
          snap =
              await userOrdersRef.where('orderCode', isEqualTo: orderCode).limit(5).get();
        } else if (paymentId.isNotEmpty) {
          snap =
              await userOrdersRef.where('paymentId', isEqualTo: paymentId).limit(5).get();
        }
        if (snap != null) {
          for (final d in snap.docs) {
            try {
              await d.reference.update(updates);
            } catch (_) {}
          }
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order moved to "${_statusLabel(next)}".')),
    );
  }

  void _showOrderTimelineSheet(Map<String, dynamic> data) {
    final String status = _normalizeOrderStatus(data);
    final int currentIndex = _statusIndex(status);
    final Map<String, int> times = _timelineTimes(data);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _orderFlow.length,
              itemBuilder: (context, i) {
                final key = _orderFlow[i];
                final bool reached = i <= currentIndex;
                final int? atMs = times[key];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        reached ? Colors.deepPurple : Colors.grey.shade300,
                    child: Icon(
                      reached ? Icons.check : Icons.circle,
                      size: reached ? 16 : 10,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    _statusLabel(key),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: reached ? Colors.black87 : Colors.grey[600],
                    ),
                  ),
                  subtitle: Text(atMs == null ? 'Pending' : _formatMs(atMs)),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomerOrderDetails(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final String customerId = (data['customerId'] as String?) ?? '';
    Map<String, dynamic>? customerData;

    if (customerId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();
        if (doc.exists) customerData = doc.data();
      } catch (_) {}
    }

    if (!mounted) return;
    final String status = _normalizeOrderStatus(data);
    final int createdMs = _asInt(data['createdAtLocalMs']);
    final String createdAt = createdMs > 0 ? _formatMs(createdMs) : '-';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Order Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _detailRow('Order ID', (data['orderId'] ?? orderId).toString()),
                  _detailRow('Order Code', (data['orderCode'] ?? '-').toString()),
                  _detailRow('Order Status', _statusLabel(status)),
                  _detailRow('Created At', createdAt),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Product Details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _detailRow('Item Name', (data['itemName'] ?? '-').toString()),
                  _detailRow('Item ID', (data['itemId'] ?? '-').toString()),
                  _detailRow(
                    'Category',
                    ((data['categoryName'] ?? data['category']) ?? '-').toString(),
                  ),
                  _detailRow('Quantity', _asInt(data['quantity'], fallback: 1).toString()),
                  _detailRow('Unit Price', 'Rs ${_asInt(data['unitPrice'])}'),
                  _detailRow('Total Amount', 'Rs ${_asInt(data['totalAmount'])}'),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Payment Details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Payment ID',
                    (data['paymentId']?.toString().isEmpty ?? true)
                        ? '-'
                        : data['paymentId'].toString(),
                  ),
                  _detailRow(
                    'Method',
                    (data['paymentMethod'] ?? 'razorpay').toString().toUpperCase(),
                  ),
                  _detailRow('Currency', (data['currency'] ?? 'INR').toString()),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Customer Details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _detailRow('Customer ID', customerId.isEmpty ? '-' : customerId),
                  _detailRow(
                    'Name',
                    (customerData?['username'] ?? customerData?['name'] ?? '-').toString(),
                  ),
                  _detailRow(
                    'Phone',
                    (customerData?['phone'] ?? customerData?['phoneNumber'] ?? '-')
                        .toString(),
                  ),
                  _detailRow(
                    'Email',
                    (data['customerEmail'] ??
                            customerData?['email'] ??
                            '-')
                        .toString(),
                  ),
                  _detailRow(
                    'Address',
                    (customerData?['address'] ??
                            customerData?['locationAddress'] ??
                            '-')
                        .toString(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                _store.addCategory(name: name);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category "$name" added.')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showAddItemDialog(ShopCategory category) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final imageController = TextEditingController();
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    final aboutController = TextEditingController();
    final suitableForController = TextEditingController();
    final warrantyController = TextEditingController();
    final highlightsController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Add Item - ${category.name}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: brandController,
                    decoration: const InputDecoration(
                      labelText: 'Brand (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: aboutController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'About Product (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: suitableForController,
                    decoration: const InputDecoration(
                      labelText: 'Suitable For (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: warrantyController,
                    decoration: const InputDecoration(
                      labelText: 'Warranty (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: highlightsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Highlights (comma separated, optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final int? price = int.tryParse(priceController.text.trim());
                if (name.isEmpty || price == null || price <= 0) return;
                final imageUrl = imageController.text.trim();
                final brand = brandController.text.trim();
                final model = modelController.text.trim();
                final about = aboutController.text.trim();
                final suitableFor = suitableForController.text.trim();
                final warranty = warrantyController.text.trim();
                final List<String> highlights = highlightsController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                _store.addItem(
                  categoryId: category.id,
                  name: name,
                  price: price,
                  imageUrl: imageUrl.isEmpty ? null : imageUrl,
                  brand: brand.isEmpty ? null : brand,
                  model: model.isEmpty ? null : model,
                  about: about.isEmpty ? null : about,
                  suitableFor: suitableFor.isEmpty ? null : suitableFor,
                  warranty: warranty.isEmpty ? null : warranty,
                  highlights: highlights,
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Item "$name" added to ${category.name}.')),
                );
              },
              child: const Text('Add Item'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteCategory(ShopCategory category) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: Text('Delete "${category.name}" and all its items?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _store.removeCategory(category.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "${category.name}" removed.')),
      );
    }
  }

  Future<void> _confirmDeleteItem(ShopCategory category, ShopItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Delete "${item.name}" from ${category.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _store.removeItem(categoryId: category.id, itemId: item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item "${item.name}" removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Shop Manager Dashboard'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<ShopCategory>>(
        valueListenable: _store.categoriesNotifier,
        builder: (context, categories, _) {
          final int totalItems = _totalItems(categories);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      title: 'Categories',
                      value: categories.length.toString(),
                      icon: Icons.category_rounded,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _KpiCard(
                      title: 'Items',
                      value: totalItems.toString(),
                      icon: Icons.inventory_2_rounded,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Manage Catalog',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (categories.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No categories yet. Tap + to add one.'),
                  ),
                ),
              ...categories.map((category) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: category.accentColor.withOpacity(0.16),
                      child: Icon(category.icon, color: category.accentColor),
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${category.items.length} items'),
                    trailing: IconButton(
                      tooltip: 'Delete category',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDeleteCategory(category),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    children: [
                      ...category.items.map((item) {
                        return ListTile(
                          dense: true,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              item.effectiveImageUrl,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 36,
                                height: 36,
                                color: category.accentColor.withOpacity(0.12),
                                child: Icon(
                                  category.icon,
                                  color: category.accentColor,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          title: Text(item.name),
                          subtitle: Text('Rs ${item.price}'),
                          trailing: IconButton(
                            tooltip: 'Delete item',
                            onPressed: () => _confirmDeleteItem(category, item),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                            ),
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _showAddItemDialog(category),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 14),
              const Text(
                'Manage Orders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('shopOrders')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Unable to load orders: ${snapshot.error}'),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs.toList() ?? [];
                  docs.sort((a, b) {
                    final int ta = _asInt(a.data()['createdAtLocalMs']);
                    final int tb = _asInt(b.data()['createdAtLocalMs']);
                    return tb.compareTo(ta);
                  });

                  if (docs.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No shop orders yet.'),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final String itemName =
                          (data['itemName'] as String?) ?? 'Product';
                      final String customerEmail =
                          (data['customerEmail'] as String?) ?? '-';
                      final int amount = _asInt(data['totalAmount']);
                      final String status = _normalizeOrderStatus(data);
                      final int idx = _statusIndex(status);
                      final bool completed = idx >= _orderFlow.length - 1;
                      final double progress =
                          (_orderFlow.length - 1) == 0 ? 0 : idx / (_orderFlow.length - 1);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      itemName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Customer: $customerEmail',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Amount: Rs $amount',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0, 1),
                                  minHeight: 7,
                                  backgroundColor: Colors.grey.shade200,
                                  color: _statusColor(status),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _showCustomerOrderDetails(doc.id, data),
                                          icon: const Icon(Icons.receipt_long_rounded),
                                          label: const Text('Order Details'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _showOrderTimelineSheet(data),
                                          icon: const Icon(Icons.timeline_rounded),
                                          label: const Text('Timeline'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: completed
                                          ? null
                                          : () => _moveOrderToNextStep(doc.id, data),
                                      icon: Icon(
                                        completed
                                            ? Icons.check_circle
                                            : Icons.arrow_forward_rounded,
                                      ),
                                      label: Text(
                                        completed ? 'Completed' : 'Next Step',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.16),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
