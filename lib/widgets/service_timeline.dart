import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ServiceTimeline extends StatelessWidget {
  final String? userId;
  final int? itemLimit;
  final bool showHeader;
  final bool showViewAll;
  final VoidCallback? onViewAll;

  const ServiceTimeline({
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Service Timeline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (showViewAll && onViewAll != null)
                      TextButton(
                        onPressed: onViewAll,
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

      return _TimelineItem(
        status: status,
        serviceName: serviceName,
        providerName: providerName,
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

class _TimelineItem extends StatelessWidget {
  final String status;
  final String serviceName;
  final String providerName;
  final DateTime date;
  final VoidCallback onTap;

  const _TimelineItem({
    Key? key,
    required this.status,
    required this.serviceName,
    required this.providerName,
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'With $providerName',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(date),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
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
          'color': Colors.deepPurple,
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
