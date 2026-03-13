import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:serviceprovider/shop_catalog_store.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedFilterCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ShopSearchResult> _buildSearchResults(List<ShopCategory> categories) {
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const <_ShopSearchResult>[];

    final List<_ShopSearchResult> results = <_ShopSearchResult>[];
    for (final category in categories) {
      for (final item in category.items) {
        final itemMatch = item.name.toLowerCase().contains(query);
        final categoryMatch = category.name.toLowerCase().contains(query);
        if (itemMatch || categoryMatch) {
          results.add(_ShopSearchResult(category: category, item: item));
        }
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Shop'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ValueListenableBuilder<List<ShopCategory>>(
        valueListenable: ShopCatalogStore.instance.categoriesNotifier,
        builder: (context, categories, _) {
          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'No categories available right now.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final List<ShopCategory> filteredCategories =
              _getFilteredCategories(categories);
          final List<_ShopSearchResult> searchResults =
              _buildSearchResults(filteredCategories);
          final bool hasQuery = _searchQuery.trim().isNotEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildCategoryBanner(categories),
              const SizedBox(height: 14),
              if (_selectedFilterCategoryId != null)
                _buildActiveFilterChip(categories),
              if (_selectedFilterCategoryId != null) const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: hasQuery
                      ? IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!hasQuery && filteredCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'No products found for this filter.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else if (!hasQuery)
                ...filteredCategories.map(
                  (category) => _CategoryQuickCard(
                    category: category,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _CategoryItemsScreen(
                            categoryId: category.id,
                          ),
                        ),
                      );
                    },
                  ),
                )
              else if (searchResults.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'No matching products found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...searchResults.map((result) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            result.item.effectiveImageUrl,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 54,
                              height: 54,
                              color: result.category.accentColor.withOpacity(0.12),
                              child: Icon(
                                result.category.icon,
                                color: result.category.accentColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.category.name,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Price: Rs ${result.item.price}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _ItemDetailsScreen(
                                  category: result.category,
                                  item: result.item,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('View Details'),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  List<ShopCategory> _getFilteredCategories(List<ShopCategory> categories) {
    if (_selectedFilterCategoryId == null) return categories;
    return categories
        .where((category) => category.id == _selectedFilterCategoryId)
        .toList();
  }

  Widget _buildActiveFilterChip(List<ShopCategory> categories) {
    String categoryName = 'Filtered';
    for (final category in categories) {
      if (category.id == _selectedFilterCategoryId) {
        categoryName = category.name;
        break;
      }
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.filter_alt_rounded,
              size: 16,
              color: Colors.deepPurple,
            ),
            const SizedBox(width: 6),
            Text(
              categoryName,
              style: const TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _selectedFilterCategoryId = null),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleShopMenuAction(
    _ShopMenuAction action,
    List<ShopCategory> categories,
  ) {
    switch (action) {
      case _ShopMenuAction.viewOrders:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _ShopOrdersScreen()),
        );
        break;
      case _ShopMenuAction.trackOrders:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _ShopTrackOrdersScreen()),
        );
        break;
      case _ShopMenuAction.payments:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _ShopPaymentsScreen()),
        );
        break;
      case _ShopMenuAction.filterProducts:
        _showFilterProductsSheet(categories);
        break;
      case _ShopMenuAction.helpSupport:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _ShopHelpSupportScreen()),
        );
        break;
    }
  }

  Future<void> _showFilterProductsSheet(List<ShopCategory> categories) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter products',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All products'),
                      selected: _selectedFilterCategoryId == null,
                      onSelected: (_) => Navigator.pop(context, ''),
                    ),
                    ...categories.map(
                      (category) => ChoiceChip(
                        label: Text(category.name),
                        selected: _selectedFilterCategoryId == category.id,
                        onSelected: (_) => Navigator.pop(context, category.id),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedFilterCategoryId = selected.isEmpty ? null : selected;
    });
  }

  Widget _buildCategoryBanner(List<ShopCategory> categories) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade500, Colors.purple.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.24),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categories',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Select a category to view products',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_ShopMenuAction>(
                tooltip: 'Shop menu',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onSelected: (action) {
                  _handleShopMenuAction(action, categories);
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<_ShopMenuAction>(
                      value: _ShopMenuAction.viewOrders,
                      child: _ShopMenuItemRow(
                        icon: Icons.receipt_long_rounded,
                        label: 'View orders',
                      ),
                    ),
                    PopupMenuItem<_ShopMenuAction>(
                      value: _ShopMenuAction.trackOrders,
                      child: _ShopMenuItemRow(
                        icon: Icons.local_shipping_rounded,
                        label: 'Track my orders',
                      ),
                    ),
                    PopupMenuItem<_ShopMenuAction>(
                      value: _ShopMenuAction.payments,
                      child: _ShopMenuItemRow(
                        icon: Icons.payments_rounded,
                        label: 'Payments',
                      ),
                    ),
                    PopupMenuItem<_ShopMenuAction>(
                      value: _ShopMenuAction.filterProducts,
                      child: _ShopMenuItemRow(
                        icon: Icons.filter_alt_rounded,
                        label: 'Filter products',
                      ),
                    ),
                    PopupMenuItem<_ShopMenuAction>(
                      value: _ShopMenuAction.helpSupport,
                      child: _ShopMenuItemRow(
                        icon: Icons.support_agent_rounded,
                        label: 'Help and Support',
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ShopMenuAction {
  viewOrders,
  trackOrders,
  payments,
  filterProducts,
  helpSupport,
}

class _ShopSearchResult {
  final ShopCategory category;
  final ShopItem item;

  const _ShopSearchResult({
    required this.category,
    required this.item,
  });
}

class _ShopMenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ShopMenuItemRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.deepPurple),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _ShopHelpSupportScreen extends StatelessWidget {
  const _ShopHelpSupportScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help and Support'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _helpTile(
            icon: Icons.shopping_bag_rounded,
            title: 'Order support',
            subtitle:
                'If your order details are missing, open "View orders" from menu and refresh.',
          ),
          _helpTile(
            icon: Icons.local_shipping_rounded,
            title: 'Tracking support',
            subtitle:
                'Use "Track my orders" to check latest order status and delivery timeline.',
          ),
          _helpTile(
            icon: Icons.payments_rounded,
            title: 'Payment support',
            subtitle:
                'For payment issues, open "Payments" and verify pending or completed transactions.',
          ),
          _helpTile(
            icon: Icons.support_agent_rounded,
            title: 'Need more help?',
            subtitle:
                'Contact admin/service provider from your request details for faster assistance.',
          ),
        ],
      ),
    );
  }

  Widget _helpTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.35,
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

