// lib/user_dashboard.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:serviceprovider/login_screen.dart';
import 'package:serviceprovider/profile_screen.dart';
import 'package:serviceprovider/view_services_screen.dart';
import 'package:serviceprovider/my_requests_screen.dart';
import 'package:serviceprovider/service_search_screen.dart';
import 'package:serviceprovider/customer_notifications_screen.dart';
import 'package:serviceprovider/customer_view_service_screen.dart';
import 'package:serviceprovider/cart_screen.dart';
import 'package:serviceprovider/payment_history_screen.dart';
import 'package:serviceprovider/chats_screen.dart';
import 'package:serviceprovider/self_fix_screen.dart';
import 'package:serviceprovider/self_fix_chatbot_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _FeaturedForYouCarousel extends StatefulWidget {
  @override
  State<_FeaturedForYouCarousel> createState() => _FeaturedForYouCarouselState();
}

class _FeaturedForYouCarouselState extends State<_FeaturedForYouCarousel> {
  late final PageController _pageController;
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients) return;
      final next = _current + 1;
      _pageController.animateToPage(next,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pull a few popular services for all users; keep it light
    final stream = FirebaseFirestore.instance
        .collection('services')
        .limit(10)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        // Hide kp1-kp4 assets; show only real service images
        List<Map<String, dynamic>> items = [];
        if (snapshot.hasData) {
          final remote = snapshot.data!.docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            return {
              'id': d.id,
              'name': (m['serviceName'] as String?) ?? (m['name'] as String?) ?? 'Service',
              'imageUrl': (m['serviceImageUrl'] as String?) ?? (m['imageUrl'] as String?),
              'isAsset': false,
            };
          }).toList();
          items.addAll(remote);
        }

        if (items.isEmpty) {
          items = [
            {'name': 'Home Deep Cleaning', 'imageUrl': null},
            {'name': 'AC Service & Repair', 'imageUrl': null},
            {'name': 'Bathroom Plumbing', 'imageUrl': null},
            {'name': 'Electric Installation', 'imageUrl': null},
            {'name': 'Pest Control Visit', 'imageUrl': null},
            {'name': 'General Handyman', 'imageUrl': null},
          ];
        }

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _current = i % items.length),
                itemBuilder: (context, index) {
                  final data = items[index % items.length];
                  final imageUrl = data['imageUrl'] as String?;
                  final title = (data['name'] as String?) ?? 'Service';
                  final bool isAsset = (data['isAsset'] as bool?) ?? false;
                  final String? id = data['id'] as String?;

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        final double page = (_pageController.page ?? _pageController.initialPage.toDouble());
                        final double delta = page - index.toDouble();
                        value = (1 - (delta.abs() * 0.08)).clamp(0.92, 1.0);
                      }
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: _CustomerCarouselCard(
                      title: title,
                      imageUrl: imageUrl,
                      isAsset: isAsset,
                      onTap: () {
                        if (id != null && id.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CustomerViewServiceScreen(serviceId: id)),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ViewServicesScreen()),
                          );
                        }
                      },
                    ),
                  );
                },
                itemCount: items.length + 10000,
              ),
            ),
            const SizedBox(height: 8),
            _CuDotsIndicator(count: items.length, current: _current % items.length),
          ],
        );
      },
    );
  }
}

class _CustomerCarouselCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final bool isAsset;
  final VoidCallback? onTap;
  const _CustomerCarouselCard({required this.title, required this.imageUrl, this.isAsset = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4)),
            ],
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.purple.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isAsset
                        ? Image.asset(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(color: Colors.deepPurple.shade200.withOpacity(0.25)),
                          )
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(color: Colors.deepPurple.shade200.withOpacity(0.25)),
                            loadingBuilder: (c, w, p) => p == null ? w : Container(color: Colors.deepPurple.shade200.withOpacity(0.15)),
                          ),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.45)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withOpacity(0.85),
                      child: const Icon(Icons.local_offer, color: Colors.deepPurple),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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
}

