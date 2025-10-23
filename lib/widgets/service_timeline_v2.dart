import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ServiceTimelineV2 extends StatelessWidget {
  final String? userId;
  final int? itemLimit;
  final bool showHeader;
  final bool showViewAll;
  final VoidCallback? onViewAll;

  const ServiceTimelineV2({
    Key? key,
    required this.userId,
    this.itemLimit = 5,
    this.showHeader = true,
    this.showViewAll = true,
    this.onViewAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_requests')
          .where('customerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(itemLimit!)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final services = snapshot.data!.docs;
        if (services.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    if (showViewAll && onViewAll != null)
                      TextButton(
                        onPressed: onViewAll,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6C63FF),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('View All'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            ..._buildTimelineItems(services, context),
          ],
        );
      },
    );
  }

  List<Widget> _buildTimelineItems(List<QueryDocumentSnapshot> services, BuildContext context) {
    return services.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'pending';
      final serviceName = data['serviceName'] ?? 'Service';
      final providerName = data['providerName'] ?? 'Provider';
      final date = (data['serviceDate'] as Timestamp?)?.toDate() ?? DateTime.now();
      final serviceType = data['serviceType'] ?? 'Cleaning';
      final price = data['price']?.toStringAsFixed(2) ?? '0.00';

      return _TimelineItemV2(
        status: status,
        serviceName: serviceName,
        providerName: providerName,
        serviceType: serviceType,
        price: price,
        date: date,
        onTap: () {
          // Navigate to service details
          Navigator.pushNamed(
            context,
            '/service-details',
            arguments: doc.id,
          );
        },
      );
    }).toList();
  }
}

class _TimelineItemV2 extends StatelessWidget {
  final String status;
  final String serviceName;
  final String providerName;
  final String serviceType;
  final String price;
  final DateTime date;
  final VoidCallback onTap;

  const _TimelineItemV2({
    Key? key,
    required this.status,
    required this.serviceName,
    required this.providerName,
    required this.serviceType,
    required this.price,
    required this.date,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();
    final statusColor = config['color'] as Color;
    final statusIcon = config['icon'] as IconData;
    final statusLabel = config['label'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Service Type Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cleaning_services, color: Color(0xFF6C63FF)),
                  ),
                  const SizedBox(width: 12),
                  // Service Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF2D2D2D),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'With $providerName',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Timeline
              Row(
                children: [
                  _buildTimelineStep(
                    'Requested',
                    Icons.check_circle,
                    isActive: true,
                    isCompleted: _isStepCompleted('requested'),
                  ),
                  _buildTimelineConnector(isActive: _isStepCompleted('requested')),
                  _buildTimelineStep(
                    'Accepted',
                    Icons.check_circle,
                    isActive: _isStepCompleted('accepted'),
                    isCompleted: _isStepCompleted('accepted'),
                  ),
                  _buildTimelineConnector(isActive: _isStepCompleted('accepted')),
                  _buildTimelineStep(
                    'In Progress',
                    Icons.check_circle,
                    isActive: _isStepCompleted('in_progress'),
                    isCompleted: _isStepCompleted('in_progress'),
                  ),
                  _buildTimelineConnector(isActive: _isStepCompleted('in_progress')),
                  _buildTimelineStep(
                    'Completed',
                    Icons.check_circle,
                    isActive: _isStepCompleted('completed'),
                    isCompleted: _isStepCompleted('completed'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Service Type and Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        serviceType,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '\$$price',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep(String label, IconData icon, {bool isActive = false, bool isCompleted = false}) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFF6C63FF) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? const Color(0xFF2D2D2D) : Colors.grey[400],
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector({bool isActive = false}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: isActive ? const Color(0xFF6C63FF) : Colors.grey[200],
      ),
    );
  }

  bool _isStepCompleted(String step) {
    final stepOrder = ['requested', 'accepted', 'in_progress', 'completed'];
    final currentStepIndex = stepOrder.indexOf(status);
    final targetStepIndex = stepOrder.indexOf(step);
    
    if (currentStepIndex == -1 || targetStepIndex == -1) return false;
    return currentStepIndex >= targetStepIndex;
  }

  Map<String, dynamic> _getStatusConfig() {
    switch (status) {
      case 'pending':
        return {
          'color': Colors.orange,
          'icon': Icons.pending_actions_rounded,
          'label': 'Pending',
        };
      case 'accepted':
        return {
          'color': Colors.blue,
          'icon': Icons.check_circle_outline_rounded,
          'label': 'Accepted',
        };
      case 'in_progress':
        return {
          'color': const Color(0xFF6C63FF),
          'icon': Icons.build_circle_outlined,
          'label': 'In Progress',
        };
      case 'completed':
        return {
          'color': Colors.green,
          'icon': Icons.verified_rounded,
          'label': 'Completed',
        };
      case 'cancelled':
        return {
          'color': Colors.red,
          'icon': Icons.cancel_outlined,
          'label': 'Cancelled',
        };
      default:
        return {
          'color': Colors.grey,
          'icon': Icons.help_outline_rounded,
          'label': 'Unknown',
        };
    }
  }
}
