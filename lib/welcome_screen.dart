// lib/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:serviceprovider/login_screen.dart';
import 'package:serviceprovider/register_screen.dart';
import 'package:serviceprovider/service_search_screen.dart';

// Converted to a StatelessWidget since it no longer needs to fetch user data
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // We use a Stack to place the buttons on top of the scrolling content
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHeader(context),
              _buildSectionTitle("Categories"),
              _buildCategoryList(),
              _buildSectionTitle("Featured Providers"),
              _buildFeaturedProviders(),
              // Add padding at the bottom so content doesn't hide behind the buttons
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          // This positions the Login/Register buttons at the bottom
          _buildAuthButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240.0,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      elevation: 2,
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
                // ▼▼▼ MODIFIED WELCOME TEXT ▼▼▼
                const Text(
                  "Welcome to ServSphere",
                  style: TextStyle(
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
                // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
                const SizedBox(height: 20),
                _buildSearchBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
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

  // --- The rest of the UI widgets remain the same ---

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
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
            return _AnimatedListItem(
              index: index,
              child: _buildCategoryChip(
                category['label'] as String,
                category['icon'] as IconData,
                category['color'] as Color,
              ),
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
          Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
  Widget _buildFeaturedProviders() {
    final featured = [
      {'name': 'Gleam & Go Cleaners', 'service': 'Home Cleaning', 'image': 'https://example.com/cleaning.jpg'},
      {'name': 'Pipe Masters', 'service': 'Plumbing', 'image': 'https://example.com/plumbing.jpg'},
      {'name': 'Bright Spark Elec.', 'service': 'Electrician', 'image': 'https://example.com/electrician.jpg'},
    ];
    
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: featured.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final provider = featured[index];
            return _AnimatedListItem(
              index: index,
              isHorizontal: true,
              child: _buildFeaturedCard(provider['name']!, provider['service']!, provider['image']!),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildFeaturedCard(String name, String service, String imageUrl) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200], child: const Icon(Icons.business, color: Colors.grey))),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                   const SizedBox(height: 4),
                   Text(service, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
  
  /// ▼▼▼ ADDED THIS NEW WIDGET FOR LOGIN/REGISTER BUTTONS ▼▼▼
  Widget _buildAuthButtons(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[100]!.withOpacity(0.0), Colors.grey[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Colors.deepPurple),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                child: const Text("Login", style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                },
                child: const Text("Get Started", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable animation widget (unchanged)
class _AnimatedListItem extends StatefulWidget {
  // ... code for animation is the same ...
  final int index;
  final Widget child;
  final bool isHorizontal;
  
  const _AnimatedListItem({
    required this.index, 
    required this.child,
    this.isHorizontal = false,
  });

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final delay = Duration(milliseconds: widget.index * 100);
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut)
    );
    
    _slideAnimation = Tween<Offset>(
      begin: widget.isHorizontal ? const Offset(0.2, 0.0) : const Offset(0.0, 0.5), 
      end: Offset.zero
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    Future.delayed(delay, () {
      if(mounted) {
        _controller.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}