class _ShopOrdersScreen extends StatelessWidget {
  const _ShopOrdersScreen();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('View Orders'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(
          child: Text('Please sign in to view your orders.'),
        ),
      );
    }

    final globalStream = FirebaseFirestore.instance
        .collection('shopOrders')
        .where('customerId', isEqualTo: user.uid)
        .snapshots();
    final userScopedStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopOrders')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('View Orders'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: globalStream,
        builder: (context, globalSnapshot) {
          if (globalSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final globalDocs = globalSnapshot.data?.docs ?? [];
          if (globalDocs.isNotEmpty) {
            return _buildOrdersList(globalDocs);
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userScopedStream,
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userDocs = userSnapshot.data?.docs ?? [];
              if (userDocs.isNotEmpty) {
                return _buildOrdersList(userDocs);
              }

              if (globalSnapshot.hasError && userSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load orders right now.'),
                );
              }

              return const Center(
                child: Text(
                  'No purchased products yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final sortedDocs = docs.toList()
      ..sort((a, b) {
        final DateTime aTime = _orderTimeFromData(a.data());
        final DateTime bTime = _orderTimeFromData(b.data());
        return bTime.compareTo(aTime);
      });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: sortedDocs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = sortedDocs[index];
        final data = doc.data();
        final String orderId = doc.id;
        final String itemName = (data['itemName'] as String?) ?? 'Product';
        final String categoryName =
            ((data['categoryName'] ?? data['category']) as String?) ?? 'Category';
        final int quantity = _asInt(data['quantity'], fallback: 1);
        final int unitPrice = _asInt(data['unitPrice']);
        final int totalAmount = _asInt(data['totalAmount']);
        final String deliveryStatus = (data['deliveryStatus'] as String?) ?? '';
        final String status = deliveryStatus.trim().isNotEmpty
            ? deliveryStatus
            : ((data['orderStatus'] as String?) ?? 'paid');
        final String paymentId = (data['paymentId'] as String?) ?? '';
        final String paymentMethod =
            (data['paymentMethod'] as String?) ?? 'razorpay';
        final String currency = (data['currency'] as String?) ?? 'INR';
        final String imageUrl =
            ((data['itemImageUrl'] ?? data['imageUrl']) as String?) ?? '';
        final DateTime orderedAt = _orderTimeFromData(data);
        final Color statusColor = _statusColor(status);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl.isEmpty
                    ? Container(
                        width: 60,
                        height: 60,
                        color: Colors.deepPurple.withOpacity(0.1),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.deepPurple,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.deepPurple.withOpacity(0.1),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      categoryName,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order ID: $orderId',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Qty: $quantity  |  Unit: Rs $unitPrice',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Amount: $currency $totalAmount',
                      style: const TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ordered: ${_formatDateTime(orderedAt)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paymentId.isEmpty
                          ? 'Payment ID: -'
                          : 'Payment ID: $paymentId',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Method: ${paymentMethod.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _openOrderDetails(
                          context,
                          orderId,
                          Map<String, dynamic>.from(data),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: BorderSide(color: Colors.deepPurple.shade200),
                        ),
                        child: const Text(
                          'Complete Details',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openOrderDetails(
    BuildContext context,
    String orderId,
    Map<String, dynamic> orderData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ShopOrderDetailsScreen(orderId: orderId, orderData: orderData),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'paid' || s == 'delivered') return Colors.green;
    if (s == 'pending' || s == 'processing') return Colors.orange;
    if (s == 'failed' || s == 'cancelled') return Colors.red;
    return Colors.blueGrey;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'order_placed':
        return 'Order Placed';
      case 'payment_confirmed':
        return 'Payment Confirmed';
      case 'out_for_delivery':
        return 'Out for Delivery';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  DateTime _orderTimeFromData(Map<String, dynamic> data) {
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    if (ts != null) return ts.toDate();
    final int? localMs = _asNullableInt(data['createdAtLocalMs']);
    if (localMs != null) {
      return DateTime.fromMillisecondsSinceEpoch(localMs);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _ShopTrackOrdersScreen extends StatelessWidget {
  const _ShopTrackOrdersScreen();

  static const List<Map<String, String>> _steps = [
    {'key': 'order_placed', 'label': 'Order Placed'},
    {'key': 'payment_confirmed', 'label': 'Payment Confirmed'},
    {'key': 'processing', 'label': 'Processing'},
    {'key': 'packed', 'label': 'Packed'},
    {'key': 'shipped', 'label': 'Shipped'},
    {'key': 'out_for_delivery', 'label': 'Out for Delivery'},
    {'key': 'delivered', 'label': 'Delivered'},
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Track My Orders'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(
          child: Text('Please sign in to track your orders.'),
        ),
      );
    }

    final globalStream = FirebaseFirestore.instance
        .collection('shopOrders')
        .where('customerId', isEqualTo: user.uid)
        .snapshots();
    final userScopedStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopOrders')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Track My Orders'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: globalStream,
        builder: (context, globalSnapshot) {
          if (globalSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final globalDocs = globalSnapshot.data?.docs ?? [];
          if (globalDocs.isNotEmpty) {
            return _buildTrackList(context, globalDocs);
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userScopedStream,
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userDocs = userSnapshot.data?.docs ?? [];
              if (userDocs.isNotEmpty) {
                return _buildTrackList(context, userDocs);
              }

              if (globalSnapshot.hasError && userSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load tracking right now.'),
                );
              }

              return const Center(
                child: Text(
                  'No orders available for tracking.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTrackList(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sortedDocs = docs.toList()
      ..sort((a, b) {
        final DateTime aTime = _orderTimeFromData(a.data());
        final DateTime bTime = _orderTimeFromData(b.data());
        return bTime.compareTo(aTime);
      });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      itemCount: sortedDocs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = sortedDocs[index];
        final data = doc.data();
        final String itemName = (data['itemName'] as String?) ?? 'Product';
        final String imageUrl =
            ((data['itemImageUrl'] ?? data['imageUrl']) as String?) ?? '';
        final String status = _normalizeStatus(data);
        final int currentStep = _stepIndex(status);
        final double progress = (_steps.length - 1) == 0
            ? 0
            : currentStep / (_steps.length - 1);
        final String label = _statusLabel(status);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl.isEmpty
                        ? Container(
                            width: 56,
                            height: 56,
                            color: Colors.deepPurple.withOpacity(0.1),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.deepPurple,
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Colors.deepPurple.withOpacity(0.1),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current: $label',
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ShopTrackTimelineScreen(
                          orderId: doc.id,
                          orderData: Map<String, dynamic>.from(data),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.timeline_rounded),
                  label: const Text(
                    'View Timeline',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _normalizeStatus(Map<String, dynamic> data) {
    final String? delivery = (data['deliveryStatus'] as String?)?.trim();
    if (delivery != null && delivery.isNotEmpty) return delivery;
    final String legacy = (data['orderStatus'] as String?)?.toLowerCase() ?? '';
    if (legacy == 'delivered') return 'delivered';
    return 'payment_confirmed';
  }

  int _stepIndex(String status) {
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i]['key'] == status) return i;
    }
    return 0;
  }

  String _statusLabel(String status) {
    for (final step in _steps) {
      if (step['key'] == status) return step['label'] ?? status;
    }
    return status;
  }

  Color _statusColor(String status) {
    if (status == 'delivered') return Colors.green;
    if (status == 'out_for_delivery') return Colors.orange;
    if (status == 'shipped' || status == 'packed' || status == 'processing') {
      return Colors.deepPurple;
    }
    return Colors.blueGrey;
  }

  DateTime _orderTimeFromData(Map<String, dynamic> data) {
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    if (ts != null) return ts.toDate();
    final int? localMs = _asNullableInt(data['createdAtLocalMs']);
    if (localMs != null) {
      return DateTime.fromMillisecondsSinceEpoch(localMs);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _ShopTrackTimelineScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const _ShopTrackTimelineScreen({
    required this.orderId,
    required this.orderData,
  });

  static const List<Map<String, String>> _steps = [
    {'key': 'order_placed', 'label': 'Order Placed'},
    {'key': 'payment_confirmed', 'label': 'Payment Confirmed'},
    {'key': 'processing', 'label': 'Processing'},
    {'key': 'packed', 'label': 'Packed'},
    {'key': 'shipped', 'label': 'Shipped'},
    {'key': 'out_for_delivery', 'label': 'Out for Delivery'},
    {'key': 'delivered', 'label': 'Delivered'},
  ];

  @override
  Widget build(BuildContext context) {
    final String status = _normalizeStatus(orderData);
    final int currentIndex = _stepIndex(status);
    final Map<String, int> timeByStatus = _timelineTimeMap(orderData);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Order Timeline'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _steps.length,
        itemBuilder: (context, index) {
          final step = _steps[index];
          final String key = step['key']!;
          final String label = step['label']!;
          final bool reached = index <= currentIndex;
          final bool isCurrent = index == currentIndex;
          final int? atMs = timeByStatus[key];
          final String timeText = atMs == null
              ? 'Pending'
              : _formatDateTime(DateTime.fromMillisecondsSinceEpoch(atMs));

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached ? Colors.deepPurple : Colors.grey.shade300,
                    ),
                    child: Icon(
                      reached ? Icons.check : Icons.circle,
                      size: reached ? 14 : 10,
                      color: Colors.white,
                    ),
                  ),
                  if (index != _steps.length - 1)
                    Container(
                      width: 2,
                      height: 44,
                      color:
                          reached ? Colors.deepPurple.withOpacity(0.45) : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? Colors.deepPurple.withOpacity(0.5)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: reached ? Colors.black87 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        timeText,
                        style: TextStyle(
                          color: reached ? Colors.grey[700] : Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _normalizeStatus(Map<String, dynamic> data) {
    final String? delivery = (data['deliveryStatus'] as String?)?.trim();
    if (delivery != null && delivery.isNotEmpty) return delivery;
    final String legacy = (data['orderStatus'] as String?)?.toLowerCase() ?? '';
    if (legacy == 'delivered') return 'delivered';
    return 'payment_confirmed';
  }

  int _stepIndex(String status) {
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i]['key'] == status) return i;
    }
    return 0;
  }

  Map<String, int> _timelineTimeMap(Map<String, dynamic> data) {
    final Map<String, int> map = {};
    final timeline = data['statusTimeline'];
    if (timeline is List) {
      for (final entry in timeline) {
        if (entry is Map) {
          final String? key = entry['status'] as String?;
          final int? at = _asNullableInt(entry['atMs']);
          if (key != null && at != null) {
            map[key] = at;
          }
        }
      }
    }
    final int? created = _asNullableInt(data['createdAtLocalMs']);
    if (created != null && !map.containsKey('order_placed')) {
      map['order_placed'] = created;
    }
    if (created != null && !map.containsKey('payment_confirmed')) {
      map['payment_confirmed'] = created;
    }
    return map;
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _ShopOrderDetailsScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const _ShopOrderDetailsScreen({
    required this.orderId,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    final String itemName = (orderData['itemName'] as String?) ?? 'Product';
    final String itemId = (orderData['itemId'] as String?) ?? '-';
    final String categoryId = (orderData['categoryId'] as String?) ?? '-';
    final String categoryName =
        ((orderData['categoryName'] ?? orderData['category']) as String?) ??
            'Category';
    final String imageUrl =
        ((orderData['itemImageUrl'] ?? orderData['imageUrl']) as String?) ?? '';
    final String deliveryStatus = (orderData['deliveryStatus'] as String?) ?? '';
    final String status = deliveryStatus.trim().isNotEmpty
        ? deliveryStatus
        : ((orderData['orderStatus'] as String?) ?? 'paid');
    final String paymentId = (orderData['paymentId'] as String?) ?? '-';
    final String paymentMethod =
        (orderData['paymentMethod'] as String?) ?? 'razorpay';
    final String currency = (orderData['currency'] as String?) ?? 'INR';
    final int quantity = _asInt(orderData['quantity'], fallback: 1);
    final int unitPrice = _asInt(orderData['unitPrice']);
    final int totalAmount = _asInt(orderData['totalAmount']);
    final String customerId = (orderData['customerId'] as String?) ?? '-';
    final String customerEmail = (orderData['customerEmail'] as String?) ?? '-';
    final String createdBy = (orderData['createdBy'] as String?) ?? '-';
    final DateTime orderedAt = _orderTimeFromData(orderData);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl.isEmpty
                      ? Container(
                          width: 64,
                          height: 64,
                          color: Colors.deepPurple.withOpacity(0.1),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.deepPurple,
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            color: Colors.deepPurple.withOpacity(0.1),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        categoryName,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                          status.toUpperCase(),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Order Information',
            children: [
              _detailRow('Order ID', orderId),
              _detailRow('Ordered At', _formatDateTime(orderedAt)),
              _detailRow('Created By', createdBy),
            ],
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Product Information',
            children: [
              _detailRow('Item ID', itemId),
              _detailRow('Item Name', itemName),
              _detailRow('Category ID', categoryId),
              _detailRow('Category Name', categoryName),
              _detailRow('Quantity', '$quantity'),
            ],
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Pricing Information',
            children: [
              _detailRow('Currency', currency),
              _detailRow('Unit Price', '$currency $unitPrice'),
              _detailRow('Total Amount', '$currency $totalAmount'),
            ],
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Payment Information',
            children: [
              _detailRow('Payment ID', paymentId.isEmpty ? '-' : paymentId),
              _detailRow('Payment Method', paymentMethod.toUpperCase()),
              _detailRow('Order Status', status.toUpperCase()),
            ],
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Customer Information',
            children: [
              _detailRow('Customer ID', customerId),
              _detailRow('Customer Email', customerEmail),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  DateTime _orderTimeFromData(Map<String, dynamic> data) {
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    if (ts != null) return ts.toDate();
    final int? localMs = _asNullableInt(data['createdAtLocalMs']);
    if (localMs != null) {
      return DateTime.fromMillisecondsSinceEpoch(localMs);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'paid' || s == 'delivered') return Colors.green;
    if (s == 'pending' || s == 'processing') return Colors.orange;
    if (s == 'failed' || s == 'cancelled') return Colors.red;
    return Colors.blueGrey;
  }
}

class _ShopPaymentsScreen extends StatelessWidget {
  const _ShopPaymentsScreen();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Shop Payments'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(
          child: Text('Please sign in to view payment history.'),
        ),
      );
    }

    final globalStream = FirebaseFirestore.instance
        .collection('shopOrders')
        .where('customerId', isEqualTo: user.uid)
        .snapshots();
    final userScopedStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopOrders')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Shop Payments'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: globalStream,
        builder: (context, globalSnapshot) {
          if (globalSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final globalDocs = globalSnapshot.data?.docs ?? [];
          if (globalDocs.isNotEmpty) {
            return _buildPaymentList(globalDocs);
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userScopedStream,
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userDocs = userSnapshot.data?.docs ?? [];
              if (userDocs.isNotEmpty) {
                return _buildPaymentList(userDocs);
              }

              if (globalSnapshot.hasError && userSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load payment history right now.'),
                );
              }

              return const Center(
                child: Text(
                  'No shop payments yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPaymentList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sortedDocs = docs.toList()
      ..sort((a, b) {
        final DateTime aTime = _orderTimeFromData(a.data());
        final DateTime bTime = _orderTimeFromData(b.data());
        return bTime.compareTo(aTime);
      });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: sortedDocs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final data = sortedDocs[index].data();
        final String itemName = (data['itemName'] as String?) ?? 'Product';
        final int totalAmount = _asInt(data['totalAmount']);
        final int quantity = _asInt(data['quantity'], fallback: 1);
        final String paymentId = (data['paymentId'] as String?) ?? '';
        final String method = (data['paymentMethod'] as String?) ?? 'razorpay';
        final DateTime paidAt = _orderTimeFromData(data);
        final String dateText =
            '${paidAt.day.toString().padLeft(2, '0')}-${paidAt.month.toString().padLeft(2, '0')}-${paidAt.year}';
        final String timeText =
            '${paidAt.hour.toString().padLeft(2, '0')}:${paidAt.minute.toString().padLeft(2, '0')}';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_rounded, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'PAID',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Amount: Rs $totalAmount',
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Quantity: $quantity',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Method: ${method.toUpperCase()}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                paymentId.isEmpty ? 'Payment ID: -' : 'Payment ID: $paymentId',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Paid on: $dateText $timeText',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime _orderTimeFromData(Map<String, dynamic> data) {
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    if (ts != null) return ts.toDate();
    final int? localMs = _asNullableInt(data['createdAtLocalMs']);
    if (localMs != null) {
      return DateTime.fromMillisecondsSinceEpoch(localMs);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _CategoryQuickCard extends StatelessWidget {
  final ShopCategory category;
  final VoidCallback onTap;

  const _CategoryQuickCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: category.accentColor.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon, color: category.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${category.items.length} items',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryItemsScreen extends StatelessWidget {
  final String categoryId;

  const _CategoryItemsScreen({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Category Items'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ValueListenableBuilder<List<ShopCategory>>(
        valueListenable: ShopCatalogStore.instance.categoriesNotifier,
        builder: (context, categories, _) {
          ShopCategory? category;
          for (final c in categories) {
            if (c.id == categoryId) {
              category = c;
              break;
            }
          }

          if (category == null) {
            return const Center(
              child: Text(
                'This category is no longer available.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          final ShopCategory activeCategory = category;

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(activeCategory.icon, color: activeCategory.accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activeCategory.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      '${activeCategory.items.length} items',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: activeCategory.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = activeCategory.items[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.effectiveImageUrl,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 54,
                                height: 54,
                                color: activeCategory.accentColor.withOpacity(0.12),
                                child: Icon(
                                  activeCategory.icon,
                                  color: activeCategory.accentColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Price: Rs ${item.price}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _ItemDetailsScreen(
                                    category: activeCategory,
                                    item: item,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('View Details'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ItemDetailsScreen extends StatefulWidget {
  final ShopCategory category;
  final ShopItem item;

  const _ItemDetailsScreen({
    required this.category,
    required this.item,
  });

  @override
  State<_ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<_ItemDetailsScreen> {
  static const String _razorpayKey = 'rzp_test_RWRMUwaEf4eLLC';

  late final Razorpay _razorpay;
  int _quantity = 1;

  int get _totalPrice => _quantity * widget.item.price;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _increment() {
    setState(() => _quantity++);
  }

  void _decrement() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
  }

  void _buyNow() {
    final user = FirebaseAuth.instance.currentUser;
    final options = {
      'key': _razorpayKey,
      'amount': _totalPrice * 100,
      'currency': 'INR',
      'name': widget.item.name,
      'description': 'Shop purchase (${widget.category.name})',
      'notes': {
        'itemId': widget.item.id,
        'itemName': widget.item.name,
        'category': widget.category.name,
        'quantity': _quantity,
        'unitPrice': widget.item.price,
      },
      'prefill': {
        'email': user?.email ?? '',
        'contact': user?.phoneNumber ?? '',
        'name': 'Customer',
      },
      'theme': {
        'color': '#673AB7',
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start Razorpay: $e')),
      );
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final bool orderSaved = await _saveShopOrder(response);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          orderSaved
              ? 'Payment successful for ${widget.item.name}.'
              : 'Payment successful, but order sync is delayed. Refresh View Orders shortly.',
        ),
        backgroundColor: Colors.green,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const _ShopPaymentsScreen()),
    );
  }

  Future<bool> _saveShopOrder(PaymentSuccessResponse response) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String shortUid =
        user.uid.length >= 6 ? user.uid.substring(0, 6) : user.uid;
    final String orderCode = 'SO-$nowMs-$shortUid';
    final globalRef = FirebaseFirestore.instance.collection('shopOrders').doc();
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopOrders')
        .doc(globalRef.id);

    final Map<String, dynamic> orderData = {
      'orderId': globalRef.id,
      'orderCode': orderCode,
      'customerId': user.uid,
      'userId': user.uid,
      'createdBy': user.uid,
      'customerEmail': user.email ?? '',
      'itemId': widget.item.id,
      'itemName': widget.item.name,
      'itemImageUrl': widget.item.effectiveImageUrl,
      'categoryId': widget.category.id,
      'categoryName': widget.category.name,
      'category': widget.category.name,
      'quantity': _quantity,
      'unitPrice': widget.item.price,
      'totalAmount': _totalPrice,
      'currency': 'INR',
      'paymentId': response.paymentId ?? '',
      'orderStatus': 'paid',
      'deliveryStatus': 'payment_confirmed',
      'paymentMethod': 'razorpay',
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtLocalMs': nowMs,
      'lastStatusUpdateMs': nowMs,
      'statusTimeline': [
        {
          'status': 'order_placed',
          'label': 'Order Placed',
          'atMs': nowMs,
          'by': 'customer',
        },
        {
          'status': 'payment_confirmed',
          'label': 'Payment Confirmed',
          'atMs': nowMs,
          'by': 'system',
        },
      ],
    };

    bool wroteAtLeastOne = false;

    try {
      await globalRef.set(orderData);
      wroteAtLeastOne = true;
    } catch (_) {}

    try {
      await userRef.set(orderData);
      wroteAtLeastOne = true;
    } catch (_) {}

    return wroteAtLeastOne;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment failed: ${response.message ?? 'Unknown error'}',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName ?? ''}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.item.effectiveImageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: widget.category.accentColor.withOpacity(0.15),
                        child: Icon(
                          widget.category.icon,
                          color: widget.category.accentColor,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.category.name,
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
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reliable ${widget.item.name.toLowerCase()} for repair and maintenance work.',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Price: Rs ${widget.item.price}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.deepPurple,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Text(
                    'Quantity',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _decrement,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          onPressed: _increment,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Total Amount: Rs $_totalPrice',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _buyNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'Buy',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
