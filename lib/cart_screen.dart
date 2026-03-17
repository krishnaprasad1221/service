import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
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
        actions: const [
          _ShopNotificationsBell(),
        ],
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

          final List<ShopCategory> filteredCategories = _getFilteredCategories(
            categories,
          );
          final List<_ShopSearchResult> searchResults = _buildSearchResults(
            filteredCategories,
          );
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
                          builder: (_) =>
                              _CategoryItemsScreen(categoryId: category.id),
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
                              color: result.category.accentColor.withOpacity(
                                0.12,
                              ),
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
                                'Brand: ${result.item.displayBrand}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
      case _ShopMenuAction.notifications:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _ShopNotificationsScreen()),
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
                      value: _ShopMenuAction.notifications,
                      child: _ShopMenuItemRow(
                        icon: Icons.notifications_active_rounded,
                        label: 'Notifications',
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
  notifications,
  filterProducts,
  helpSupport,
}

class _ShopSearchResult {
  final ShopCategory category;
  final ShopItem item;

  const _ShopSearchResult({required this.category, required this.item});
}

class _ShopMenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ShopMenuItemRow({required this.icon, required this.label});

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
                  style: TextStyle(color: Colors.grey[700], height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopNotificationsBell extends StatelessWidget {
  const _ShopNotificationsBell();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .limit(200)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        int unreadShop = 0;
        for (final d in docs) {
          final type = (d.data()['type'] as String?) ?? '';
          if (type == 'shop_order_stage' || type.startsWith('shop_')) {
            unreadShop++;
          }
        }

        return IconButton(
          tooltip: 'Shop notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _ShopNotificationsScreen()),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_rounded, color: Colors.white),
              if (unreadShop > 0)
                Positioned(
                  right: -2,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadShop > 99 ? '99+' : unreadShop.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ShopNotificationsScreen extends StatelessWidget {
  const _ShopNotificationsScreen();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Shop Notifications'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(child: Text('Please sign in to view notifications.')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Shop Notifications'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load notifications.'));
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs =
              snapshot.data?.docs ?? const [];
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = allDocs
              .where((d) {
                final type = (d.data()['type'] as String?) ?? '';
                return type == 'shop_order_stage' || type.startsWith('shop_');
              })
              .toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No shop notifications yet.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final String title =
                  (data['title'] as String?)?.trim().isNotEmpty == true
                  ? (data['title'] as String).trim()
                  : 'Shop order update';
              final String body = (data['body'] as String?) ?? '';
              final bool isRead = (data['isRead'] as bool?) ?? false;
              final String status = (data['status'] as String?) ?? '';
              final String time = _timestampText(data['createdAt']);

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  if (!isRead) {
                    try {
                      await doc.reference.update({'isRead': true});
                    } catch (_) {}
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRead
                          ? Colors.grey.shade200
                          : Colors.deepPurple.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _statusIcon(status),
                          color: _statusColor(status),
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.deepPurple,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            if (body.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (time.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 13,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'order_placed':
        return Icons.receipt_long_rounded;
      case 'payment_confirmed':
        return Icons.payment_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'processing':
        return Icons.settings_suggest_rounded;
      case 'packed':
        return Icons.inventory_2_rounded;
      case 'shipped':
        return Icons.local_shipping_rounded;
      case 'out_for_delivery':
        return Icons.delivery_dining_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _statusColor(String status) {
    if (status == 'cancelled') return Colors.red;
    if (status == 'delivered') return Colors.green;
    if (status == 'out_for_delivery') return Colors.orange;
    if (status == 'shipped' || status == 'packed' || status == 'processing') {
      return Colors.deepPurple;
    }
    if (status == 'payment_confirmed') return Colors.teal;
    return Colors.blueGrey;
  }

  String _timestampText(dynamic ts) {
    if (ts is! Timestamp) return '';
    final DateTime dt = ts.toDate();
    return '${dt.day.toString().padLeft(2, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergeShopOrderDocs({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> globalDocs,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
}) {
  if (globalDocs.isEmpty) return userDocs;
  if (userDocs.isEmpty) return globalDocs;

  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged =
      <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  for (final doc in userDocs) {
    merged[doc.id] = doc;
  }
  for (final doc in globalDocs) {
    // Global order docs are treated as authoritative for delivery/return state.
    merged[doc.id] = doc;
  }
  return merged.values.toList(growable: false);
}

class _ShopOrdersScreen extends StatefulWidget {
  const _ShopOrdersScreen();

  @override
  State<_ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends State<_ShopOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _statusFilter = 'all';
  String _dateFilter = 'all';
  String _priceFilter = 'all';

  static const List<Map<String, String>> _statusOptions = [
    {'value': 'all', 'label': 'All Status'},
    {'value': 'order_placed', 'label': 'Order Placed'},
    {'value': 'payment_confirmed', 'label': 'Payment Confirmed'},
    {'value': 'processing', 'label': 'Processing'},
    {'value': 'packed', 'label': 'Packed'},
    {'value': 'shipped', 'label': 'Shipped'},
    {'value': 'out_for_delivery', 'label': 'Out for Delivery'},
    {'value': 'delivered', 'label': 'Delivered'},
    {'value': 'cancelled', 'label': 'Cancelled'},
  ];

  static const List<Map<String, String>> _dateOptions = [
    {'value': 'all', 'label': 'All Dates'},
    {'value': 'today', 'label': 'Today'},
    {'value': 'last_7_days', 'label': 'Last 7 Days'},
    {'value': 'last_30_days', 'label': 'Last 30 Days'},
    {'value': 'this_year', 'label': 'This Year'},
  ];

  static const List<Map<String, String>> _priceOptions = [
    {'value': 'all', 'label': 'All Prices'},
    {'value': 'under_500', 'label': 'Under Rs 500'},
    {'value': '500_2000', 'label': 'Rs 500 - Rs 2,000'},
    {'value': '2000_5000', 'label': 'Rs 2,000 - Rs 5,000'},
    {'value': 'above_5000', 'label': 'Above Rs 5,000'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('View Orders'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(child: Text('Please sign in to view your orders.')),
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
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userScopedStream,
            builder: (context, userSnapshot) {
              final globalDocs = globalSnapshot.data?.docs ?? [];
              final userDocs = userSnapshot.data?.docs ?? [];
              final mergedDocs = _mergeShopOrderDocs(
                globalDocs: globalDocs,
                userDocs: userDocs,
              );

              if (mergedDocs.isNotEmpty) {
                return _buildOrdersList(mergedDocs);
              }

              if (globalSnapshot.connectionState == ConnectionState.waiting ||
                  userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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

  Widget _buildOrdersList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final filteredDocs = _applyFilters(docs);
    final int itemCount = filteredDocs.isEmpty ? 2 : filteredDocs.length + 1;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSearchAndFilterCard(
            totalCount: docs.length,
            filteredCount: filteredDocs.length,
          );
        }

        if (filteredDocs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'No orders match your search/filters.',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          );
        }

        return _buildOrderCard(context, filteredDocs[index - 1]);
      },
    );
  }

  Widget _buildSearchAndFilterCard({
    required int totalCount,
    required int filteredCount,
  }) {
    final bool hasActiveFilters =
        _searchQuery.trim().isNotEmpty ||
        _statusFilter != 'all' ||
        _dateFilter != 'all' ||
        _priceFilter != 'all';

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
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by item, order ID, category, payment ID...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.trim().isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterDropdown(
                label: 'Status',
                value: _statusFilter,
                options: _statusOptions,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _statusFilter = value);
                },
              ),
              _buildFilterDropdown(
                label: 'Date',
                value: _dateFilter,
                options: _dateOptions,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _dateFilter = value);
                },
              ),
              _buildFilterDropdown(
                label: 'Price',
                value: _priceFilter,
                options: _priceOptions,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _priceFilter = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$filteredCount of $totalCount orders',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _statusFilter = 'all';
                      _dateFilter = 'all';
                      _priceFilter = 'all';
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> options,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        items: options
            .map(
              (opt) => DropdownMenuItem<String>(
                value: opt['value']!,
                child: Text(opt['label']!),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sortedDocs =
        docs.toList()
          ..sort((a, b) {
            final DateTime aTime = _orderTimeFromData(a.data());
            final DateTime bTime = _orderTimeFromData(b.data());
            return bTime.compareTo(aTime);
          });

    final String q = _searchQuery.trim().toLowerCase();

    return sortedDocs.where((doc) {
      final data = doc.data();
      final String orderId = doc.id.toLowerCase();
      final String itemName =
          ((data['itemName'] as String?) ?? 'product').toLowerCase();
      final String categoryName =
          (((data['categoryName'] ?? data['category']) as String?) ?? 'category')
              .toLowerCase();
      final String paymentId = ((data['paymentId'] as String?) ?? '').toLowerCase();
      final String paymentMethod =
          ((data['paymentMethod'] as String?) ?? '').toLowerCase();
      final String status = _normalizeOrderStatus(data);
      final int totalAmount = _asInt(data['totalAmount']);
      final DateTime orderedAt = _orderTimeFromData(data);

      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }
      if (!_matchesDateFilter(orderedAt)) {
        return false;
      }
      if (!_matchesPriceFilter(totalAmount)) {
        return false;
      }

      if (q.isNotEmpty) {
        final String searchable = [
          orderId,
          itemName,
          categoryName,
          paymentId,
          paymentMethod,
          status,
          _statusLabel(status).toLowerCase(),
        ].join(' ');
        if (!searchable.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  bool _matchesDateFilter(DateTime orderedAt) {
    final DateTime now = DateTime.now();
    switch (_dateFilter) {
      case 'today':
        return orderedAt.year == now.year &&
            orderedAt.month == now.month &&
            orderedAt.day == now.day;
      case 'last_7_days':
        return !orderedAt.isBefore(now.subtract(const Duration(days: 7)));
      case 'last_30_days':
        return !orderedAt.isBefore(now.subtract(const Duration(days: 30)));
      case 'this_year':
        return orderedAt.year == now.year;
      default:
        return true;
    }
  }

  bool _matchesPriceFilter(int totalAmount) {
    switch (_priceFilter) {
      case 'under_500':
        return totalAmount < 500;
      case '500_2000':
        return totalAmount >= 500 && totalAmount <= 2000;
      case '2000_5000':
        return totalAmount > 2000 && totalAmount <= 5000;
      case 'above_5000':
        return totalAmount > 5000;
      default:
        return true;
    }
  }

  Widget _buildOrderCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final String orderId = doc.id;
    final String itemName = (data['itemName'] as String?) ?? 'Product';
    final String categoryName =
        ((data['categoryName'] ?? data['category']) as String?) ?? 'Category';
    final int quantity = _asInt(data['quantity'], fallback: 1);
    final int unitPrice = _asInt(data['unitPrice']);
    final int totalAmount = _asInt(data['totalAmount']);
    final String status = _normalizeOrderStatus(data);
    final String paymentId = (data['paymentId'] as String?) ?? '';
    final String paymentMethod = (data['paymentMethod'] as String?) ?? 'razorpay';
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
                  paymentId.isEmpty ? 'Payment ID: -' : 'Payment ID: $paymentId',
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
  }

  String _normalizeOrderStatus(Map<String, dynamic> data) {
    final String? delivery = (data['deliveryStatus'] as String?)?.trim();
    if (delivery != null && delivery.isNotEmpty) {
      return delivery.toLowerCase();
    }
    final String legacy = (data['orderStatus'] as String?)?.toLowerCase() ?? '';
    if (legacy == 'cancelled' || legacy == 'canceled') return 'cancelled';
    if (legacy == 'order_placed' || legacy == 'pending' || legacy == 'cod_pending') {
      return 'order_placed';
    }
    if (legacy == 'paid' || legacy == 'payment_confirmed') {
      return 'payment_confirmed';
    }
    if (legacy == 'processing' ||
        legacy == 'packed' ||
        legacy == 'shipped' ||
        legacy == 'out_for_delivery' ||
        legacy == 'delivered') {
      return legacy;
    }
    return 'payment_confirmed';
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
    if (s == 'delivered') return Colors.green;
    if (s == 'cancelled' || s == 'failed') return Colors.red;
    if (s == 'out_for_delivery') return Colors.orange;
    if (s == 'processing' || s == 'packed' || s == 'shipped') {
      return Colors.deepPurple;
    }
    if (s == 'payment_confirmed') return Colors.teal;
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
      case 'cancelled':
        return 'Cancelled';
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
        body: const Center(child: Text('Please sign in to track your orders.')),
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
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userScopedStream,
            builder: (context, userSnapshot) {
              final globalDocs = globalSnapshot.data?.docs ?? [];
              final userDocs = userSnapshot.data?.docs ?? [];
              final mergedDocs = _mergeShopOrderDocs(
                globalDocs: globalDocs,
                userDocs: userDocs,
              );

              if (mergedDocs.isNotEmpty) {
                return _buildTrackList(context, mergedDocs);
              }

              if (globalSnapshot.connectionState == ConnectionState.waiting ||
                  userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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
        final bool isCancelled = status == 'cancelled';
        final double progress = isCancelled || (_steps.length - 1) == 0
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
    if (delivery != null && delivery.isNotEmpty) {
      return delivery.toLowerCase();
    }
    final String legacy = (data['orderStatus'] as String?)?.toLowerCase() ?? '';
    if (legacy == 'cancelled' || legacy == 'canceled') return 'cancelled';
    if (legacy == 'order_placed' || legacy == 'pending' || legacy == 'cod_pending') {
      return 'order_placed';
    }
    if (legacy == 'paid' || legacy == 'payment_confirmed') {
      return 'payment_confirmed';
    }
    if (legacy == 'processing' ||
        legacy == 'packed' ||
        legacy == 'shipped' ||
        legacy == 'out_for_delivery' ||
        legacy == 'delivered') {
      return legacy;
    }
    return 'payment_confirmed';
  }

  int _stepIndex(String status) {
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i]['key'] == status) return i;
    }
    return 0;
  }

  String _statusLabel(String status) {
    if (status == 'cancelled') return 'Cancelled';
    for (final step in _steps) {
      if (step['key'] == status) return step['label'] ?? status;
    }
    return status;
  }

  Color _statusColor(String status) {
    if (status == 'cancelled') return Colors.red;
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
                      color: reached
                          ? Colors.deepPurple.withOpacity(0.45)
                          : Colors.grey.shade300,
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
    if (delivery != null && delivery.isNotEmpty) {
      return delivery.toLowerCase();
    }
    final String legacy = (data['orderStatus'] as String?)?.toLowerCase() ?? '';
    if (legacy == 'cancelled' || legacy == 'canceled') return 'cancelled';
    if (legacy == 'order_placed' || legacy == 'pending' || legacy == 'cod_pending') {
      return 'order_placed';
    }
    if (legacy == 'paid' || legacy == 'payment_confirmed') {
      return 'payment_confirmed';
    }
    if (legacy == 'processing' ||
        legacy == 'packed' ||
        legacy == 'shipped' ||
        legacy == 'out_for_delivery' ||
        legacy == 'delivered') {
      return legacy;
    }
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
    final String itemBrand = (orderData['itemBrand'] as String?) ?? '-';
    final String itemModel = (orderData['itemModel'] as String?) ?? '-';
    final String itemModelNumber =
        (orderData['itemModelNumber'] as String?) ?? '-';
    final String itemType = (orderData['itemType'] as String?) ?? '-';
    final String itemShade = (orderData['itemShade'] as String?) ?? '-';
    final String itemMaterial = (orderData['itemMaterial'] as String?) ?? '-';
    final String itemPackOf = (orderData['itemPackOf'] as String?) ?? '-';
    final String itemWarranty = (orderData['itemWarranty'] as String?) ?? '-';
    final String itemSuitableFor =
        (orderData['itemSuitableFor'] as String?) ?? '-';
    final String deliveryLocation =
        (orderData['deliveryLocation'] as String?) ?? '-';
    final String customerDeliveryLocation =
        (orderData['customerDeliveryLocation'] as String?) ?? '-';
    final int deliveryWorkingDays = _asInt(
      orderData['deliveryWorkingDays'],
      fallback: 0,
    );
    final String aboutSeller = (orderData['aboutSeller'] as String?) ?? '-';
    final double overallRating = _asDouble(orderData['overallRating']);
    final double productQuality = _asDouble(orderData['productQuality']);
    final double serviceQuality = _asDouble(orderData['serviceQuality']);
    final String itemHighlights = () {
      final dynamic raw = orderData['itemHighlights'];
      if (raw is List) {
        final List<String> list = raw
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
        if (list.isNotEmpty) return list.join(', ');
      }
      return '-';
    }();
    final String paymentMethod =
        (orderData['paymentMethod'] as String?) ?? 'razorpay';
    final String status = _normalizeOrderStatus(orderData);
    final bool deliveredCompleted = status == 'delivered';
    final Map<String, dynamic>? returnReplacementRequest =
        _extractReturnReplacementRequest(orderData);
    final String rrStatus = ((returnReplacementRequest?['status'] as String?) ?? '')
        .trim()
        .toLowerCase();
    final bool canRequestReturnReplacement = deliveredCompleted &&
        (returnReplacementRequest == null || rrStatus == 'rejected');
    final bool canCancelBeforeProcessing = _canCancelBeforeProcessing(status);
    final bool isCodOrder = paymentMethod.toLowerCase() == 'cod';
    final String cancelInfoText = isCodOrder
        ? 'COD order: no refund is required. You only cancel the order.'
        : 'Paid order: refund will be initiated to your original payment method after cancellation.';
    final String paymentId = (orderData['paymentId'] as String?) ?? '-';
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
              _detailRow('Brand', itemBrand),
              _detailRow('Model', itemModel),
              _detailRow('Model Number', itemModelNumber),
              _detailRow('Type', itemType),
              _detailRow('Shade', itemShade),
              _detailRow('Material', itemMaterial),
              _detailRow('Pack Of', itemPackOf),
              _detailRow('Warranty', itemWarranty),
              _detailRow('Suitable For', itemSuitableFor),
              _detailRow('Quantity', '$quantity'),
              _detailRow('Highlights', itemHighlights),
            ],
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Delivery Details',
            children: [
              _detailRow('Delivery To', customerDeliveryLocation),
              _detailRow('Dispatch From', deliveryLocation),
              _detailRow(
                'Working Days',
                deliveryWorkingDays <= 0
                    ? '-'
                    : 'Within $deliveryWorkingDays working days',
              ),
            ],
          ),
          if (deliveredCompleted) ...[
            const SizedBox(height: 12),
            _buildShopReviewSection(
              context: context,
              orderId: orderId,
              itemId: itemId,
              itemName: itemName,
              customerId: customerId,
            ),
            const SizedBox(height: 12),
            _buildReturnReplacementSection(
              context: context,
              orderId: orderId,
              orderData: orderData,
              itemName: itemName,
              customerId: customerId,
              request: returnReplacementRequest,
              canRequest: canRequestReturnReplacement,
            ),
          ],
          const SizedBox(height: 12),
          _buildSection(
            title: 'Seller Details',
            children: [
              _detailRow('About Seller', aboutSeller),
              _detailRow('Overall Rating', _ratingText(overallRating)),
              _detailRow('Product Quality', _ratingText(productQuality)),
              _detailRow('Service Quality', _ratingText(serviceQuality)),
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
          if (canCancelBeforeProcessing) ...[
            const SizedBox(height: 12),
            _buildSection(
              title: 'Cancel Order',
              children: [
                Text(
                  'Cancellation is allowed only before the order reaches Processing.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cancelInfoText,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _confirmAndCancelOrder(
                        context: context,
                        orderId: orderId,
                        itemName: itemName,
                        paymentMethod: paymentMethod,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text(
                      'Cancel Order',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
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

  String _normalizeOrderStatus(Map<String, dynamic> data) {
    final String? delivery = (data['deliveryStatus'] as String?)?.trim();
    if (delivery != null && delivery.isNotEmpty) {
      return delivery.toLowerCase();
    }

    final String legacy = (data['orderStatus'] as String?)?.toLowerCase() ?? '';
    if (legacy == 'cancelled' || legacy == 'canceled') return 'cancelled';
    if (legacy == 'order_placed' || legacy == 'pending' || legacy == 'cod_pending') {
      return 'order_placed';
    }
    if (legacy == 'paid' || legacy == 'payment_confirmed') {
      return 'payment_confirmed';
    }
    if (legacy == 'processing' ||
        legacy == 'packed' ||
        legacy == 'shipped' ||
        legacy == 'out_for_delivery' ||
        legacy == 'delivered') {
      return legacy;
    }
    return 'payment_confirmed';
  }

  bool _canCancelBeforeProcessing(String status) {
    return status == 'order_placed' || status == 'payment_confirmed';
  }

  Future<void> _confirmAndCancelOrder({
    required BuildContext context,
    required String orderId,
    required String itemName,
    required String paymentMethod,
  }) async {
    final bool isCod = paymentMethod.toLowerCase() == 'cod';
    final String policyText = isCod
        ? 'COD order: no refund is required.'
        : 'Paid order: refund will be initiated to your original payment method.';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You can cancel only before Processing. This action cannot be undone.',
            ),
            const SizedBox(height: 8),
            Text(
              policyText,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    final bool cancelled = await _cancelShopOrder(
      orderId: orderId,
      itemName: itemName,
      paymentMethod: paymentMethod,
    );

    if (!context.mounted) return;

    if (cancelled) {
      final String successMessage = isCod
          ? 'Order cancelled successfully. COD order closed with no charge.'
          : 'Order cancelled successfully. Refund will be processed to your original payment method.';
      messenger?.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to cancel now. Order may already be in Processing or later.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<bool> _cancelShopOrder({
    required String orderId,
    required String itemName,
    required String paymentMethod,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || orderId.trim().isEmpty) return false;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final bool isCod = paymentMethod.toLowerCase() == 'cod';

    final Map<String, dynamic> patch = <String, dynamic>{
      'deliveryStatus': 'cancelled',
      'orderStatus': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledAtLocalMs': nowMs,
      'cancelledBy': user.uid,
      'cancelReason': 'Cancelled by customer before processing',
      'lastStatusUpdateMs': nowMs,
      'refundStatus': isCod ? 'not_applicable' : 'initiated',
      'statusTimeline': FieldValue.arrayUnion([
        <String, dynamic>{
          'status': 'cancelled',
          'label': 'Cancelled',
          'atMs': nowMs,
          'by': 'customer',
        },
      ]),
    };

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopOrders')
        .doc(orderId);
    final globalRef = FirebaseFirestore.instance
        .collection('shopOrders')
        .doc(orderId);

    Map<String, dynamic>? latestData;
    try {
      final userSnap = await userRef.get();
      latestData = userSnap.data();
    } catch (_) {}
    if (latestData == null) {
      try {
        final globalSnap = await globalRef.get();
        latestData = globalSnap.data();
      } catch (_) {}
    }
    if (latestData != null) {
      final String latestStatus = _normalizeOrderStatus(latestData);
      if (!_canCancelBeforeProcessing(latestStatus)) {
        return false;
      }
    }

    bool userUpdated = false;

    try {
      await userRef.set(patch, SetOptions(merge: true));
      userUpdated = true;
    } catch (_) {}

    // Keep global doc in sync when rules allow; user-scoped update is required.
    try {
      await globalRef.set(patch, SetOptions(merge: true));
    } catch (_) {}

    if (userUpdated) {
      await _pushShopCancellationNotification(
        customerId: user.uid,
        orderId: orderId,
        itemName: itemName,
        isCod: isCod,
      );
    }

    return userUpdated;
  }

  Future<void> _pushShopCancellationNotification({
    required String customerId,
    required String orderId,
    required String itemName,
    required bool isCod,
  }) async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || customerId.trim().isEmpty) return;

    final String safeItem = itemName.trim().isEmpty ? 'your item' : itemName.trim();
    final String body = isCod
        ? '$safeItem was cancelled before processing. COD order closed with no charge.'
        : '$safeItem was cancelled before processing. Refund to original payment method is initiated.';

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': customerId,
        'createdBy': uid,
        'type': 'shop_order_stage',
        'title': 'Order cancelled',
        'body': body,
        'status': 'cancelled',
        'relatedId': orderId,
        'orderId': orderId,
        'itemName': safeItem,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Map<String, dynamic>? _extractReturnReplacementRequest(
    Map<String, dynamic> data,
  ) {
    final dynamic raw = data['returnReplacementRequest'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  int _deliveredAtMs(Map<String, dynamic> data) {
    final int explicitDelivered = _asInt(data['deliveredAtLocalMs'], fallback: 0);
    if (explicitDelivered > 0) return explicitDelivered;

    int latest = 0;
    final dynamic timeline = data['statusTimeline'];
    if (timeline is List) {
      for (final dynamic row in timeline) {
        if (row is Map) {
          final String status =
              ((row['status'] as String?) ?? '').trim().toLowerCase();
          if (status == 'delivered') {
            final int atMs = _asInt(row['atMs'], fallback: 0);
            if (atMs > latest) latest = atMs;
          }
        }
      }
    }
    if (latest > 0) return latest;
    if (_normalizeOrderStatus(data) == 'delivered') {
      final int fallbackMs = _asInt(data['lastStatusUpdateMs'], fallback: 0);
      if (fallbackMs > 0) return fallbackMs;
      return _asInt(data['createdAtLocalMs'], fallback: 0);
    }
    return 0;
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  _findGlobalOrderDocByMeta(Map<String, dynamic>? source) async {
    if (source == null) return null;

    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return null;

    final CollectionReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance.collection('shopOrders');
    final String knownOrderId = _asString(source['orderId']).trim();
    final String orderCode = _asString(source['orderCode']).trim();
    final String paymentId = _asString(source['paymentId']).trim();

    if (knownOrderId.isEmpty && orderCode.isEmpty && paymentId.isEmpty) {
      return null;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await ref
          .where('customerId', isEqualTo: uid)
          .limit(80)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        final Map<String, dynamic> d = doc.data();
        final String dOrderId = _asString(d['orderId']).trim();
        final String dOrderCode = _asString(d['orderCode']).trim();
        final String dPaymentId = _asString(d['paymentId']).trim();
        if (knownOrderId.isNotEmpty && dOrderId == knownOrderId) {
          return doc;
        }
        if (orderCode.isNotEmpty && dOrderCode == orderCode) {
          return doc;
        }
        if (paymentId.isNotEmpty && dPaymentId == paymentId) {
          return doc;
        }
      }
    } catch (_) {}

    return null;
  }

  Map<String, dynamic>? _buildGlobalOrderSeedForReturnReplacement({
    required String orderId,
    required String customerId,
    required Map<String, dynamic>? source,
    required Map<String, dynamic> rrPayload,
    required int nowMs,
  }) {
    if (source == null) return null;

    String itemId = _asString(source['itemId']).trim();
    if (itemId.isEmpty) {
      itemId = _asString(source['productId']).trim();
    }
    if (itemId.isEmpty) {
      itemId = orderId;
    }

    String itemName = _asString(source['itemName']).trim();
    if (itemName.isEmpty) {
      itemName = _asString(source['title']).trim();
    }
    if (itemName.isEmpty) {
      itemName = 'Product';
    }

    String categoryName = _asString(
      source['categoryName'] ?? source['category'],
    ).trim();
    if (categoryName.isEmpty) {
      categoryName = 'General';
    }

    final int quantity = _asInt(source['quantity'], fallback: 1);
    final int unitPrice = _asInt(source['unitPrice'], fallback: 0);
    int totalAmount = _asInt(source['totalAmount'], fallback: 0);
    if (totalAmount < 0) totalAmount = 0;
    if (totalAmount == 0) {
      final int safeQty = quantity > 0 ? quantity : 1;
      totalAmount = (unitPrice < 0 ? 0 : unitPrice) * safeQty;
    }

    final int deliveredAtMs = _deliveredAtMs(source);

    int createdAtLocalMs = _asInt(source['createdAtLocalMs'], fallback: 0);
    if (createdAtLocalMs <= 0) {
      createdAtLocalMs = nowMs;
    }
    int lastStatusUpdateMs = _asInt(source['lastStatusUpdateMs'], fallback: 0);
    if (lastStatusUpdateMs <= 0) {
      lastStatusUpdateMs = deliveredAtMs > 0 ? deliveredAtMs : createdAtLocalMs;
    }

    String deliveryStatus = _asString(source['deliveryStatus']).trim();
    String orderStatus = _asString(source['orderStatus']).trim();
    final bool deliveredLike =
        _normalizeOrderStatus(source) == 'delivered' || deliveredAtMs > 0;
    if (deliveryStatus.isEmpty) {
      deliveryStatus = deliveredLike ? 'delivered' : 'order_placed';
    }
    if (orderStatus.isEmpty) {
      orderStatus = deliveredLike ? 'delivered' : 'paid';
    }

    // Build only whitelisted/sanitized fields so legacy invalid source values
    // cannot violate create validation rules for global shopOrders.
    final Map<String, dynamic> seed = <String, dynamic>{
      'orderId': orderId,
      'customerId': customerId,
      'userId': customerId,
      'itemId': itemId,
      'itemName': itemName,
      'categoryName': categoryName,
      'category': categoryName,
      'quantity': quantity > 0 ? quantity : 1,
      'unitPrice': unitPrice < 0 ? 0 : unitPrice,
      'totalAmount': totalAmount,
      'paymentId': _asString(source['paymentId']),
      'paymentMethod': _asString(source['paymentMethod']),
      'orderStatus': orderStatus,
      'deliveryStatus': deliveryStatus,
      'currency': _asString(source['currency'], fallback: 'INR'),
      'customerEmail': _asString(source['customerEmail']),
      'itemImageUrl': _asString(source['itemImageUrl'] ?? source['imageUrl']),
      'createdAtLocalMs': createdAtLocalMs,
      'lastStatusUpdateMs': lastStatusUpdateMs,
      'returnReplacementRequest': rrPayload,
    };

    if (deliveredAtMs > 0) {
      seed['deliveredAtLocalMs'] = deliveredAtMs;
    }
    final String orderCode = _asString(source['orderCode']).trim();
    if (orderCode.isNotEmpty) {
      seed['orderCode'] = orderCode;
    }
    return seed;
  }

  String _rrTypeLabel(String type) {
    final String value = type.trim().toLowerCase();
    if (value == 'return') return 'Return';
    if (value == 'replacement') return 'Replacement';
    return 'Request';
  }

  String _rrStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'requested':
        return 'Requested';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return '-';
    }
  }

  Color _rrStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'requested':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'in_progress':
        return Colors.deepPurple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildReturnReplacementSection({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> orderData,
    required String itemName,
    required String customerId,
    required Map<String, dynamic>? request,
    required bool canRequest,
  }) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != customerId) {
      return const SizedBox.shrink();
    }

    final String rrType = ((request?['requestType'] as String?) ?? '')
        .trim()
        .toLowerCase();
    final String rrStatus = ((request?['status'] as String?) ?? '')
        .trim()
        .toLowerCase();
    final String rrReason = ((request?['reason'] as String?) ?? '').trim();
    final int requestedAt = _asInt(request?['requestedAtLocalMs'], fallback: 0);

    return _buildSection(
      title: 'Return / Replacement',
      children: [
        if (request != null) ...[
          _detailRow('Type', _rrTypeLabel(rrType)),
          _detailRow('Status', _rrStatusLabel(rrStatus)),
          if (rrReason.isNotEmpty) _detailRow('Reason', rrReason),
          if (requestedAt > 0)
            _detailRow(
              'Requested At',
              _formatDateTime(DateTime.fromMillisecondsSinceEpoch(requestedAt)),
            ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _rrStatusColor(rrStatus).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _rrStatusColor(rrStatus).withOpacity(0.25)),
            ),
            child: Text(
              'Current status: ${_rrStatusLabel(rrStatus)}',
              style: TextStyle(
                color: _rrStatusColor(rrStatus),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (canRequest) ...[
          Text(
            'Eligible after delivery',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openReturnReplacementRequestDialog(
                    context: context,
                    orderId: orderId,
                    orderData: orderData,
                    itemName: itemName,
                    customerId: customerId,
                    requestType: 'return',
                  ),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Request Return'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: BorderSide(color: Colors.deepPurple.withOpacity(0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openReturnReplacementRequestDialog(
                    context: context,
                    orderId: orderId,
                    orderData: orderData,
                    itemName: itemName,
                    customerId: customerId,
                    requestType: 'replacement',
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Request Replacement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: BorderSide(color: Colors.deepPurple.withOpacity(0.3)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _openReturnReplacementRequestDialog({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> orderData,
    required String itemName,
    required String customerId,
    required String requestType,
  }) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    String reasonDraft = '';

    final String? reasonValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final String trimmedReason = reasonDraft.trim();
          return AlertDialog(
            title: Text('${_rrTypeLabel(requestType)} Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please provide the reason for your request.',
                ),
                const SizedBox(height: 10),
                TextField(
                  maxLines: 4,
                  maxLength: 2000,
                  onChanged: (value) {
                    setDialogState(() => reasonDraft = value);
                  },
                  decoration: InputDecoration(
                    labelText: '${_rrTypeLabel(requestType)} reason',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: trimmedReason.isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop(trimmedReason),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );

    if (reasonValue == null || reasonValue.trim().isEmpty) {
      return;
    }

    try {
      final bool submitted = await _submitReturnReplacementRequest(
        orderId: orderId,
        orderData: orderData,
        itemName: itemName,
        customerId: customerId,
        requestType: requestType,
        reason: reasonValue.trim(),
      );
      if (!context.mounted) return;

      if (submitted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text('${_rrTypeLabel(requestType)} request submitted.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to submit request. Ensure delivery is completed and Firestore rules are deployed.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Unable to submit request: $e')),
      );
    }
  }

  Future<bool> _submitReturnReplacementRequest({
    required String orderId,
    required Map<String, dynamic> orderData,
    required String itemName,
    required String customerId,
    required String requestType,
    required String reason,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String requestedOrderId = orderId.trim();
    if (user == null || user.uid != customerId || requestedOrderId.isEmpty) {
      return false;
    }
    final String normalizedType = requestType.trim().toLowerCase();
    if (normalizedType != 'return' && normalizedType != 'replacement') {
      return false;
    }
    final String normalizedReason = reason.trim();
    if (normalizedReason.isEmpty || normalizedReason.length > 2000) {
      return false;
    }

    final Map<String, dynamic> screenOrderData = Map<String, dynamic>.from(
      orderData,
    );

    final CollectionReference<Map<String, dynamic>> globalOrdersRef =
        FirebaseFirestore.instance.collection('shopOrders');
    final userOrdersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopOrders');
    final DocumentReference<Map<String, dynamic>> userRef =
        userOrdersRef.doc(requestedOrderId);

    Map<String, dynamic>? userLatest;
    Map<String, dynamic>? globalLatest;
    bool anyByIdReadable = false;
    try {
      final userSnap = await userRef.get();
      userLatest = userSnap.data();
    } catch (_) {}

    final String orderIdFromScreen = _asString(screenOrderData['orderId']).trim();
    final String orderIdFromUser = _asString(userLatest?['orderId']).trim();

    final List<String> candidateGlobalDocIds = <String>[];
    void addCandidate(String value) {
      if (value.isEmpty || candidateGlobalDocIds.contains(value)) return;
      candidateGlobalDocIds.add(value);
    }

    addCandidate(requestedOrderId);
    addCandidate(orderIdFromScreen);
    addCandidate(orderIdFromUser);
    if (candidateGlobalDocIds.isEmpty) return false;

    DocumentReference<Map<String, dynamic>> targetGlobalRef = globalOrdersRef
        .doc(candidateGlobalDocIds.first);

    for (final String candidateId in candidateGlobalDocIds) {
      final DocumentReference<Map<String, dynamic>> byIdGlobalRef =
          globalOrdersRef.doc(candidateId);
      try {
        final DocumentSnapshot<Map<String, dynamic>> globalSnap =
            await byIdGlobalRef.get();
        anyByIdReadable = true;
        if (globalSnap.exists && globalSnap.data() != null) {
          targetGlobalRef = byIdGlobalRef;
          globalLatest = globalSnap.data();
          break;
        }
      } catch (_) {}
    }

    if (globalLatest == null) {
      final String orderCode = _asString(
        screenOrderData['orderCode'] ?? userLatest?['orderCode'],
      ).trim();
      final String paymentId = _asString(
        screenOrderData['paymentId'] ?? userLatest?['paymentId'],
      ).trim();
      final String knownOrderId = orderIdFromScreen.isNotEmpty
          ? orderIdFromScreen
          : orderIdFromUser;
      final Map<String, dynamic> lookupSource = <String, dynamic>{
        if (knownOrderId.isNotEmpty) 'orderId': knownOrderId,
        if (orderCode.isNotEmpty) 'orderCode': orderCode,
        if (paymentId.isNotEmpty) 'paymentId': paymentId,
      };
      final QueryDocumentSnapshot<Map<String, dynamic>>? byMetaDoc =
          await _findGlobalOrderDocByMeta(lookupSource);
      if (byMetaDoc != null) {
        targetGlobalRef = byMetaDoc.reference;
        globalLatest = byMetaDoc.data();
      }
    }

    String canonicalOrderId = _asString(globalLatest?['orderId']).trim();
    if (canonicalOrderId.isEmpty) canonicalOrderId = orderIdFromScreen;
    if (canonicalOrderId.isEmpty) canonicalOrderId = orderIdFromUser;
    if (canonicalOrderId.isEmpty) canonicalOrderId = requestedOrderId;

    if (globalLatest == null && !anyByIdReadable) {
      // If direct doc read failed (possibly denied/legacy mismatch), avoid
      // random writes and use a deterministic fallback doc id.
      targetGlobalRef = globalOrdersRef.doc(
        canonicalOrderId.isNotEmpty ? canonicalOrderId : requestedOrderId,
      );
    }

    final Map<String, dynamic>? latest =
        globalLatest ?? userLatest ?? (screenOrderData.isEmpty ? null : screenOrderData);
    if (latest == null) return false;

    final String latestStatus = _normalizeOrderStatus(latest);
    if (latestStatus != 'delivered') return false;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    Future<bool> syncUserRequest(Map<String, dynamic> rrPayload) async {
      if (userLatest != null) {
        try {
          await userRef.update({'returnReplacementRequest': rrPayload});
          return true;
        } catch (_) {
          try {
            await userRef.set(
              {'returnReplacementRequest': rrPayload},
              SetOptions(merge: true),
            );
            return true;
          } catch (_) {
            return false;
          }
        }
      }

      final Map<String, dynamic> sourceForUserSeed = globalLatest ?? latest;
      final Map<String, dynamic>? userSeed =
          _buildGlobalOrderSeedForReturnReplacement(
            orderId: canonicalOrderId,
            customerId: user.uid,
            source: sourceForUserSeed,
            rrPayload: rrPayload,
            nowMs: nowMs,
          );
      if (userSeed == null) return false;
      try {
        await userRef.set(userSeed, SetOptions(merge: true));
        return true;
      } catch (_) {
        return false;
      }
    }

    final Map<String, dynamic>? existing = _extractReturnReplacementRequest(
      latest,
    );
    final String existingStatus = ((existing?['status'] as String?) ?? '')
        .trim()
        .toLowerCase();
    if (existing != null &&
        existingStatus != 'rejected' &&
        existingStatus != '') {
      // Idempotent behaviour: treat existing active request as success.
      if (globalLatest != null) {
        await syncUserRequest(Map<String, dynamic>.from(existing));
        return true;
      }

      final Map<String, dynamic>? existingSeed =
          _buildGlobalOrderSeedForReturnReplacement(
            orderId: canonicalOrderId,
            customerId: user.uid,
            source: userLatest ?? latest,
            rrPayload: Map<String, dynamic>.from(existing),
            nowMs: nowMs,
          );
      bool globalUpdated = false;
      if (existingSeed != null) {
        try {
          await targetGlobalRef.set(existingSeed, SetOptions(merge: true));
          globalUpdated = true;
        } catch (_) {}
      }
      if (!globalUpdated) return false;
      await syncUserRequest(Map<String, dynamic>.from(existing));
      return true;
    }

    String safeItemName = itemName.trim();
    if (safeItemName.isEmpty) safeItemName = 'Product';
    if (safeItemName.length > 200) {
      safeItemName = safeItemName.substring(0, 200);
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'requestType': normalizedType,
      'status': 'requested',
      'reason': normalizedReason,
      'itemName': safeItemName,
      'requestedBy': user.uid,
      'requestedAt': FieldValue.serverTimestamp(),
      'requestedAtLocalMs': nowMs,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtLocalMs': nowMs,
    };

    bool globalUpdated = false;

    if (globalLatest != null) {
      try {
        await targetGlobalRef.update({'returnReplacementRequest': payload});
        globalUpdated = true;
      } catch (_) {
        try {
          await targetGlobalRef.set(
            {'returnReplacementRequest': payload},
            SetOptions(merge: true),
          );
          globalUpdated = true;
        } catch (_) {}
      }
    } else {
      final Map<String, dynamic>? globalSeed =
          _buildGlobalOrderSeedForReturnReplacement(
            orderId: canonicalOrderId,
            customerId: user.uid,
            source: userLatest ?? latest,
            rrPayload: payload,
            nowMs: nowMs,
          );
      if (globalSeed != null) {
        try {
          await targetGlobalRef.set(globalSeed, SetOptions(merge: true));
          globalUpdated = true;
        } catch (_) {}
      }
    }

    if (!globalUpdated) {
      // Last-resort write path so request is still visible in shop dashboard,
      // even when legacy global doc ids/shape are inconsistent.
      final String fallbackDocId = (
        'rr_${user.uid}_$canonicalOrderId'
      ).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final Map<String, dynamic>? fallbackSeed =
          _buildGlobalOrderSeedForReturnReplacement(
            orderId: canonicalOrderId,
            customerId: user.uid,
            source: latest,
            rrPayload: payload,
            nowMs: nowMs,
          );
      if (fallbackSeed != null) {
        try {
          await globalOrdersRef
              .doc(fallbackDocId)
              .set(fallbackSeed, SetOptions(merge: true));
          globalUpdated = true;
        } catch (_) {}
      }
    }

    if (!globalUpdated) return false;
    await syncUserRequest(payload);
    return true;
  }

  Widget _buildShopReviewSection({
    required BuildContext context,
    required String orderId,
    required String itemId,
    required String itemName,
    required String customerId,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != customerId || itemId.trim().isEmpty || itemId == '-') {
      return const SizedBox.shrink();
    }

    final reviewRef = FirebaseFirestore.instance
        .collection('shopItemReviews')
        .doc(_shopReviewDocId(orderId, user.uid));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: reviewRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final bool hasReview = data != null;
        final double rating = _asDouble(data?['rating']);
        final String comment = (data?['comment'] as String?)?.trim() ?? '';

        return _buildSection(
          title: 'Product Review',
          children: [
            if (hasReview) _detailRow('Your Rating', _ratingText(rating)),
            if (hasReview && comment.isNotEmpty) _detailRow('Your Review', comment),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _openShopReviewDialog(
                    context: context,
                    reviewRef: reviewRef,
                    orderId: orderId,
                    itemId: itemId,
                    itemName: itemName,
                    customerId: customerId,
                    isEdit: hasReview,
                    initialRating: hasReview && rating >= 1 && rating <= 5 ? rating : 5.0,
                    initialComment: comment,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  hasReview ? Icons.visibility_rounded : Icons.rate_review_rounded,
                ),
                label: Text(hasReview ? 'View Review' : 'Add Review'),
              ),
            ),
          ],
        );
      },
    );
  }

  String _shopReviewDocId(String orderId, String customerId) {
    return '${orderId}_$customerId';
  }

  Future<void> _openShopReviewDialog({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> reviewRef,
    required String orderId,
    required String itemId,
    required String itemName,
    required String customerId,
    required bool isEdit,
    required double initialRating,
    required String initialComment,
  }) async {
    final TextEditingController commentController = TextEditingController(
      text: initialComment,
    );
    double rating = initialRating;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final bool? submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(isEdit ? 'Your Review' : 'Add Review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (int i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setState(() => rating = i.toDouble()),
                        icon: Icon(
                          rating >= i ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Write your review (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    return;
                  }
                  final String reviewerName = await _resolveReviewerName(
                    currentUser,
                  );

                  final Map<String, dynamic> payload = <String, dynamic>{
                    'orderId': orderId,
                    'itemId': itemId,
                    'itemName': itemName,
                    'customerId': customerId,
                    'customerName': reviewerName,
                    'customerEmail': (currentUser.email ?? '').trim(),
                    'rating': rating,
                    'comment': commentController.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  if (!isEdit) {
                    payload['createdAt'] = FieldValue.serverTimestamp();
                  }

                  await reviewRef.set(payload, SetOptions(merge: true));
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: Text(isEdit ? 'Update' : 'Submit'),
              ),
            ],
          ),
        ),
      );

      if (submitted ?? false) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              isEdit ? 'Review updated successfully.' : 'Review submitted successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Failed to save review: $e')));
    } finally {
      commentController.dispose();
    }
  }

  Future<String> _resolveReviewerName(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final String username = ((doc.data()?['username'] as String?) ?? '').trim();
      if (username.isNotEmpty) {
        return username;
      }
    } catch (_) {}

    return 'User';
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final String v = (value ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _emailUserPart(String email) {
    if (email.isEmpty) return '';
    final int at = email.indexOf('@');
    if (at <= 0) return email;
    return email.substring(0, at).trim();
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  String _ratingText(double value) {
    if (value <= 0) return '-';
    final double safe = value > 5 ? 5 : value;
    return '${safe.toStringAsFixed(1)}/5';
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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

  const _CategoryQuickCard({required this.category, required this.onTap});

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
                  child: ClipOval(
                    child: Image.network(
                      category.effectiveImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(category.icon, color: category.accentColor),
                    ),
                  ),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        activeCategory.effectiveImageUrl,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 34,
                          height: 34,
                          color: activeCategory.accentColor.withOpacity(0.14),
                          child: Icon(
                            activeCategory.icon,
                            color: activeCategory.accentColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
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
                                color: activeCategory.accentColor.withOpacity(
                                  0.12,
                                ),
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
                                  'Brand: ${item.displayBrand}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
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

  const _ItemDetailsScreen({required this.category, required this.item});

  @override
  State<_ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

enum _CheckoutPaymentOption { online, cod }

class _ItemDetailsScreenState extends State<_ItemDetailsScreen> {
  static const String _razorpayKey = 'rzp_test_RWRMUwaEf4eLLC';

  late final Razorpay _razorpay;
  final TextEditingController _deliveryLocationController =
      TextEditingController();
  final Map<String, Future<String>> _dashboardNameFutureByUid =
      <String, Future<String>>{};
  int _quantity = 1;
  _CheckoutPaymentOption _selectedPaymentOption = _CheckoutPaymentOption.online;
  String _pendingDeliveryLocation = '';
  _CheckoutPaymentOption _pendingPaymentOption = _CheckoutPaymentOption.online;

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
    _deliveryLocationController.dispose();
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

  void _buyNow() async {
    _deliveryLocationController.text = _pendingDeliveryLocation;
    _selectedPaymentOption = _pendingPaymentOption;
    await _setCurrentLocationForCheckout(force: true);
    if (!mounted) {
      return;
    }
    _showCheckoutSheet();
  }

  Future<bool> _setCurrentLocationForCheckout({
    bool force = false,
    bool showSnack = false,
  }) async {
    if (!force && _deliveryLocationController.text.trim().isNotEmpty) {
      return true;
    }

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String locationText = '';
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          locationText = [
            p.street,
            p.subLocality,
            p.locality,
            p.postalCode,
          ].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
        }
      } catch (_) {
        // Reverse geocode can fail; fall back to coordinates.
      }

      if (locationText.isEmpty) {
        locationText =
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      }

      _deliveryLocationController.text = locationText;
      _pendingDeliveryLocation = locationText;
      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location added')),
        );
      }
      return true;
    } catch (_) {
      // Keep checkout flow intact; user can still enter location manually.
      return false;
    }
  }

  void _showCheckoutSheet() {
    final List<ShopItem> suggestedItems = () {
      for (final category
          in ShopCatalogStore.instance.categoriesNotifier.value) {
        if (category.id != widget.category.id) continue;
        return category.items
            .where((i) => i.id != widget.item.id)
            .take(3)
            .toList(growable: false);
      }
      return const <ShopItem>[];
    }();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  14 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checkout',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _deliveryLocationController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Delivery Location',
                          hintText: 'Enter house/flat, street, area, city',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final bool added = await _setCurrentLocationForCheckout(
                              force: true,
                              showSnack: true,
                            );
                            if (added) {
                              setSheetState(() {});
                            }
                          },
                          icon: const Icon(Icons.my_location),
                          label: const Text('Add current location'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.deepPurple.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          'Estimated delivery: within ${widget.item.displayDeliveryWorkingDays} working days',
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Payment Option',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      RadioListTile<_CheckoutPaymentOption>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _CheckoutPaymentOption.online,
                        groupValue: _selectedPaymentOption,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setSheetState(() => _selectedPaymentOption = value);
                        },
                        title: const Text('Online Payment (Razorpay)'),
                      ),
                      RadioListTile<_CheckoutPaymentOption>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _CheckoutPaymentOption.cod,
                        groupValue: _selectedPaymentOption,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setSheetState(() => _selectedPaymentOption = value);
                        },
                        title: const Text('Cash on Delivery'),
                      ),
                      if (suggestedItems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Suggestions',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: suggestedItems
                              .map((i) => _featureChip(i.name))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantity: $_quantity',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total: Rs $_totalPrice',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            final String location = _deliveryLocationController
                                .text
                                .trim();
                            if (location.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please add delivery location.',
                                  ),
                                ),
                              );
                              return;
                            }

                            _pendingDeliveryLocation = location;
                            _pendingPaymentOption = _selectedPaymentOption;
                            Navigator.pop(context);

                            if (_selectedPaymentOption ==
                                _CheckoutPaymentOption.online) {
                              _startOnlinePayment(location);
                            } else {
                              await _placeCodOrder(location);
                            }
                          },
                          child: Text(
                            _selectedPaymentOption ==
                                    _CheckoutPaymentOption.online
                                ? 'Continue to Pay'
                                : 'Place COD Order',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startOnlinePayment(String location) {
    final user = FirebaseAuth.instance.currentUser;
    _pendingDeliveryLocation = location;
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
        'deliveryLocation': location,
      },
      'prefill': {
        'email': user?.email ?? '',
        'contact': user?.phoneNumber ?? '',
        'name': 'Customer',
      },
      'theme': {'color': '#673AB7'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start Razorpay: $e')));
    }
  }

  Future<void> _placeCodOrder(String location) async {
    final bool saved = await _saveShopOrder(
      paymentMethod: 'cod',
      paymentId: '',
      orderStatus: 'cod_pending',
      deliveryStatus: 'order_placed',
      customerDeliveryLocation: location,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Order placed with Cash on Delivery.'
              : 'Order placed, but sync is delayed. Refresh View Orders shortly.',
        ),
        backgroundColor: saved ? Colors.green : Colors.orange,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const _ShopOrdersScreen()),
    );
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final String location = _pendingDeliveryLocation.trim().isEmpty
        ? widget.item.displayDeliveryLocation
        : _pendingDeliveryLocation.trim();
    final bool orderSaved = await _saveShopOrder(
      paymentMethod: 'razorpay',
      paymentId: response.paymentId ?? '',
      orderStatus: 'paid',
      deliveryStatus: 'payment_confirmed',
      customerDeliveryLocation: location,
    );
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

  Future<bool> _saveShopOrder({
    required String paymentMethod,
    required String paymentId,
    required String orderStatus,
    required String deliveryStatus,
    required String customerDeliveryLocation,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String shortUid = user.uid.length >= 6
        ? user.uid.substring(0, 6)
        : user.uid;
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
      'itemBrand': widget.item.displayBrand,
      'itemModel': widget.item.displayModel,
      'itemModelNumber': widget.item.displayModelNumber,
      'itemType': widget.item.displayType,
      'itemShade': widget.item.displayShade,
      'itemMaterial': widget.item.displayMaterial,
      'itemPackOf': widget.item.displayPackOf,
      'itemHighlights': widget.item.displayHighlights,
      'deliveryLocation': widget.item.displayDeliveryLocation,
      'customerDeliveryLocation': customerDeliveryLocation,
      'deliveryWorkingDays': widget.item.displayDeliveryWorkingDays,
      'aboutSeller': widget.item.displayAboutSeller,
      'overallRating': widget.item.displayOverallRating,
      'productQuality': widget.item.displayProductQuality,
      'serviceQuality': widget.item.displayServiceQuality,
      'itemWarranty': widget.item.displayWarranty,
      'itemSuitableFor': widget.item.displaySuitableFor,
      'categoryId': widget.category.id,
      'categoryName': widget.category.name,
      'category': widget.category.name,
      'quantity': _quantity,
      'unitPrice': widget.item.price,
      'totalAmount': _totalPrice,
      'currency': 'INR',
      'paymentId': paymentId,
      'orderStatus': orderStatus,
      'deliveryStatus': deliveryStatus,
      'paymentMethod': paymentMethod,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtLocalMs': nowMs,
      'lastStatusUpdateMs': nowMs,
      'statusTimeline': deliveryStatus == 'payment_confirmed'
          ? [
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
            ]
          : [
              {
                'status': 'order_placed',
                'label': 'Order Placed',
                'atMs': nowMs,
                'by': 'customer',
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

    if (wroteAtLeastOne) {
      // Best-effort customer-facing shop notifications for initial stages.
      await _pushShopStageNotification(
        customerId: user.uid,
        orderId: globalRef.id,
        orderCode: orderCode,
        itemName: widget.item.name,
        status: 'order_placed',
      );
      if (deliveryStatus == 'payment_confirmed') {
        await _pushShopStageNotification(
          customerId: user.uid,
          orderId: globalRef.id,
          orderCode: orderCode,
          itemName: widget.item.name,
          status: 'payment_confirmed',
        );
      }
    }

    return wroteAtLeastOne;
  }

  Future<void> _pushShopStageNotification({
    required String customerId,
    required String orderId,
    required String orderCode,
    required String itemName,
    required String status,
  }) async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || customerId.trim().isEmpty) return;

    final String safeItem = itemName.trim().isEmpty ? 'your item' : itemName.trim();
    final String ref = orderCode.trim().isEmpty ? orderId : orderCode.trim();
    final String label = _shopStatusLabel(status);

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': customerId,
        'createdBy': uid,
        'type': 'shop_order_stage',
        'title': 'Shop order update',
        'body': '$safeItem is now "$label" (Order: $ref).',
        'status': status,
        'relatedId': orderId,
        'orderId': orderId,
        'orderCode': orderCode,
        'itemName': safeItem,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  String _shopStatusLabel(String status) {
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
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? 'Unknown error'}'),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
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

  Widget _featureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.deepPurple,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _ratingRow(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (rating / 5).clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerAndCustomerReviewSections() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shopItemReviews')
          .where('itemId', isEqualTo: widget.item.id)
          .snapshots(),
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> reviews = (snapshot.data?.docs ?? [])
            .map((doc) => doc.data())
            .toList();

        final List<double> validRatings = reviews
            .map((r) => _toDouble(r['rating']))
            .where((r) => r >= 1 && r <= 5)
            .toList(growable: false);
        final bool hasCustomerRatings = validRatings.isNotEmpty;
        final double customerAverage = hasCustomerRatings
            ? validRatings.reduce((a, b) => a + b) / validRatings.length
            : widget.item.displayOverallRating;

        reviews.sort((a, b) => _reviewTimeMs(b).compareTo(_reviewTimeMs(a)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  const Text(
                    'Seller Details',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.displayAboutSeller,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ratingRow('Overall Rating', customerAverage),
                  _ratingRow(
                    'Product Quality',
                    widget.item.displayProductQuality,
                  ),
                  _ratingRow(
                    'Service Quality',
                    widget.item.displayServiceQuality,
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
                  const Text(
                    'Customer Reviews',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (hasCustomerRatings) ...[
                    _customerAverageStars(
                      average: customerAverage,
                      count: validRatings.length,
                    ),
                    const SizedBox(height: 6),
                    ...reviews
                        .where((r) {
                          final double rating = _toDouble(r['rating']);
                          return rating >= 1 && rating <= 5;
                        })
                        .take(3)
                        .map(
                          (r) => _customerReviewTile(
                            customerId: ((r['customerId'] as String?) ?? '').trim(),
                            customerName: _reviewerDisplayName(r),
                            rating: _toDouble(r['rating']),
                            comment: ((r['comment'] as String?) ?? '').trim(),
                          ),
                        ),
                  ] else
                    Text(
                      'No customer reviews yet for this product.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _customerReviewTile({
    required String customerId,
    required String customerName,
    required double rating,
    required String comment,
  }) {
    final double safeRating = rating < 1 ? 1 : (rating > 5 ? 5 : rating);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FutureBuilder<String>(
                  future: _dashboardUsernameForCustomerId(
                    customerId,
                    fallbackName: customerName,
                  ),
                  builder: (context, snapshot) {
                    final String resolved = _normalizedReviewerName(
                      snapshot.data ?? customerName,
                    );
                    return Text(
                      resolved,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    );
                  },
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _starRatingBar(safeRating, size: 14),
                  const SizedBox(height: 2),
                  Text(
                    '${safeRating.toStringAsFixed(1)}/5',
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _customerAverageStars({
    required double average,
    required int count,
  }) {
    final double safe = average < 1 ? 1 : (average > 5 ? 5 : average);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          _starRatingBar(safe, size: 16),
          const SizedBox(width: 8),
          Text(
            '${safe.toStringAsFixed(1)} / 5',
            style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '$count review${count == 1 ? '' : 's'}',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _starRatingBar(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final int star = index + 1;
        IconData icon;
        if (rating >= star) {
          icon = Icons.star_rounded;
        } else if (rating >= star - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, size: size, color: Colors.amber);
      }),
    );
  }

  int _reviewTimeMs(Map<String, dynamic> data) {
    final dynamic updatedAt = data['updatedAt'];
    final dynamic createdAt = data['createdAt'];
    if (updatedAt is Timestamp) return updatedAt.millisecondsSinceEpoch;
    if (createdAt is Timestamp) return createdAt.millisecondsSinceEpoch;
    return 0;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<String> _dashboardUsernameForCustomerId(
    String customerId, {
    required String fallbackName,
  }) {
    final String uid = customerId.trim();
    final String safeFallback = _normalizedReviewerName(fallbackName);
    if (uid.isEmpty) {
      return Future<String>.value(safeFallback);
    }

    final existing = _dashboardNameFutureByUid[uid];
    if (existing != null) {
      return existing;
    }

    final future = () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final String username = ((doc.data()?['username'] as String?) ?? '')
            .trim();
        if (username.isNotEmpty) {
          return username;
        }
      } catch (_) {}
      return safeFallback;
    }();

    _dashboardNameFutureByUid[uid] = future;
    return future;
  }

  String _normalizedReviewerName(String value) {
    final String v = value.trim();
    return v.isEmpty ? 'User' : v;
  }

  String _reviewerDisplayName(Map<String, dynamic> data) {
    final String customerId = ((data['customerId'] as String?) ?? '').trim();
    final String explicit = ((data['customerName'] as String?) ?? '').trim();
    if (explicit.isNotEmpty && explicit != customerId) {
      return explicit;
    }

    final String email = ((data['customerEmail'] as String?) ?? '').trim();
    if (email.isNotEmpty) {
      final int at = email.indexOf('@');
      if (at > 0) return email.substring(0, at).trim();
      return email;
    }

    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _featureChip(widget.item.displayBrand),
                          _featureChip(widget.item.displayModel),
                        ],
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
                const Text(
                  'Delivery Details',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 8),
                _infoRow('Location', widget.item.displayDeliveryLocation),
                _infoRow(
                  'Delivery',
                  'Within ${widget.item.displayDeliveryWorkingDays} working days',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSellerAndCustomerReviewSections(),
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
                const Text(
                  'About Product',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item.displayAbout,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow('Brand', widget.item.displayBrand),
                _infoRow('Model', widget.item.displayModel),
                _infoRow('Model No', widget.item.displayModelNumber),
                _infoRow('Type', widget.item.displayType),
                _infoRow('Shade', widget.item.displayShade),
                _infoRow('Material', widget.item.displayMaterial),
                _infoRow('Pack Of', widget.item.displayPackOf),
                _infoRow('Suitable', widget.item.displaySuitableFor),
                _infoRow('Warranty', widget.item.displayWarranty),
                _infoRow('Unit Price', 'Rs ${widget.item.price}'),
                const SizedBox(height: 4),
                const Text(
                  'Highlights',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.item.displayHighlights
                      .map((feature) => _featureChip(feature))
                      .toList(),
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
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const SizedBox(height: 14),
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
    );
  }
}
