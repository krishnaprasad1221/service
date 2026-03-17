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
  static const int _rrResponseSlaMs = 24 * 60 * 60 * 1000;
  static const int _highValueThreshold = 5000;
  static const List<String> _rrTabKeys = <String>[
    'requested',
    'approved',
    'rejected',
    'in_progress',
    'completed',
  ];
  static const List<String> _rejectPolicyReasons = <String>[
    'Product condition is not eligible under return/replacement policy.',
    'Physical damage not covered by replacement policy.',
    'Issue mismatch after quality inspection.',
  ];
  static const List<Map<String, String>> _returnCheckpointDefs = <Map<String, String>>[
    {'key': 'pickupScheduled', 'label': 'Pickup Scheduled'},
    {'key': 'pickedUp', 'label': 'Picked Up'},
    {'key': 'qualityChecked', 'label': 'Quality Check'},
    {'key': 'refundProcessed', 'label': 'Refund Processed'},
  ];
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
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _normalizeOrderStatus(Map<String, dynamic> data) {
    final String? delivery = (data['deliveryStatus'] as String?)?.trim();
    if (delivery != null && delivery.isNotEmpty) return delivery.toLowerCase();
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
    if (status == 'cancelled') return Colors.red;
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

  Map<String, dynamic>? _extractReturnReplacementRequest(
    Map<String, dynamic> data,
  ) {
    final dynamic raw = data['returnReplacementRequest'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  String _rrTypeLabel(String value) {
    final String type = value.trim().toLowerCase();
    if (type == 'return') return 'Return';
    if (type == 'replacement') return 'Replacement';
    return 'Request';
  }

  String _rrStatusLabel(String value) {
    switch (value.trim().toLowerCase()) {
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

  Color _rrStatusColor(String value) {
    switch (value.trim().toLowerCase()) {
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

  String _nextReturnReplacementStatus(String currentStatus) {
    if (currentStatus == 'approved') return 'in_progress';
    if (currentStatus == 'in_progress') return 'completed';
    return currentStatus;
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
    return _asInt(data['lastStatusUpdateMs'], fallback: 0);
  }

  String _normalizeRrStatus(String value) {
    final String v = value.trim().toLowerCase();
    if (v == 'requested' ||
        v == 'approved' ||
        v == 'rejected' ||
        v == 'in_progress' ||
        v == 'completed') {
      return v;
    }
    return 'requested';
  }

  int _rrRequestedAtMs(Map<String, dynamic> rr, Map<String, dynamic> orderData) {
    final int reqAt = _asInt(rr['requestedAtLocalMs'], fallback: 0);
    if (reqAt > 0) return reqAt;
    final int createdAt = _asInt(orderData['createdAtLocalMs'], fallback: 0);
    if (createdAt > 0) return createdAt;
    return _asInt(orderData['lastStatusUpdateMs'], fallback: 0);
  }

  String _rrEffectiveTabStatus(
    Map<String, dynamic> rr,
    Map<String, dynamic> orderData,
  ) {
    return _normalizeRrStatus((rr['status'] as String?) ?? '');
  }

  bool _canTransitionRrStatus(String currentStatus, String nextStatus) {
    final String current = _normalizeRrStatus(currentStatus);
    final String next = _normalizeRrStatus(nextStatus);
    if (current == 'requested') {
      return next == 'approved' || next == 'rejected';
    }
    if (current == 'approved') {
      return next == 'in_progress';
    }
    if (current == 'in_progress') {
      return next == 'completed';
    }
    return false;
  }

  List<Map<String, dynamic>> _rrAuditTrail(Map<String, dynamic> rr) {
    final dynamic raw = rr['auditTrail'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: true);
  }

  Map<String, dynamic> _rrAuditEntry({
    required String action,
    required String actor,
    required int atMs,
    String status = '',
    String note = '',
    String checkpoint = '',
  }) {
    return <String, dynamic>{
      'action': action,
      if (status.trim().isNotEmpty) 'status': status.trim().toLowerCase(),
      if (note.trim().isNotEmpty) 'note': note.trim(),
      if (checkpoint.trim().isNotEmpty) 'checkpoint': checkpoint.trim(),
      'by': actor,
      'atMs': atMs,
    };
  }

  Map<String, bool> _rrCheckpoints(Map<String, dynamic> rr) {
    final Map<String, bool> out = <String, bool>{
      'pickupScheduled': false,
      'pickedUp': false,
      'qualityChecked': false,
      'refundProcessed': false,
    };
    final dynamic raw = rr['checkpoints'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key is String && out.containsKey(key) && value is bool) {
          out[key] = value;
        }
      });
    }
    return out;
  }

  bool _isCheckpointActionAllowed(Map<String, bool> checkpoints, String key) {
    if (!checkpoints.containsKey(key)) return false;
    if (checkpoints[key] == true) return false;
    if (key == 'pickupScheduled') return true;
    if (key == 'pickedUp') return checkpoints['pickupScheduled'] == true;
    if (key == 'qualityChecked') return checkpoints['pickedUp'] == true;
    if (key == 'refundProcessed') return checkpoints['qualityChecked'] == true;
    return false;
  }

  String _formatDurationCompact(int ms) {
    if (ms <= 0) return '-';
    final int minutes = (ms / 60000).floor();
    if (minutes < 60) return '${minutes}m';
    final int hours = (minutes / 60).floor();
    if (hours < 24) return '${hours}h ${minutes % 60}m';
    final int days = (hours / 24).floor();
    return '${days}d ${hours % 24}h';
  }

  bool _isReplacementStockAvailable(Map<String, dynamic> orderData) {
    final String itemId = ((orderData['itemId'] as String?) ?? '').trim();
    final String itemName =
        ((orderData['itemName'] as String?) ?? '').trim().toLowerCase();
    if (itemId.isEmpty && itemName.isEmpty) return false;
    for (final ShopCategory category in _store.categoriesNotifier.value) {
      for (final ShopItem item in category.items) {
        if (itemId.isNotEmpty && item.id == itemId) return true;
        if (itemName.isNotEmpty && item.name.trim().toLowerCase() == itemName) {
          return true;
        }
      }
    }
    return false;
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
        },
      ]),
    };
    if (next == 'delivered') {
      updates['deliveredAtLocalMs'] = nowMs;
    }

    try {
      await FirebaseFirestore.instance
          .collection('shopOrders')
          .doc(orderDocId)
          .update(updates);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update order: $e')));
      return;
    }

    final String customerId = (orderData['customerId'] as String?) ?? '';
    await _syncOrderUpdatesToUserCopy(
      customerId: customerId,
      orderDocId: orderDocId,
      orderData: orderData,
      updates: updates,
    );

    await _pushShopStageNotificationToCustomer(
      customerId: customerId,
      orderId: (orderData['orderId'] as String?) ?? orderDocId,
      orderCode: (orderData['orderCode'] as String?) ?? '',
      itemName: (orderData['itemName'] as String?) ?? 'Product',
      status: next,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order moved to "${_statusLabel(next)}".')),
    );
  }

  Future<void> _syncOrderUpdatesToUserCopy({
    required String customerId,
    required String orderDocId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> updates,
  }) async {
    if (customerId.trim().isEmpty) return;

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

    if (synced) return;

    final userOrdersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(customerId)
        .collection('shopOrders');
    final String orderCode = (orderData['orderCode'] as String?) ?? '';
    final String paymentId = (orderData['paymentId'] as String?) ?? '';
    QuerySnapshot<Map<String, dynamic>>? snap;
    if (orderCode.isNotEmpty) {
      snap = await userOrdersRef.where('orderCode', isEqualTo: orderCode).limit(5).get();
    } else if (paymentId.isNotEmpty) {
      snap = await userOrdersRef.where('paymentId', isEqualTo: paymentId).limit(5).get();
    }
    if (snap != null) {
      for (final d in snap.docs) {
        try {
          await d.reference.update(updates);
        } catch (_) {}
      }
    }
  }

  Future<void> _updateReturnReplacementRequestStatus({
    required String orderDocId,
    required Map<String, dynamic> orderData,
    required String nextStatus,
    String note = '',
  }) async {
    final Map<String, dynamic>? rr = _extractReturnReplacementRequest(orderData);
    if (rr == null) return;

    final String currentStatus = _normalizeRrStatus(
      (rr['status'] as String?) ?? 'requested',
    );
    final String targetStatus = _normalizeRrStatus(nextStatus);
    if (!_canTransitionRrStatus(currentStatus, targetStatus)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid flow: ${_rrStatusLabel(currentStatus)} -> ${_rrStatusLabel(targetStatus)}',
          ),
        ),
      );
      return;
    }

    final String requestType = ((rr['requestType'] as String?) ?? '')
        .trim()
        .toLowerCase();
    final String cleanNote = note.trim();
    if (targetStatus == 'rejected' && cleanNote.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reject note is required.')),
      );
      return;
    }
    if (targetStatus == 'approved' &&
        requestType == 'replacement' &&
        !_isReplacementStockAvailable(orderData)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Replacement cannot be approved: stock unavailable.'),
        ),
      );
      return;
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String actor = FirebaseAuth.instance.currentUser?.uid ?? 'shop';
    final Map<String, dynamic> updated = Map<String, dynamic>.from(rr)
      ..['status'] = targetStatus
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['updatedAtLocalMs'] = nowMs
      ..['handledBy'] = actor;

    if (cleanNote.isNotEmpty) {
      updated['note'] = cleanNote;
    }
    if (targetStatus == 'approved' || targetStatus == 'rejected') {
      updated['decisionAt'] = FieldValue.serverTimestamp();
      updated['decisionAtLocalMs'] = nowMs;
      updated['decisionBy'] = actor;
    }
    if (targetStatus == 'completed') {
      updated['completedAt'] = FieldValue.serverTimestamp();
      updated['completedAtLocalMs'] = nowMs;
    }

    final List<Map<String, dynamic>> trail = _rrAuditTrail(rr)
      ..add(
        _rrAuditEntry(
          action: 'status_update',
          actor: actor,
          atMs: nowMs,
          status: targetStatus,
          note: cleanNote,
        ),
      );
    updated['auditTrail'] = trail;

    final Map<String, dynamic> updates = {'returnReplacementRequest': updated};

    try {
      await FirebaseFirestore.instance
          .collection('shopOrders')
          .doc(orderDocId)
          .update(updates);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: $e')),
      );
      return;
    }

    final String customerId = (orderData['customerId'] as String?) ?? '';
    await _syncOrderUpdatesToUserCopy(
      customerId: customerId,
      orderDocId: orderDocId,
      orderData: orderData,
      updates: updates,
    );

    final String type = ((updated['requestType'] as String?) ?? '').trim();
    await _pushReturnReplacementNotificationToCustomer(
      customerId: customerId,
      orderId: (orderData['orderId'] as String?) ?? orderDocId,
      itemName: (orderData['itemName'] as String?) ?? 'Product',
      requestType: type,
      status: targetStatus,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_rrTypeLabel(type)} request ${_rrStatusLabel(targetStatus)}.')),
    );
  }

  Future<void> _updateReturnCheckpoint({
    required String orderDocId,
    required Map<String, dynamic> orderData,
    required String checkpointKey,
  }) async {
    final Map<String, dynamic>? rr = _extractReturnReplacementRequest(orderData);
    if (rr == null) return;

    final String rrType = ((rr['requestType'] as String?) ?? '')
        .trim()
        .toLowerCase();
    if (rrType != 'return') return;
    final String rrStatus = _normalizeRrStatus((rr['status'] as String?) ?? '');
    if (rrStatus != 'approved' && rrStatus != 'in_progress') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkpoints are allowed only after approval.'),
        ),
      );
      return;
    }
    final Map<String, bool> checkpoints = _rrCheckpoints(rr);
    if (!_isCheckpointActionAllowed(checkpoints, checkpointKey)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete previous checkpoint first.')),
      );
      return;
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String actor = FirebaseAuth.instance.currentUser?.uid ?? 'shop';
    checkpoints[checkpointKey] = true;

    final Map<String, dynamic> updated = Map<String, dynamic>.from(rr)
      ..['checkpoints'] = checkpoints
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['updatedAtLocalMs'] = nowMs
      ..['handledBy'] = actor;

    final List<Map<String, dynamic>> trail = _rrAuditTrail(rr)
      ..add(
        _rrAuditEntry(
          action: 'checkpoint_update',
          actor: actor,
          atMs: nowMs,
          checkpoint: checkpointKey,
        ),
      );
    updated['auditTrail'] = trail;

    if (checkpointKey == 'refundProcessed') {
      updated['refundAt'] = FieldValue.serverTimestamp();
      updated['refundAtLocalMs'] = nowMs;
    }

    final Map<String, dynamic> updates = {'returnReplacementRequest': updated};

    try {
      await FirebaseFirestore.instance
          .collection('shopOrders')
          .doc(orderDocId)
          .update(updates);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update checkpoint: $e')),
      );
      return;
    }

    final String customerId = (orderData['customerId'] as String?) ?? '';
    await _syncOrderUpdatesToUserCopy(
      customerId: customerId,
      orderDocId: orderDocId,
      orderData: orderData,
      updates: updates,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Return checkpoint updated.')),
    );
  }

  Future<String?> _openRejectReasonDialog() async {
    String selectedTemplate = '';
    final TextEditingController noteController = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Reject Request'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select policy reason'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _rejectPolicyReasons.map((reason) {
                      final bool selected = selectedTemplate == reason;
                      return ChoiceChip(
                        label: Text(reason),
                        selected: selected,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedTemplate = reason;
                            noteController.text = reason;
                            noteController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(offset: noteController.text.length),
                                );
                          });
                        },
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    maxLength: 300,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Reject note (mandatory)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: noteController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(
                          dialogContext,
                        ).pop(noteController.text.trim()),
                child: const Text('Reject'),
              ),
            ],
          ),
        ),
      );
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _pushReturnReplacementNotificationToCustomer({
    required String customerId,
    required String orderId,
    required String itemName,
    required String requestType,
    required String status,
  }) async {
    final String actor = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (actor.isEmpty || customerId.trim().isEmpty) return;

    final String safeItem = itemName.trim().isEmpty ? 'your item' : itemName.trim();
    final String typeLabel = _rrTypeLabel(requestType);
    final String statusLabel = _rrStatusLabel(status);

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': customerId.trim(),
        'createdBy': actor,
        'type': 'shop_return_replacement',
        'title': '$typeLabel request update',
        'body': '$typeLabel request for $safeItem is now "$statusLabel".',
        'status': status,
        'relatedId': orderId,
        'orderId': orderId,
        'itemName': safeItem,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _pushShopStageNotificationToCustomer({
    required String customerId,
    required String orderId,
    required String orderCode,
    required String itemName,
    required String status,
  }) async {
    final String actor = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (actor.isEmpty || customerId.trim().isEmpty) return;

    final String safeItem = itemName.trim().isEmpty ? 'your item' : itemName.trim();
    final String ref = orderCode.trim().isEmpty ? orderId : orderCode.trim();
    final String label = _statusLabel(status);

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': customerId.trim(),
        'createdBy': actor,
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
                    backgroundColor: reached
                        ? Colors.deepPurple
                        : Colors.grey.shade300,
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
    final String itemHighlights = () {
      final dynamic raw = data['itemHighlights'];
      if (raw is List) {
        final List<String> vals = raw
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
        if (vals.isNotEmpty) return vals.join(', ');
      }
      return '-';
    }();
    final String overallRating = _ratingText(data['overallRating']);
    final String productQuality = _ratingText(data['productQuality']);
    final String serviceQuality = _ratingText(data['serviceQuality']);

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
                  _detailRow(
                    'Order ID',
                    (data['orderId'] ?? orderId).toString(),
                  ),
                  _detailRow(
                    'Order Code',
                    (data['orderCode'] ?? '-').toString(),
                  ),
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
                  _detailRow('Brand', (data['itemBrand'] ?? '-').toString()),
                  _detailRow('Model', (data['itemModel'] ?? '-').toString()),
                  _detailRow(
                    'Model Number',
                    (data['itemModelNumber'] ?? '-').toString(),
                  ),
                  _detailRow('Type', (data['itemType'] ?? '-').toString()),
                  _detailRow('Shade', (data['itemShade'] ?? '-').toString()),
                  _detailRow(
                    'Material',
                    (data['itemMaterial'] ?? '-').toString(),
                  ),
                  _detailRow('Pack Of', (data['itemPackOf'] ?? '-').toString()),
                  _detailRow(
                    'Category',
                    ((data['categoryName'] ?? data['category']) ?? '-')
                        .toString(),
                  ),
                  _detailRow(
                    'Quantity',
                    _asInt(data['quantity'], fallback: 1).toString(),
                  ),
                  _detailRow('Unit Price', 'Rs ${_asInt(data['unitPrice'])}'),
                  _detailRow(
                    'Total Amount',
                    'Rs ${_asInt(data['totalAmount'])}',
                  ),
                  _detailRow(
                    'Suitable For',
                    (data['itemSuitableFor'] ?? '-').toString(),
                  ),
                  _detailRow(
                    'Warranty',
                    (data['itemWarranty'] ?? '-').toString(),
                  ),
                  _detailRow('Highlights', itemHighlights),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Delivery & Seller',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Delivery Location',
                    (data['deliveryLocation'] ?? '-').toString(),
                  ),
                  _detailRow(
                    'Delivery To',
                    (data['customerDeliveryLocation'] ?? '-').toString(),
                  ),
                  _detailRow(
                    'Working Days',
                    data['deliveryWorkingDays'] == null
                        ? '-'
                        : 'Within ${_asInt(data['deliveryWorkingDays'])} working days',
                  ),
                  _detailRow(
                    'About Seller',
                    (data['aboutSeller'] ?? '-').toString(),
                  ),
                  _detailRow('Overall Rating', overallRating),
                  _detailRow('Product Quality', productQuality),
                  _detailRow('Service Quality', serviceQuality),
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
                    (data['paymentMethod'] ?? 'razorpay')
                        .toString()
                        .toUpperCase(),
                  ),
                  _detailRow(
                    'Currency',
                    (data['currency'] ?? 'INR').toString(),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Customer Details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Customer ID',
                    customerId.isEmpty ? '-' : customerId,
                  ),
                  _detailRow(
                    'Name',
                    (customerData?['username'] ?? customerData?['name'] ?? '-')
                        .toString(),
                  ),
                  _detailRow(
                    'Phone',
                    (customerData?['phone'] ??
                            customerData?['phoneNumber'] ??
                            '-')
                        .toString(),
                  ),
                  _detailRow(
                    'Email',
                    (data['customerEmail'] ?? customerData?['email'] ?? '-')
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

  String _ratingText(dynamic value) {
    double? parsed;
    if (value is double) {
      parsed = value;
    } else if (value is int) {
      parsed = value.toDouble();
    } else if (value is num) {
      parsed = value.toDouble();
    } else if (value is String) {
      parsed = double.tryParse(value);
    }
    if (parsed == null || parsed <= 0) return '-';
    final double safe = parsed > 5 ? 5 : parsed;
    return '${safe.toStringAsFixed(1)}/5';
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
    final imageController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(
                    labelText: 'Category Image URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
                final imageUrl = imageController.text.trim();
                _store.addCategory(
                  name: name,
                  imageUrl: imageUrl.isEmpty ? null : imageUrl,
                );
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
    final modelNumberController = TextEditingController();
    final typeController = TextEditingController();
    final shadeController = TextEditingController();
    final materialController = TextEditingController();
    final packOfController = TextEditingController();
    final deliveryLocationController = TextEditingController();
    final deliveryDaysController = TextEditingController();
    final aboutSellerController = TextEditingController();
    final overallRatingController = TextEditingController();
    final productQualityController = TextEditingController();
    final serviceQualityController = TextEditingController();
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
                    controller: modelNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Model Number (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'Type (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: shadeController,
                    decoration: const InputDecoration(
                      labelText: 'Shade (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: materialController,
                    decoration: const InputDecoration(
                      labelText: 'Material (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: packOfController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Pack Of (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: deliveryLocationController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Location (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: deliveryDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Working Days (3/4/5/6 optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: aboutSellerController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'About Seller (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: overallRatingController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Overall Rating (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: productQualityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Product Quality Rating (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: serviceQualityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Service Quality Rating (optional)',
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
                final modelNumber = modelNumberController.text.trim();
                final itemType = typeController.text.trim();
                final shade = shadeController.text.trim();
                final material = materialController.text.trim();
                final packOf = packOfController.text.trim();
                final deliveryLocation = deliveryLocationController.text.trim();
                final int? deliveryDays = int.tryParse(
                  deliveryDaysController.text.trim(),
                );
                final aboutSeller = aboutSellerController.text.trim();
                final double? overallRating = double.tryParse(
                  overallRatingController.text.trim(),
                );
                final double? productQuality = double.tryParse(
                  productQualityController.text.trim(),
                );
                final double? serviceQuality = double.tryParse(
                  serviceQualityController.text.trim(),
                );
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
                  modelNumber: modelNumber.isEmpty ? null : modelNumber,
                  itemType: itemType.isEmpty ? null : itemType,
                  shade: shade.isEmpty ? null : shade,
                  material: material.isEmpty ? null : material,
                  packOf: packOf.isEmpty ? null : packOf,
                  deliveryLocation: deliveryLocation.isEmpty
                      ? null
                      : deliveryLocation,
                  deliveryWorkingDays: deliveryDays,
                  aboutSeller: aboutSeller.isEmpty ? null : aboutSeller,
                  overallRating: overallRating,
                  productQuality: productQuality,
                  serviceQuality: serviceQuality,
                  about: about.isEmpty ? null : about,
                  suitableFor: suitableFor.isEmpty ? null : suitableFor,
                  warranty: warranty.isEmpty ? null : warranty,
                  highlights: highlights,
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Item "$name" added to ${category.name}.'),
                  ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Item "${item.name}" removed.')));
    }
  }

  Widget _buildDashboardHero({
    required int categoryCount,
    required int totalItems,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1B2A59), const Color(0xFF3657A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3657A7).withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shop Operations',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage catalog, orders, and delivery timeline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroStat(
                icon: Icons.category_rounded,
                label: 'Categories',
                value: categoryCount.toString(),
              ),
              _heroStat(
                icon: Icons.inventory_2_rounded,
                label: 'Items',
                value: totalItems.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.deepPurple, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Widget _buildAnalyticsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('shopOrders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text('Unable to load analytics: ${snapshot.error}'),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? const [];
        final int totalOrders = docs.length;
        int delivered = 0;
        int cod = 0;
        double revenue = 0;
        final Map<String, int> productCounts = <String, int>{};
        final Map<String, int> categoryCounts = <String, int>{};

        for (final d in docs) {
          final data = d.data();
          final int qty = _asInt(data['quantity'], fallback: 1);
          final double amount = _asDouble(data['totalAmount']);
          revenue += amount;

          final String status = _normalizeOrderStatus(data);
          if (status == 'delivered') {
            delivered++;
          }
          final String method =
              ((data['paymentMethod'] as String?) ?? '').toLowerCase();
          if (method == 'cod') {
            cod++;
          }

          final String itemName = (data['itemName'] as String?) ?? 'Product';
          final String categoryName =
              ((data['categoryName'] ?? data['category']) as String?) ??
              'Category';
          productCounts[itemName] = (productCounts[itemName] ?? 0) + qty;
          categoryCounts[categoryName] = (categoryCounts[categoryName] ?? 0) + 1;
        }

        final int active = totalOrders - delivered;
        final int online = totalOrders - cod;
        final double avgOrderValue = totalOrders == 0 ? 0 : revenue / totalOrders;

        final List<MapEntry<String, int>> topProducts = productCounts.entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final List<MapEntry<String, int>> topCategories = categoryCounts.entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _analyticsMetricCard(
                      label: 'Revenue',
                      value: 'Rs ${revenue.toStringAsFixed(0)}',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _analyticsMetricCard(
                      label: 'Orders',
                      value: totalOrders.toString(),
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _analyticsMetricCard(
                      label: 'AOV',
                      value: 'Rs ${avgOrderValue.toStringAsFixed(0)}',
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _analyticsMetricCard(
                      label: 'Delivered',
                      value: delivered.toString(),
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _analyticsProgressRow(
                label: 'Active vs Delivered',
                leftValue: active,
                rightValue: delivered,
                leftLabel: 'Active',
                rightLabel: 'Delivered',
                color: Colors.orange,
              ),
              const SizedBox(height: 8),
              _analyticsProgressRow(
                label: 'Online vs COD',
                leftValue: online,
                rightValue: cod,
                leftLabel: 'Online',
                rightLabel: 'COD',
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              Text(
                'Top Products',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (topProducts.isEmpty)
                Text(
                  'No order data yet.',
                  style: TextStyle(color: Colors.grey[600]),
                )
              else
                ...topProducts
                    .take(3)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${e.key}  •  ${e.value}',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 10),
              Text(
                'Top Categories',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (topCategories.isEmpty)
                Text(
                  'No category trends yet.',
                  style: TextStyle(color: Colors.grey[600]),
                )
              else
                ...topCategories
                    .take(3)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${e.key}  •  ${e.value}',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
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

  Widget _analyticsMetricCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsProgressRow({
    required String label,
    required int leftValue,
    required int rightValue,
    required String leftLabel,
    required String rightLabel,
    required Color color,
  }) {
    final int total = leftValue + rightValue;
    final double leftRatio = total == 0 ? 0 : leftValue / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: leftRatio.clamp(0, 1),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '$leftLabel: $leftValue',
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '$rightLabel: $rightValue',
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  bool _isUpcomingOrderStatus(String status) {
    final String normalized = status.trim().toLowerCase();
    return normalized != 'delivered' && normalized != 'cancelled';
  }

  bool _hasReturnReplacementRequest(Map<String, dynamic> data) {
    final Map<String, dynamic>? rr = _extractReturnReplacementRequest(data);
    if (rr == null) return false;
    final String rrStatus = ((rr['status'] as String?) ?? '').trim();
    final String rrType = ((rr['requestType'] as String?) ?? '').trim();
    return rrStatus.isNotEmpty && rrType.isNotEmpty;
  }

  bool _matchesRrDateFilter({
    required int requestedAtMs,
    required String dateFilter,
    required DateTime now,
  }) {
    if (dateFilter == 'all') return true;
    if (requestedAtMs <= 0) return false;
    final DateTime requested = DateTime.fromMillisecondsSinceEpoch(requestedAtMs);
    if (dateFilter == 'today') {
      return requested.year == now.year &&
          requested.month == now.month &&
          requested.day == now.day;
    }
    if (dateFilter == 'last_7_days') {
      return now.millisecondsSinceEpoch - requestedAtMs <= 7 * 24 * 60 * 60 * 1000;
    }
    if (dateFilter == 'last_30_days') {
      return now.millisecondsSinceEpoch - requestedAtMs <=
          30 * 24 * 60 * 60 * 1000;
    }
    return true;
  }

  int _rrPriorityScore({
    required bool breached,
  }) {
    if (breached) return 0;
    return 1;
  }

  Future<void> _openManageCatalogQuickAction() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF2F5FB),
          appBar: AppBar(
            title: const Text('Manage Catalog'),
            backgroundColor: const Color(0xFF1B2A59),
            actions: [
              IconButton(
                tooltip: 'Add category',
                onPressed: _showAddCategoryDialog,
                icon: const Icon(Icons.add_box_rounded),
              ),
            ],
          ),
          body: ValueListenableBuilder<List<ShopCategory>>(
            valueListenable: _store.categoriesNotifier,
            builder: (context, categories, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: [
                  _buildSectionHeader(
                    icon: Icons.inventory_2_rounded,
                    title: 'Manage Catalog',
                    subtitle: 'Categories and products overview',
                  ),
                  const SizedBox(height: 10),
                  _buildManageCatalogList(categories),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openOrdersQuickAction({required bool upcomingOnly}) async {
    if (!mounted) return;
    final String title = upcomingOnly ? 'Upcoming Orders' : 'All Orders';
    final String subtitle = upcomingOnly
        ? 'Active orders that are not yet delivered'
        : 'Track progress and update delivery stages';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF2F5FB),
          appBar: AppBar(
            title: Text(title),
            backgroundColor: const Color(0xFF1B2A59),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              _buildSectionHeader(
                icon: Icons.local_shipping_rounded,
                title: title,
                subtitle: subtitle,
              ),
              const SizedBox(height: 10),
              _buildManageOrdersList(upcomingOnly: upcomingOnly),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReturnReplacementQuickAction() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DefaultTabController(
          length: _rrTabKeys.length,
          child: Scaffold(
            backgroundColor: const Color(0xFFF2F5FB),
            appBar: AppBar(
              title: const Text('Manage Return/Replacement'),
              backgroundColor: const Color(0xFF1B2A59),
              bottom: TabBar(
                isScrollable: true,
                tabs: _rrTabKeys.map((key) {
                  final String label = _rrStatusLabel(key);
                  return Tab(text: label);
                }).toList(growable: false),
              ),
            ),
            body: _buildReturnReplacementManagementBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildReturnReplacementManagementBody() {
    String statusFilter = 'all';
    String typeFilter = 'all';
    String dateFilter = 'all';
    String paymentFilter = 'all';
    String customerQuery = '';
    bool highValueOnly = false;

    return StatefulBuilder(
      builder: (context, setPageState) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('shopOrders').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Unable to load requests: ${snapshot.error}'),
              );
            }

            final DateTime now = DateTime.now();
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> allRrDocs =
                (snapshot.data?.docs ?? const [])
                    .where((doc) => _hasReturnReplacementRequest(doc.data()))
                    .toList(growable: false);

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs =
                allRrDocs.where((doc) {
                  final Map<String, dynamic> data = doc.data();
                  final Map<String, dynamic>? rr =
                      _extractReturnReplacementRequest(data);
                  if (rr == null) return false;

                  final String rrType = ((rr['requestType'] as String?) ?? '')
                      .trim()
                      .toLowerCase();
                  final String effectiveStatus = _rrEffectiveTabStatus(rr, data);
                  final int requestedAtMs = _rrRequestedAtMs(rr, data);
                  final String customerText =
                      '${(data['customerEmail'] ?? '')} ${(data['customerId'] ?? '')}'
                          .toLowerCase();
                  final String paymentMethod =
                      ((data['paymentMethod'] as String?) ?? '')
                          .trim()
                          .toLowerCase();
                  final int amount = _asInt(data['totalAmount']);

                  if (statusFilter != 'all' && effectiveStatus != statusFilter) {
                    return false;
                  }
                  if (typeFilter != 'all' && rrType != typeFilter) {
                    return false;
                  }
                  if (!_matchesRrDateFilter(
                    requestedAtMs: requestedAtMs,
                    dateFilter: dateFilter,
                    now: now,
                  )) {
                    return false;
                  }
                  if (paymentFilter == 'cod' && paymentMethod != 'cod') {
                    return false;
                  }
                  if (paymentFilter == 'online' &&
                      (paymentMethod.isEmpty || paymentMethod == 'cod')) {
                    return false;
                  }
                  if (highValueOnly && amount < _highValueThreshold) {
                    return false;
                  }
                  if (customerQuery.isNotEmpty &&
                      !customerText.contains(customerQuery)) {
                    return false;
                  }
                  return true;
                }).toList(growable: true);

            filteredDocs.sort((a, b) {
              final Map<String, dynamic> dataA = a.data();
              final Map<String, dynamic> dataB = b.data();
              final Map<String, dynamic> rrA =
                  _extractReturnReplacementRequest(dataA)!;
              final Map<String, dynamic> rrB =
                  _extractReturnReplacementRequest(dataB)!;

              final int reqA = _rrRequestedAtMs(rrA, dataA);
              final int reqB = _rrRequestedAtMs(rrB, dataB);
              final int dueA = reqA + _rrResponseSlaMs;
              final int dueB = reqB + _rrResponseSlaMs;
              final bool breachedA = _normalizeRrStatus(
                        (rrA['status'] as String?) ?? '',
                      ) ==
                      'requested' &&
                  now.millisecondsSinceEpoch > dueA;
              final bool breachedB = _normalizeRrStatus(
                        (rrB['status'] as String?) ?? '',
                      ) ==
                      'requested' &&
                  now.millisecondsSinceEpoch > dueB;
              final int scoreA = _rrPriorityScore(
                breached: breachedA,
              );
              final int scoreB = _rrPriorityScore(
                breached: breachedB,
              );
              if (scoreA != scoreB) return scoreA.compareTo(scoreB);
              return reqA.compareTo(reqB);
            });

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildRrFilterDropdown(
                              value: statusFilter,
                              label: 'Status',
                              options: const [
                                ('all', 'All'),
                                ('requested', 'Requested'),
                                ('approved', 'Approved'),
                                ('rejected', 'Rejected'),
                                ('in_progress', 'In Progress'),
                                ('completed', 'Completed'),
                              ],
                              onChanged: (v) => setPageState(
                                () => statusFilter = v ?? 'all',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRrFilterDropdown(
                              value: typeFilter,
                              label: 'Type',
                              options: const [
                                ('all', 'All'),
                                ('return', 'Return'),
                                ('replacement', 'Replacement'),
                              ],
                              onChanged: (v) =>
                                  setPageState(() => typeFilter = v ?? 'all'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRrFilterDropdown(
                              value: dateFilter,
                              label: 'Date',
                              options: const [
                                ('all', 'All'),
                                ('today', 'Today'),
                                ('last_7_days', 'Last 7 Days'),
                                ('last_30_days', 'Last 30 Days'),
                              ],
                              onChanged: (v) =>
                                  setPageState(() => dateFilter = v ?? 'all'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRrFilterDropdown(
                              value: paymentFilter,
                              label: 'Payment',
                              options: const [
                                ('all', 'All'),
                                ('cod', 'COD'),
                                ('online', 'Online'),
                              ],
                              onChanged: (v) => setPageState(
                                () => paymentFilter = v ?? 'all',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (value) => setPageState(
                          () => customerQuery = value.trim().toLowerCase(),
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Filter by customer',
                          hintText: 'Email or customer ID',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('High value orders only'),
                        subtitle: Text('>= Rs $_highValueThreshold'),
                        value: highValueOnly,
                        onChanged: (value) =>
                            setPageState(() => highValueOnly = value),
                      ),
                      _buildReturnReplacementAnalytics(filteredDocs),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: _rrTabKeys.map((tabKey) {
                      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      tabDocs = filteredDocs.where((doc) {
                        final Map<String, dynamic> data = doc.data();
                        final Map<String, dynamic>? rr =
                            _extractReturnReplacementRequest(data);
                        if (rr == null) return false;
                        return _rrEffectiveTabStatus(rr, data) == tabKey;
                      }).toList(growable: false);

                      if (tabDocs.isEmpty) {
                        return Center(
                          child: Text(
                            'No ${_rrStatusLabel(tabKey).toLowerCase()} requests.',
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                        itemCount: tabDocs.length,
                        itemBuilder: (context, index) {
                          final doc = tabDocs[index];
                          final data = doc.data();
                          final rr = _extractReturnReplacementRequest(data)!;
                          return _buildReturnReplacementPriorityCard(
                            doc: doc,
                            orderData: data,
                            rr: rr,
                          );
                        },
                      );
                    }).toList(growable: false),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRrFilterDropdown({
    required String value,
    required String label,
    required List<(String, String)> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: options
          .map(
            (e) => DropdownMenuItem<String>(
              value: e.$1,
              child: Text(e.$2),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  Widget _buildReturnReplacementAnalytics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int total = 0;
    int approved = 0;
    int rejected = 0;
    int completed = 0;
    int last7Days = 0;
    int completionSamples = 0;
    int totalCompletionMs = 0;
    int refundAmount = 0;
    final Map<String, int> reasonCounts = <String, int>{};
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final d in docs) {
      final Map<String, dynamic> data = d.data();
      final Map<String, dynamic>? rr = _extractReturnReplacementRequest(data);
      if (rr == null) continue;
      total++;
      final String status = _rrEffectiveTabStatus(rr, data);
      final String rrType = ((rr['requestType'] as String?) ?? '')
          .trim()
          .toLowerCase();
      final int requestedAt = _rrRequestedAtMs(rr, data);
      if (requestedAt > 0 &&
          nowMs - requestedAt <= 7 * 24 * 60 * 60 * 1000) {
        last7Days++;
      }
      if (status == 'approved' ||
          status == 'in_progress' ||
          status == 'completed') {
        approved++;
      }
      if (status == 'rejected') {
        rejected++;
      }
      if (status == 'completed') {
        completed++;
        final int completedAt = _asInt(rr['completedAtLocalMs'], fallback: 0);
        if (requestedAt > 0 && completedAt > requestedAt) {
          completionSamples++;
          totalCompletionMs += completedAt - requestedAt;
        }
        if (rrType == 'return') {
          final Map<String, bool> checkpoints = _rrCheckpoints(rr);
          if (checkpoints['refundProcessed'] == true ||
              _asInt(rr['refundAtLocalMs'], fallback: 0) > 0) {
            refundAmount += _asInt(data['totalAmount']);
          }
        }
      }

      final String reason = ((rr['reason'] as String?) ?? '')
          .trim()
          .toLowerCase();
      if (reason.isNotEmpty) {
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
      }
    }

    final double approvalPct = total == 0 ? 0 : (approved * 100) / total;
    final double rejectionPct = total == 0 ? 0 : (rejected * 100) / total;
    final double requestRate = last7Days / 7;
    final String avgCompletionText = completionSamples == 0
        ? '-'
        : _formatDurationCompact((totalCompletionMs / completionSamples).round());

    final List<MapEntry<String, int>> topReasons = reasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRrMetricChip(
                icon: Icons.speed_rounded,
                label: 'Req/day',
                value: requestRate.toStringAsFixed(1),
                color: Colors.indigo,
              ),
              _buildRrMetricChip(
                icon: Icons.check_circle_rounded,
                label: 'Approval %',
                value: approvalPct.toStringAsFixed(1),
                color: Colors.green,
              ),
              _buildRrMetricChip(
                icon: Icons.cancel_rounded,
                label: 'Rejection %',
                value: rejectionPct.toStringAsFixed(1),
                color: Colors.red,
              ),
              _buildRrMetricChip(
                icon: Icons.timelapse_rounded,
                label: 'Avg Completion',
                value: avgCompletionText,
                color: Colors.deepPurple,
              ),
              _buildRrMetricChip(
                icon: Icons.currency_rupee_rounded,
                label: 'Refund Amount',
                value: refundAmount.toString(),
                color: Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            topReasons.isEmpty
                ? 'Top return reasons: -'
                : 'Top return reasons: ${topReasons.take(3).map((e) => '${e.key} (${e.value})').join(', ')}',
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRrMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnReplacementPriorityCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> rr,
  }) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String rrType = ((rr['requestType'] as String?) ?? '')
        .trim()
        .toLowerCase();
    final String rrStatus = _normalizeRrStatus((rr['status'] as String?) ?? '');
    final int requestedAt = _rrRequestedAtMs(rr, orderData);
    final int responseDueMs =
        requestedAt > 0 ? requestedAt + _rrResponseSlaMs : 0;
    final bool breached =
        rrStatus == 'requested' && responseDueMs > 0 && nowMs > responseDueMs;
    final int requestAgeMs = requestedAt > 0 ? nowMs - requestedAt : 0;
    final bool isReplacement = rrType == 'replacement';
    final bool stockAvailable =
        !isReplacement || _isReplacementStockAvailable(orderData);
    final String orderId = ((orderData['orderId'] as String?) ?? doc.id).trim();
    final String orderCode = ((orderData['orderCode'] as String?) ?? '-').trim();
    final String itemName = ((orderData['itemName'] as String?) ?? 'Product').trim();
    final String customer =
        ((orderData['customerEmail'] ?? orderData['customerId']) ?? '-')
            .toString()
            .trim();
    final String reason = ((rr['reason'] as String?) ?? '').trim();
    final int amount = _asInt(orderData['totalAmount']);
    final List<Map<String, dynamic>> trail = _rrAuditTrail(rr)
      ..sort(
        (a, b) => _asInt(
          b['atMs'],
          fallback: 0,
        ).compareTo(_asInt(a['atMs'], fallback: 0)),
      );
    final Map<String, bool> checkpoints = _rrCheckpoints(rr);

    final Color urgencyColor = breached ? Colors.red : Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: urgencyColor.withOpacity(0.55),
          width: breached ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                      fontSize: 15.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _rrStatusColor(rrStatus).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _rrStatusLabel(rrStatus),
                    style: TextStyle(
                      color: _rrStatusColor(rrStatus),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Order: $orderId  |  Code: $orderCode'),
            Text('Customer: $customer'),
            Text('Type: ${_rrTypeLabel(rrType)}  |  Amount: Rs $amount'),
            if (reason.isNotEmpty) Text('Reason: $reason'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    requestedAt > 0
                        ? 'Requested: ${_formatMs(requestedAt)}'
                        : 'Requested: -',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  breached ? 'SLA: Breached' : 'SLA: On track',
                  style: TextStyle(
                    color: urgencyColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Request age: ${_formatDurationCompact(requestAgeMs)}  |  Response due: ${responseDueMs > 0 ? _formatMs(responseDueMs) : '-'}',
              style: TextStyle(
                color: breached ? Colors.red : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isReplacement) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: (stockAvailable ? Colors.green : Colors.red)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (stockAvailable ? Colors.green : Colors.red)
                        .withOpacity(0.35),
                  ),
                ),
                child: Text(
                  stockAvailable ? 'Stock available' : 'Stock unavailable',
                  style: TextStyle(
                    color: stockAvailable ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (rrStatus == 'requested') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: stockAvailable || !isReplacement
                          ? () => _updateReturnReplacementRequestStatus(
                                orderDocId: doc.id,
                                orderData: orderData,
                                nextStatus: 'approved',
                              )
                          : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final String? reasonNote = await _openRejectReasonDialog();
                        if (reasonNote == null) return;
                        await _updateReturnReplacementRequestStatus(
                          orderDocId: doc.id,
                          orderData: orderData,
                          nextStatus: 'rejected',
                          note: reasonNote,
                        );
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.35)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (rrStatus == 'approved') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _updateReturnReplacementRequestStatus(
                    orderDocId: doc.id,
                    orderData: orderData,
                    nextStatus: 'in_progress',
                  ),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Mark In Progress'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (rrStatus == 'in_progress') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateReturnReplacementRequestStatus(
                    orderDocId: doc.id,
                    orderData: orderData,
                    nextStatus: 'completed',
                  ),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Mark Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (rrType == 'return' &&
                (rrStatus == 'approved' ||
                    rrStatus == 'in_progress' ||
                    rrStatus == 'completed')) ...[
              const Text(
                'Return checkpoints',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _returnCheckpointDefs.map((def) {
                  final String key = def['key']!;
                  final String label = def['label']!;
                  final bool done = checkpoints[key] == true;
                  final bool canTap = _isCheckpointActionAllowed(checkpoints, key);
                  return FilterChip(
                    selected: done,
                    label: Text(label),
                    selectedColor: Colors.green.withOpacity(0.2),
                    onSelected: (!done && canTap)
                        ? (_) => _updateReturnCheckpoint(
                              orderDocId: doc.id,
                              orderData: orderData,
                              checkpointKey: key,
                            )
                        : null,
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 8),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Audit Trail',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              children: trail.isEmpty
                  ? [
                      ListTile(
                        dense: true,
                        title: Text(
                          'No audit entries yet.',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ]
                  : trail.map((entry) {
                      final int at = _asInt(entry['atMs'], fallback: 0);
                      final String who = (entry['by'] ?? '-').toString();
                      final String action = (entry['action'] ?? '-').toString();
                      final String status = (entry['status'] ?? '').toString();
                      final String checkpoint =
                          (entry['checkpoint'] ?? '').toString();
                      final String note = (entry['note'] ?? '').toString();
                      final String detail = status.isNotEmpty
                          ? status
                          : (checkpoint.isNotEmpty ? checkpoint : '');
                      return ListTile(
                        dense: true,
                        title: Text(
                          detail.isEmpty ? action : '$action: $detail',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${at > 0 ? _formatMs(at) : '-'} | by $who${note.isNotEmpty ? ' | $note' : ''}',
                        ),
                      );
                    }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageCatalogList(List<ShopCategory> categories) {
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text('No categories yet. Tap + to add one.'),
      );
    }

    return Column(
      children: categories.map((category) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: CircleAvatar(
              backgroundColor: category.accentColor.withOpacity(0.16),
              child: ClipOval(
                child: Image.network(
                  category.effectiveImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(category.icon, color: category.accentColor),
                ),
              ),
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
            children: [
              ...category.items.map((item) {
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Rs ${item.price}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
      }).toList(),
    );
  }

  Widget _buildManageOrdersList({
    required bool upcomingOnly,
    bool returnReplacementOnly = false,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('shopOrders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text('Unable to load orders: ${snapshot.error}'),
          );
        }

        final allDocs = snapshot.data?.docs.toList() ?? [];
        allDocs.sort((a, b) {
          final int ta = _asInt(a.data()['createdAtLocalMs']);
          final int tb = _asInt(b.data()['createdAtLocalMs']);
          return tb.compareTo(ta);
        });

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> byStatus = upcomingOnly
            ? allDocs.where((doc) {
                final String status = _normalizeOrderStatus(doc.data());
                return _isUpcomingOrderStatus(status);
              }).toList(growable: false)
            : allDocs;

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            returnReplacementOnly
                ? byStatus
                    .where((doc) => _hasReturnReplacementRequest(doc.data()))
                    .toList(growable: false)
                : byStatus;

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              returnReplacementOnly
                  ? 'No return/replacement requests yet.'
                  : upcomingOnly
                  ? 'No upcoming orders right now.'
                  : 'No shop orders yet.',
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final String itemName = (data['itemName'] as String?) ?? 'Product';
            final String customerEmail = (data['customerEmail'] as String?) ?? '-';
            final int amount = _asInt(data['totalAmount']);
            final String status = _normalizeOrderStatus(data);
            final int idx = _statusIndex(status);
            final bool completed =
                status == 'cancelled' || idx >= _orderFlow.length - 1;
            final double progress = status == 'cancelled'
                ? 0
                : (_orderFlow.length - 1) == 0
                    ? 0
                    : idx / (_orderFlow.length - 1);
            final Map<String, dynamic>? rr =
                _extractReturnReplacementRequest(data);
            final String rrType = ((rr?['requestType'] as String?) ?? '')
                .trim()
                .toLowerCase();
            final String rrStatus = ((rr?['status'] as String?) ?? '')
                .trim()
                .toLowerCase();
            final String rrReason = ((rr?['reason'] as String?) ?? '').trim();
            final int rrRequestedAt = _asInt(
              rr?['requestedAtLocalMs'],
              fallback: 0,
            );
            final bool hasRr = rr != null && rrStatus.isNotEmpty;
            final bool canApproveReject = rrStatus == 'requested';
            final bool canProgressRr =
                rrStatus == 'approved' || rrStatus == 'in_progress';
            final String nextRrStatus = _nextReturnReplacementStatus(rrStatus);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(13),
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
                              fontSize: 15.5,
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
                    if (hasRr) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.deepPurple.withOpacity(0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_rrTypeLabel(rrType)} Request',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _rrStatusColor(rrStatus)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _rrStatusLabel(rrStatus),
                                    style: TextStyle(
                                      color: _rrStatusColor(rrStatus),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (rrReason.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                rrReason,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (rrRequestedAt > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Requested on ${_formatMs(rrRequestedAt)}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepPurple,
                                  side: BorderSide(
                                    color: Colors.deepPurple.withOpacity(0.35),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showOrderTimelineSheet(data),
                                icon: const Icon(Icons.timeline_rounded),
                                label: const Text('Timeline'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepPurple,
                                  side: BorderSide(
                                    color: Colors.deepPurple.withOpacity(0.35),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (hasRr && canApproveReject) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateReturnReplacementRequestStatus(
                                        orderDocId: doc.id,
                                        orderData: data,
                                        nextStatus: 'approved',
                                      ),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final String? reasonNote =
                                        await _openRejectReasonDialog();
                                    if (reasonNote == null) return;
                                    await _updateReturnReplacementRequestStatus(
                                      orderDocId: doc.id,
                                      orderData: data,
                                      nextStatus: 'rejected',
                                      note: reasonNote,
                                    );
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: BorderSide(
                                      color: Colors.red.withOpacity(0.35),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (hasRr && canProgressRr) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _updateReturnReplacementRequestStatus(
                                    orderDocId: doc.id,
                                    orderData: data,
                                    nextStatus: nextRrStatus,
                                  ),
                              icon: Icon(
                                nextRrStatus == 'completed'
                                    ? Icons.task_alt_rounded
                                    : Icons.sync_rounded,
                              ),
                              label: Text(
                                nextRrStatus == 'completed'
                                    ? 'Mark ${_rrTypeLabel(rrType)} Completed'
                                    : 'Mark ${_rrTypeLabel(rrType)} In Progress',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.deepPurple,
                                side: BorderSide(
                                  color: Colors.deepPurple.withOpacity(0.35),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
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
                            label: Text(completed ? 'Completed' : 'Next Step'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
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
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FB),
      appBar: AppBar(
        title: const Text('Shop Manager'),
        backgroundColor: const Color(0xFF1B2A59),
        elevation: 0,
        scrolledUnderElevation: 0,
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
              _buildDashboardHero(
                categoryCount: categories.length,
                totalItems: totalItems,
              ),
              const SizedBox(height: 14),
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
              _buildSectionHeader(
                icon: Icons.flash_on_rounded,
                title: 'Quick Actions',
                subtitle: 'Fast access to key shop controls',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.local_shipping_rounded,
                      title: 'All Orders',
                      subtitle: 'View and manage every order',
                      color: Colors.indigo,
                      onTap: () => _openOrdersQuickAction(upcomingOnly: false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.upcoming_rounded,
                      title: 'Upcoming Orders',
                      subtitle: 'Only active, not yet delivered',
                      color: Colors.orange,
                      onTap: () => _openOrdersQuickAction(upcomingOnly: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.add_box_rounded,
                      title: 'Add Category',
                      subtitle: 'Create a new catalog category',
                      color: Colors.deepPurple,
                      onTap: _showAddCategoryDialog,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'Manage Catalog',
                      subtitle: 'Open categories and items management',
                      color: Colors.teal,
                      onTap: _openManageCatalogQuickAction,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _buildQuickActionCard(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Manage Return/Replacement',
                  subtitle: 'Handle all return and replacement requests',
                  color: Colors.deepPurple,
                  onTap: _openReturnReplacementQuickAction,
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader(
                icon: Icons.inventory_2_rounded,
                title: 'Catalog Overview',
                subtitle:
                    'Use Quick Actions > Manage Catalog to view categories and items',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  categories.isEmpty
                      ? 'No categories yet. Use Quick Actions to add and manage your catalog.'
                      : '${categories.length} categories and $totalItems items in catalog.',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildSectionHeader(
                icon: Icons.insights_rounded,
                title: 'Order Insights',
                subtitle:
                    'Use Quick Actions > All Orders to view and manage customer orders',
              ),
              const SizedBox(height: 10),
              _buildAnalyticsSection(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: const Color(0xFF1B2A59),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
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
