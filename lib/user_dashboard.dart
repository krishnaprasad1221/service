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
import 'package:serviceprovider/payment_history_screen.dart';
import 'package:serviceprovider/service_search_screen.dart';
import 'package:serviceprovider/customer_notifications_screen.dart';
import 'package:serviceprovider/customer_view_service_screen.dart';
import 'package:serviceprovider/self_fix_screen.dart';
import 'package:serviceprovider/self_fix_chatbot_screen.dart';
// Notifications screen removed from Customer Dashboard

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
            {'name': 'Book top-rated services', 'imageUrl': null},
            {'name': 'Fast response nearby', 'imageUrl': null},
            {'name': 'Great prices this week', 'imageUrl': null},
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
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'My Requests',
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
      slivers: [
        _buildHeader(),
        _buildSectionTitle("Featured"),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 180,
            child: _FeaturedForYouCarousel(),
          ),
        ),
        _buildSectionTitle("Categories"),
        _buildCategoryList(),
        _buildSectionTitle("Quick Actions"),
        _buildDashboardGrid(),
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Text(
          title,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800]),
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
    ];

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildListDelegate([
          _buildDashboardCard(
            title: "View All\nServices",
            icon: Icons.apps_rounded,
            color: Colors.blue,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ViewServicesScreen())),
          ),
          _buildDashboardCard(
            title: "Payment",
            icon: Icons.history_rounded,
            color: Colors.green,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PaymentHistoryScreen())),
          ),
          _buildDashboardCard(
            title: "Service\nTimeline",
            icon: Icons.timeline_rounded,
            color: Colors.deepPurple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
                height: 1.3,
              ),
            ),
          ],
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

