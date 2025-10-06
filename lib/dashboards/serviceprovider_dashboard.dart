// lib/dashboards/serviceprovider_dashboard.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // <-- Make sure this import is added
import 'package:serviceprovider/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../create_service_screen.dart';
import '../manage_services_screen.dart';
import '../service_provider_profile_screen.dart';
import '../map_webview_screen.dart';
import '../pending_requests_screen.dart';
import '../provider_availability_screen.dart';
import '../provider_notifications_screen.dart';
import '../booking_detail_screen.dart';
import '../on_time_bookings_screen.dart';

class ServiceProviderDashboard extends StatefulWidget {
  const ServiceProviderDashboard({super.key});

  @override
  State<ServiceProviderDashboard> createState() => _ServiceProviderDashboardState();
}

class _ServiceProviderDashboardState extends State<ServiceProviderDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isApproved = false;
  String _username = 'Service Provider';
  String? _profileImageUrl;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _isApproved = data['isApproved'] ?? false;
            _username = data['username'] ?? 'Service Provider';
            _profileImageUrl = data['profileImageUrl'];
            _isLoading = false;
            _pages = [
              _DashboardHomeTab(username: _username, profileImageUrl: _profileImageUrl),
              const _ManageBookingsTab(), // This will now be the updated widget
              const ServiceProviderProfileScreen(),
            ];
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error checking approval status: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isApproved ? _buildApprovedDashboard() : _buildPendingScreen();
  }

  Widget _buildApprovedDashboard() {
    return WillPopScope(
      onWillPop: () async {
        // If not on the first tab, go back to Dashboard tab instead of popping to auth
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey[600],
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: 'Bookings'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 80, color: Colors.orangeAccent),
                const SizedBox(height: 24),
                const Text("Approval Pending", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  "Welcome, $_username! Your account is under review by the admin. We'll notify you upon approval.",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Earnings KPIs (month earnings + completed jobs) ---
class _EarningsSummaryKpis extends StatelessWidget {
  const _EarningsSummaryKpis();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final firstOfNextMonth = DateTime(now.month == 12 ? now.year + 1 : now.year, now.month == 12 ? 1 : now.month + 1, 1);

    // Use completedAt window so KPIs update immediately when a job is marked completed
    final query = FirebaseFirestore.instance
        .collection('serviceRequests')
        .where('providerId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstOfMonth))
        .where('completedAt', isLessThan: Timestamp.fromDate(firstOfNextMonth));

    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: LinearProgressIndicator(minHeight: 2),
            );
          }

          double earnings = 0.0;
          int jobs = 0;
          if (snapshot.hasData) {
            final docs = snapshot.data!.docs;
            jobs = docs.length;
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              final amount = (data['finalAmount'] ?? data['quotedAmount'])?.toDouble();
              if (amount != null) earnings += amount;
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.5,
              ),
              children: [
                _InfoCard(title: 'Earnings (This Month)', value: earnings.toStringAsFixed(2), icon: Icons.payments, color: Colors.indigo),
                _InfoCard(title: 'Completed (This Month)', value: jobs.toString(), icon: Icons.task_alt, color: Colors.green),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- DASHBOARD HOME TAB WIDGET (Unchanged) ---
class _DashboardHomeTab extends StatelessWidget {
  final String username;
  final String? profileImageUrl;

  const _DashboardHomeTab({required this.username, this.profileImageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            _buildCurvedHeader(context),
            _buildSectionTitle("At a Glance"),
            _buildKpiGrid(),
            _buildSectionTitle("Performance"),
            const _EarningsSummaryKpis(),
            _buildActionRequiredCard(context),
            _buildSectionTitle("Manage Business"),
            _buildQuickActionsGrid(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCurvedHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: ClipPath(
        clipper: _AppBarClipper(),
        child: Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: Image.asset('assets/header_pattern.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox()),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 24,
                  right: 24,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Welcome back,", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18)),
                          Text(
                            username,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _NotificationsBell(),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                      child: profileImageUrl == null ? const Icon(Icons.person, size: 35, color: Colors.white) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
        child: Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),
      ),
    );
  }
  
  Widget _buildKpiGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
        children: [
          _InfoCard(title: 'Completed Jobs', value: '156', icon: Icons.check_circle, color: Colors.green),
          _InfoCard(title: 'Your Rating', value: '4.8 ★', icon: Icons.star, color: Colors.amber),
        ],
      ),
    );
  }

  Widget _buildActionRequiredCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
             gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.orange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: ListTile(
            leading: const Icon(Icons.notifications_active, color: Colors.white, size: 30),
            title: const Text("3 New Requests", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
            subtitle: Text("Respond now to improve your rating", style: TextStyle(color: Colors.white.withOpacity(0.9))),
            trailing: const Icon(Icons.arrow_forward, color: Colors.white),
            onTap: () {
                // Navigate to dedicated Pending Requests screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PendingRequestsScreen()),
                );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
        children: [
          _ActionCard(
            title: "Add New Service",
            icon: Icons.add_circle,
            color: Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateServiceScreen())),
          ),
          _ActionCard(
            title: "Manage My Services",
            icon: Icons.edit_note,
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageServicesScreen())),
          ),
          _ActionCard(
            title: "Manage Availability",
            icon: Icons.schedule,
            color: Colors.deepPurple,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderAvailabilityScreen())),
          ),
          _ActionCard(
            title: "Notifications",
            icon: Icons.notifications,
            color: Colors.orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderNotificationsScreen())),
          ),
          _ActionCard(
            title: "On Time Service Requests",
            icon: Icons.access_time_filled,
            color: Colors.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnTimeBookingsScreen())),
          ),
        ],
      ),
    );
  }
}