class _CuDotsIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _CuDotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? Colors.deepPurple : Colors.deepPurple.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}


// Customer notifications bell with unread badge
class _CustomerNotificationsBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .limit(100)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) count = snapshot.data!.docs.length;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerNotificationsScreen()),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications, color: Colors.white),
              if (count > 0)
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


class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  String _username = 'User';
  // NEW: State variable to hold the profile image URL
  String? _profileImageUrl;
  String? _effectiveAvatarUrl; // URL with cache-busting query to force refresh
  bool _isLoading = true;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _attachUserListener();
  }



  // Fetch initial values for username/profile photo and set up pages
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _username = doc.data()!['username'] ?? 'User';
          _profileImageUrl = doc.data()!['profileImageUrl'];
          _effectiveAvatarUrl = _cacheBusted(_profileImageUrl);
        });
      }
    } catch (_) {
      // ignore errors for initial load
    } finally {
      _pages = [
        _buildHomeWithAssistant(),
        const MyRequestsScreen(),
        const CustomerNotificationsScreen(),
        const CartScreen(),
        const ProfileScreen(),
      ];
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Listen to user doc so avatar updates immediately after profile photo changes
  void _attachUserListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      setState(() {
        _username = data['username'] ?? _username;
        _profileImageUrl = data['profileImageUrl'];
        _effectiveAvatarUrl = _cacheBusted(_profileImageUrl);
      });
    });
  }

  // Returns url with a cache-busting timestamp query to force image reloads
  String? _cacheBusted(String? url) {
    if (url == null || url.isEmpty) return url;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return url.contains('?') ? "$url&v=$ts" : "$url?v=$ts";
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 12,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'My Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none_rounded),
            label: 'Notification',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeWithAssistant() {
    return Stack(
      children: [
        _buildHomeContent(),
        Positioned(
          right: 16,
          bottom: 24,
          child: _SelfFixAssistantButton(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SelfFixChatbotScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHomeContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildHeader(),
        _buildSectionTitle("Quick Actions"),
        _buildQuickActionsGrid(),
        _buildSectionTitle("Featured"),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 190,
              child: _FeaturedForYouCarousel(),
            ),
          ),
        ),
        _buildSectionTitle("Categories"),
        _buildCategoryList(),
        _buildSectionTitle("Popular Services"),
        _buildPopularServicesList(),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  // MODIFIED: This widget now displays the profile photo
  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 220.0,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      elevation: 2,
      actions: [
        _CustomerNotificationsBell(),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purple.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16.0,
                right: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NEW: Row to hold the text and the profile photo
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello, $_username!",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Find the best services near you",
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // NEW: CircleAvatar to display the profile photo
                    CircleAvatar(
                      key: ValueKey(_effectiveAvatarUrl),
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: _effectiveAvatarUrl != null
                          ? NetworkImage(_effectiveAvatarUrl!)
                          : null,
                      child: _effectiveAvatarUrl == null
                          ? const Icon(Icons.person,
                              size: 30, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSearchBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServiceSearchScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: const [
            Icon(Icons.search, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Search for a service...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
        child: Text(
          title,
          style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: Colors.grey[800]),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.34,
        ),
        delegate: SliverChildListDelegate(
          [
            _buildQuickActionCard(
              title: 'View All Services',
              subtitle: 'Browse providers',
              icon: Icons.design_services_rounded,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViewServicesScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              title: 'My Requests',
              subtitle: 'Track bookings',
              icon: Icons.list_alt_rounded,
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              title: 'Payment',
              subtitle: 'View payment status',
              icon: Icons.payments_rounded,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                );
              },
            ),
            _buildNotificationsQuickActionCard(),
            _buildChatQuickActionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsQuickActionCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _buildQuickActionCard(
        title: 'Notifications',
        subtitle: 'Check updates',
        icon: Icons.notifications_active_rounded,
        color: Colors.deepPurple,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerNotificationsScreen()),
          );
        },
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .limit(100)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final unread = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _buildQuickActionCard(
          title: 'Notifications',
          subtitle: 'Check updates',
          icon: Icons.notifications_active_rounded,
          color: Colors.deepPurple,
          badgeCount: unread,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerNotificationsScreen()),
            );
          },
        );
      },
    );
  }

  Widget _buildChatQuickActionCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _buildQuickActionCard(
        title: 'Chat',
        subtitle: 'Message providers',
        icon: Icons.chat_bubble_outline_rounded,
        color: Colors.teal,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatsScreen(role: ChatRole.customer)),
          );
        },
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        var unread = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp? lastTs = data['lastMessageAt'] as Timestamp?;
            final String lastSenderId = (data['lastSenderId'] as String?) ?? '';
            if (lastTs == null || lastSenderId == uid) continue;
            final Timestamp? lastRead = data['lastReadAtCustomer'] as Timestamp?;
            if (lastRead == null || lastTs.toDate().isAfter(lastRead.toDate())) {
              unread++;
            }
          }
        }

        return _buildQuickActionCard(
          title: 'Chat',
          subtitle: 'Message providers',
          icon: Icons.chat_bubble_outline_rounded,
          color: Colors.teal,
          badgeCount: unread,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatsScreen(role: ChatRole.customer)),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final Color soft = Color.lerp(color, Colors.white, 0.82)!;
    final Color surface = Color.lerp(color, Colors.white, 0.93)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        splashColor: color.withOpacity(0.12),
        highlightColor: color.withOpacity(0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [Colors.white, soft, surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withOpacity(0.16), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.10),
                  ),
                ),
              ),
              Positioned(
                left: -24,
                bottom: -26,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.95), color.withOpacity(0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.30),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 21),
                        ),
                        const Spacer(),
                        if (badgeCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              badgeCount > 99 ? '99+' : '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[850],
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 11.4,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Open',
                            style: TextStyle(
                              color: color,
                              fontSize: 10.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Icon(
                            Icons.arrow_outward_rounded,
                            size: 16,
                            color: color,
                          ),
                        ),
                      ],
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

  Widget _buildCategoryList() {
    final categories = [
      {'icon': Icons.cleaning_services, 'label': 'Cleaning', 'color': Colors.lightBlue},
      {'icon': Icons.plumbing, 'label': 'Plumbing', 'color': Colors.orange},
      {'icon': Icons.brush, 'label': 'Painting', 'color': Colors.pink},
      {'icon': Icons.electrical_services, 'label': 'Electrician', 'color': Colors.amber},
      {'icon': Icons.handyman, 'label': 'Repairs', 'color': Colors.brown},
      {'icon': Icons.ac_unit_rounded, 'label': 'AC Repair', 'color': Colors.cyan},
      {'icon': Icons.pest_control_rounded, 'label': 'Pest Control', 'color': Colors.green},
      {'icon': Icons.local_laundry_service_rounded, 'label': 'Laundry', 'color': Colors.indigo},
      {'icon': Icons.directions_car_filled_rounded, 'label': 'Car Care', 'color': Colors.blueGrey},
      {'icon': Icons.security_rounded, 'label': 'CCTV', 'color': Colors.deepPurple},
      {'icon': Icons.grass_rounded, 'label': 'Gardening', 'color': Colors.teal},
      {'icon': Icons.local_shipping_rounded, 'label': 'Shifting', 'color': Colors.deepOrange},
    ];

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final category = categories[index];
            return _buildCategoryChip(
              category['label'] as String,
              category['icon'] as IconData,
              category['color'] as Color,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, Color color) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              )),
        ],
      ),
    );
  }

  Widget _buildPopularServicesList() {
    final services = [
      {
        'title': 'AC Mechanic',
        'subtitle': 'Cooling, gas refill',
        'badge': 'Popular',
        'icon': Icons.ac_unit_rounded,
        'color': Colors.cyan,
      },
      {
        'title': 'House Cleaning',
        'subtitle': 'Full home deep clean',
        'badge': 'Top rated',
        'icon': Icons.cleaning_services_rounded,
        'color': Colors.lightBlue,
      },
      {
        'title': 'Car Wash',
        'subtitle': 'Exterior and interior',
        'badge': 'Shine',
        'icon': Icons.local_car_wash_rounded,
        'color': Colors.blueAccent,
      },
      {
        'title': 'Fridge Repair',
        'subtitle': 'No cooling, noise',
        'badge': 'Fast',
        'icon': Icons.kitchen_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'TV Repair',
        'subtitle': 'Screen and sound',
        'badge': 'Trusted',
        'icon': Icons.tv_rounded,
        'color': Colors.indigo,
      },
      {
        'title': 'Car Wash Spa',
        'subtitle': 'Exterior and interior',
        'badge': 'Premium',
        'icon': Icons.local_car_wash_rounded,
        'color': Colors.lightBlue,
      },
      {
        'title': 'Sofa Cleaning',
        'subtitle': 'Fabric and stain removal',
        'badge': 'Home visit',
        'icon': Icons.weekend_rounded,
        'color': Colors.brown,
      },
      {
        'title': 'Washing Machine',
        'subtitle': 'Drain, spin issues',
        'badge': 'Same-day',
        'icon': Icons.local_laundry_service_rounded,
        'color': Colors.purple,
      },
      {
        'title': 'Bathroom Cleaning',
        'subtitle': 'Tiles, fittings, floor',
        'badge': 'Hygiene',
        'icon': Icons.bathroom_rounded,
        'color': Colors.lightBlueAccent,
      },
      {
        'title': 'Microwave Service',
        'subtitle': 'Heating problems',
        'badge': 'Quick fix',
        'icon': Icons.microwave_rounded,
        'color': Colors.deepOrange,
      },
      {
        'title': 'Kitchen Cleaning',
        'subtitle': 'Grease and chimney',
        'badge': 'Fresh',
        'icon': Icons.kitchen_rounded,
        'color': Colors.orangeAccent,
      },
      {
        'title': 'Geyser Repair',
        'subtitle': 'No hot water',
        'badge': 'Winter',
        'icon': Icons.hot_tub_rounded,
        'color': Colors.orange,
      },
      {
        'title': 'RO Water Service',
        'subtitle': 'Filter and leakage',
        'badge': 'Home visit',
        'icon': Icons.water_drop_rounded,
        'color': Colors.lightBlueAccent,
      },
      {
        'title': 'Pest Control',
        'subtitle': 'Ants, roaches, rats',
        'badge': 'Safe',
        'icon': Icons.pest_control_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Laptop Repair',
        'subtitle': 'Battery and speed',
        'badge': 'Tech',
        'icon': Icons.laptop_mac_rounded,
        'color': Colors.teal,
      },
      {
        'title': 'Phone Repair',
        'subtitle': 'Screen and battery',
        'badge': 'Express',
        'icon': Icons.phone_android_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Plumbing',
        'subtitle': 'Leak and fittings',
        'badge': 'Urgent',
        'icon': Icons.plumbing_rounded,
        'color': Colors.orange,
      },
      {
        'title': 'Inverter Service',
        'subtitle': 'Backup and wiring',
        'badge': 'Power',
        'icon': Icons.battery_charging_full_rounded,
        'color': Colors.blueGrey,
      },
      {
        'title': 'Electrician',
        'subtitle': 'Wiring and switch',
        'badge': 'Verified',
        'icon': Icons.electrical_services_rounded,
        'color': Colors.amber,
      },
      {
        'title': 'Painting',
        'subtitle': 'Walls and touch-up',
        'badge': 'New look',
        'icon': Icons.brush_rounded,
        'color': Colors.pinkAccent,
      },
      {
        'title': 'Chimney Cleaning',
        'subtitle': 'Kitchen maintenance',
        'badge': 'Hygiene',
        'icon': Icons.kitchen_rounded,
        'color': Colors.redAccent,
      },
      {
        'title': 'Car Detailing',
        'subtitle': 'Polish and wax',
        'badge': 'Premium',
        'icon': Icons.car_repair_rounded,
        'color': Colors.blueGrey,
      },
      {
        'title': 'Gardening',
        'subtitle': 'Lawn and trimming',
        'badge': 'Outdoor',
        'icon': Icons.grass_rounded,
        'color': Colors.teal,
      },
      {
        'title': 'Water Tank Cleaning',
        'subtitle': 'Safe and hygienic',
        'badge': 'Seasonal',
        'icon': Icons.water,
        'color': Colors.blue,
      },
      {
        'title': 'Window Cleaning',
        'subtitle': 'Glass and frames',
        'badge': 'Clear',
        'icon': Icons.window,
        'color': Colors.lightBlue,
      },
      {
        'title': 'Floor Polishing',
        'subtitle': 'Marble and tiles',
        'badge': 'Shine',
        'icon': Icons.layers_rounded,
        'color': Colors.indigo,
      },
      {
        'title': 'Carpentry',
        'subtitle': 'Furniture fixes',
        'badge': 'Skilled',
        'icon': Icons.carpenter_rounded,
        'color': Colors.brown,
      },
      {
        'title': 'Door Lock Repair',
        'subtitle': 'Locks and keys',
        'badge': 'Secure',
        'icon': Icons.lock_rounded,
        'color': Colors.blueGrey,
      },
      {
        'title': 'Appliance Installation',
        'subtitle': 'Setup and fitting',
        'badge': 'New',
        'icon': Icons.build_circle_rounded,
        'color': Colors.deepPurple,
      },
      {
        'title': 'Generator Service',
        'subtitle': 'Backup maintenance',
        'badge': 'Power',
        'icon': Icons.electrical_services_rounded,
        'color': Colors.amber,
      },
      {
        'title': 'Bike Wash',
        'subtitle': 'Clean and polish',
        'badge': 'Quick',
        'icon': Icons.pedal_bike_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Home Sanitization',
        'subtitle': 'Disinfection service',
        'badge': 'Safe',
        'icon': Icons.clean_hands_rounded,
        'color': Colors.teal,
      },
      {
        'title': 'Curtain Cleaning',
        'subtitle': 'Dust and stain',
        'badge': 'Care',
        'icon': Icons.blinds_rounded,
        'color': Colors.purple,
      },
    ];

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 176,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: services.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final service = services[index];
            return _buildServiceTypeCard(
              title: service['title'] as String,
              subtitle: service['subtitle'] as String,
              badge: service['badge'] as String,
              icon: service['icon'] as IconData,
              color: service['color'] as Color,
            );
          },
        ),
      ),
    );
  }

  Widget _buildServiceTypeCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color color,
  }) {
    final Color soft = color.withOpacity(0.14);
    return SizedBox(
      width: 160,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ViewServicesScreen()),
          ),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [soft, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _SelfFixAssistantButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SelfFixAssistantButton({required this.onTap});

  @override
  State<_SelfFixAssistantButton> createState() => _SelfFixAssistantButtonState();
}

class _SelfFixAssistantButtonState extends State<_SelfFixAssistantButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: const Offset(0, -0.02),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 6, right: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bolt_rounded, size: 16, color: Colors.deepPurple),
              SizedBox(width: 4),
              Text(
                'Self-fix assistant',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        SlideTransition(
          position: _offsetAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade800, Colors.purple.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.9),
                    width: 2.2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.deepPurple.shade50,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.deepPurple.shade500,
                      size: 32,
                    ),
                    Positioned(
                      bottom: 10,
                      child: Container(
                        width: 30,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.withOpacity(0.55),
                              Colors.purple.withOpacity(0.25),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