// Bell icon with unread badge for notifications
class _NotificationsBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .limit(50)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) count = snapshot.data!.docs.length;
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProviderNotificationsScreen()),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(Icons.notifications, color: Colors.white, size: 26),
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

// --- ▼▼▼ BOOKINGS TAB WIDGET (FULLY UPDATED) ▼▼▼ ---
class _ManageBookingsTab extends StatefulWidget {
  const _ManageBookingsTab();

  @override
  State<_ManageBookingsTab> createState() => _ManageBookingsTabState();
}

class _ManageBookingsTabState extends State<_ManageBookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bookings'),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BookingList(status: 'pending'),
          _BookingList(status: 'accepted'),
          _BookingList(status: 'completed'),
        ],
      ),
    );
  }
}

// --- REUSABLE WIDGET TO DISPLAY BOOKING LISTS ---
class _BookingList extends StatelessWidget {
  final String status;

  const _BookingList({required this.status});

  Future<void> _updateRequestStatus(String docId, String newStatus) async {
    final Map<String, dynamic> updates = {'status': newStatus};
    if (newStatus == 'accepted') {
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'completed') {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }
    final docRef = FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(docId);
    await docRef.update(updates);

    // Create a notification for the customer to reflect provider action
    try {
      final snap = await docRef.get();
      final data = snap.data() as Map<String, dynamic>?;
      if (data != null) {
        final String? customerId = data['customerId'] as String?;
        final String serviceName = (data['serviceName'] as String?) ?? 'Your booking';
        if (customerId != null && customerId.isNotEmpty) {
          String title;
          String body;
          if (newStatus == 'accepted') {
            title = 'Booking accepted';
            body = 'Your request for $serviceName was accepted';
          } else if (newStatus == 'completed') {
            title = 'Booking completed';
            body = '$serviceName has been marked completed';
          } else if (newStatus == 'rejected') {
            title = 'Booking rejected';
            body = 'Your request for $serviceName was rejected';
          } else {
            title = 'Booking update';
            body = 'Status changed to $newStatus for $serviceName';
          }
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': customerId,
            'createdBy': FirebaseAuth.instance.currentUser?.uid,
            'type': 'booking_status',
            'title': title,
            'body': body,
            'relatedId': docId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {
      // ignore notification errors to avoid blocking status updates
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('providerId', isEqualTo: user.uid)
          .where('status', isEqualTo: status)
          .orderBy('scheduledDateTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('An error occurred.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No $status requests found.'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildBookingCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildBookingCard(
      BuildContext context, String docId, Map<String, dynamic> data) {
    final scheduledDate = (data['scheduledDateTime'] as Timestamp).toDate();
    final scheduledDateStr = DateFormat.yMMMd().format(scheduledDate);
    final scheduledTimeStr = DateFormat.jm().format(scheduledDate);

    DateTime? requestedDate;
    String? requestedDateStr;
    String? requestedTimeStr;
    final bookingTs = data['bookingTimestamp'];
    if (bookingTs is Timestamp) {
      requestedDate = bookingTs.toDate();
      requestedDateStr = DateFormat.yMMMd().format(requestedDate);
      requestedTimeStr = DateFormat.jm().format(requestedDate);
    }

    // Additional details for richer cards
    final String? addressStr = (data['addressSnapshot'] is Map<String, dynamic>)
        ? ((
                ((data['addressSnapshot']['addressLine'] ?? '') as String) +
                ((((data['addressSnapshot']['city'] ?? '') as String).isNotEmpty)
                    ? ', ${data['addressSnapshot']['city']}'
                    : '') +
                ((((data['addressSnapshot']['pincode'] ?? '') as String).isNotEmpty)
                    ? ', ${data['addressSnapshot']['pincode']}'
                    : '') +
                ((((data['addressSnapshot']['landmark'] ?? '') as String).isNotEmpty)
                    ? ' • ${data['addressSnapshot']['landmark']}'
                    : ''))
            .trim())
        : (data['address'] as String?);

    final String? estimatedDuration = _pickFirstString([
      data['estimatedDuration'],
      data['estimated_time'],
      data['timeEstimate'],
      data['duration'],
      data['expectedDuration'],
      data['durationText'],
      (data['durationMinutes'] != null) ? "${data['durationMinutes']} mins" : null,
      (data['estimatedDurationDays'] != null) ? "${data['estimatedDurationDays']} day(s)" : null,
    ]);

    final double? quoted = _toDouble(data['quotedAmount']);
    final double? finalAmt = _toDouble(data['finalAmount']);
    final int photoCount = (((data['imageUrls'] as List?)?.length) ?? 0) +
        (((data['attachments'] as List?)?.length) ?? 0);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailScreen(requestId: docId),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['serviceName'] ?? 'No Service Name',
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              _CustomerDetailsSection(
                customerId: data['customerId'],
                fallbackName: data['customerName'] ?? 'Customer',
                bookingData: data,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.event,
                text: '$scheduledDateStr at $scheduledTimeStr',
              ),
              if (requestedDateStr != null && requestedTimeStr != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: _InfoRow(
                    icon: Icons.schedule,
                    text: 'Requested: $requestedDateStr at $requestedTimeStr',
                  ),
                ),
              if (addressStr != null && addressStr.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: addressStr,
                  ),
                ),
              if (estimatedDuration != null && estimatedDuration.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: _InfoRow(
                    icon: Icons.timer_outlined,
                    text: 'Estimated: $estimatedDuration',
                  ),
                ),
              if (quoted != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: _InfoRow(
                    icon: Icons.request_quote,
                    text: 'Quote: ${quoted.toStringAsFixed(2)}',
                  ),
                ),
              if (finalAmt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: _InfoRow(
                    icon: Icons.payments_outlined,
                    text: 'Final: ${finalAmt.toStringAsFixed(2)}',
                  ),
                ),
              if (photoCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: _InfoRow(
                    icon: Icons.photo_library_outlined,
                    text: '$photoCount photo(s)',
                  ),
                ),
              const SizedBox(height: 12),
              _buildActionButtons(docId),
            ],
          ),
        ),
      ),
    );
  }

  // --- lightweight helpers ---
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String? _pickFirstString(List<dynamic?> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      final s = c.toString();
      if (s.trim().isNotEmpty) return s;
    }
    return null;
  }

  Widget _buildActionButtons(String docId) {
    if (status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => _updateRequestStatus(docId, 'rejected'),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _updateRequestStatus(docId, 'accepted'),
            child: const Text('Accept'),
          ),
        ],
      );
    } else if (status == 'accepted') {
      return Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Mark as Complete'),
          onPressed: () => _updateRequestStatus(docId, 'completed'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      );
    } else {
      return const Align(
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
      );
    }
  }
}

// Helper widget for info rows
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}

// Enriched customer details section shown inside each booking card
class _CustomerDetailsSection extends StatelessWidget {
  final String customerId;
  final String fallbackName;
  final Map<String, dynamic> bookingData;
  const _CustomerDetailsSection({required this.customerId, required this.fallbackName, required this.bookingData});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        String displayName = fallbackName;
        String? email;
        String? phone;
        String? address;
        String? profileImageUrl;
        GeoPoint? geo;

        if (snapshot.hasData && snapshot.data?.data() != null) {
          final data = snapshot.data!.data()!;
          final username = data['username'] as String?;
          if (username != null && username.trim().isNotEmpty) {
            displayName = username;
          }
          email = data['email'] as String?;
          phone = data['phone'] as String?;
          address = data['address'] as String?;
          profileImageUrl = data['profileImageUrl'] as String?;
          final locField = data['location'];
          if (locField is GeoPoint) {
            geo = locField;
          }
        }

        // Booking-specific fields (from snapshot at request time)
        final Map<String, dynamic>? contact = bookingData['contact'] is Map<String, dynamic>
            ? bookingData['contact'] as Map<String, dynamic>
            : null;
        final String? contactName = contact != null ? contact['name']?.toString() : null;
        final String? contactPhone = contact != null ? contact['phone']?.toString() : null;
        final String? accessNotes = bookingData['accessNotes']?.toString();
        final String? instructions = bookingData['instructions']?.toString();
        final int? estimatedDays = (bookingData['estimatedDurationDays'] is int)
            ? bookingData['estimatedDurationDays'] as int
            : null;
        final List<String> attachUrls = [
          ...(((bookingData['imageUrls'] as List?) ?? const [])
              .map((e) => e?.toString())
              .whereType<String>()),
          ...(((bookingData['attachments'] as List?) ?? const [])
              .map((e) => e?.toString())
              .whereType<String>()),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                      ? NetworkImage(profileImageUrl!)
                      : null,
                  child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email != null && email!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(email!, style: TextStyle(color: Colors.grey[700], fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                      if (phone != null && phone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(phone!, style: TextStyle(color: Colors.grey[700], fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if ((address != null && address!.isNotEmpty) || geo != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (address != null && address!.isNotEmpty)
                          ? address!
                          : 'Location available',
                      style: const TextStyle(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'View on map',
                    icon: const Icon(Icons.map_outlined),
                    color: Colors.deepPurple,
                    onPressed: () => _openInMaps(context, geo: geo, address: address ?? ''),
                  ),
                ],
              ),
            ],

            // On-site Contact & Access
            if ((contactName != null && contactName.isNotEmpty) ||
                (contactPhone != null && contactPhone.isNotEmpty) ||
                (accessNotes != null && accessNotes.trim().isNotEmpty)) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contactName != null && contactName.isNotEmpty)
                          Text('Contact: $contactName', style: const TextStyle(fontSize: 14)),
                        if (contactPhone != null && contactPhone.isNotEmpty)
                          Text('Phone: $contactPhone', style: const TextStyle(fontSize: 14)),
                        if (accessNotes != null && accessNotes.trim().isNotEmpty)
                          Text('Access: $accessNotes', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Job details: instructions, estimated days, attachments count/preview
            if ((instructions != null && instructions.trim().isNotEmpty) ||
                estimatedDays != null ||
                attachUrls.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.build_outlined, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (estimatedDays != null)
                          Text('Estimated: $estimatedDays day(s)', style: const TextStyle(fontSize: 14)),
                        if (instructions != null && instructions.trim().isNotEmpty)
                          Text('Instructions: $instructions', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        if (attachUrls.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 60,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (c, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(attachUrls[i], height: 60, width: 60, fit: BoxFit.cover),
                              ),
                              separatorBuilder: (c, i) => const SizedBox(width: 6),
                              itemCount: attachUrls.length.clamp(0, 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openInMaps(BuildContext context, {GeoPoint? geo, String? address}) async {
    // Build candidates: geo:, google.navigation:, and web https fallback
    final String? query = geo != null
        ? '${geo.latitude},${geo.longitude}'
        : (address != null && address.isNotEmpty ? address : null);

    if (query == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location available for this customer.')),
      );
      return;
    }

    final List<Uri> candidates = [
      if (geo != null) Uri.parse('geo:${geo.latitude},${geo.longitude}?q=${geo.latitude},${geo.longitude}(Customer)'),
      if (address != null && address.isNotEmpty) Uri.parse('geo:0,0?q=${Uri.encodeComponent(address!)}'),
      if (geo != null) Uri.parse('google.navigation:q=${geo.latitude},${geo.longitude}&mode=d'),
      if (address != null && address.isNotEmpty) Uri.parse('google.navigation:q=${Uri.encodeComponent(address!)}&mode=d'),
      // Web fallback
      if (geo != null) Uri.parse('https://www.google.com/maps/search/?api=1&query=${geo.latitude},${geo.longitude}'),
      if (address != null && address.isNotEmpty) Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address!)}'),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          // Try external first
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return;
          // Fallback to platformDefault (may open in in-app browser for https)
          final launchedAlt = await launchUrl(uri, mode: LaunchMode.platformDefault);
          if (launchedAlt) return;
        }
      } catch (_) {
        // continue to next candidate
      }
    }

    // Final fallback: try to open the web URL via platform default (browser)
    final Uri webUri = (geo != null)
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=${geo.latitude},${geo.longitude}')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address!)}');
    try {
      final launched = await launchUrl(webUri, mode: LaunchMode.platformDefault);
      if (launched) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open map. URL: ${webUri.toString()}')),
      );
    }
  }
}

// --- REUSABLE UI WIDGETS (Unchanged) ---
class _InfoCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _InfoCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 30, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 30, color: color)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

// --- CUSTOM CLIPPER (Unchanged) ---
class _AppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}