import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController(initialPage: 1);
  int _selectedIndex = 0;

  final List<Map<String, String>> _events = [
    {
      'title': 'Football Tournament',
      'location': 'IIT RPR Stadium',
      'image': 'football_tournament.png',
    },
    {
      'title': 'Basketball Match',
      'location': 'Basketball Court',
      'image': 'basketball_match.png',
    },
    {
      'title': 'Cricket Finals',
      'location': 'Main Ground',
      'image': 'cricket_match.png',
    },
    {
      'title': 'Badminton League',
      'location': 'Indoor Arena',
      'image': 'badminton_match.png',
    },
  ];

  final List<Map<String, String>> _sports = [
    {'Football': 'assets/football_logo.png'},
    {'Basketball': 'assets/basketball_logo.png'},
    {'Cricket': 'assets/cricket_logo.png'},
    {'Tennis': 'assets/tennis_logo.png'},
    {'Badminton': 'assets/badminton_logo.png'},
    {'Volleyball': 'assets/volleyball_logo.png'},
    {'Hockey': 'assets/hockey_logo.png'},
    {'Table Tennis': 'assets/table_tennis_logo.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true, // ✅ allows nav bar to float
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Home",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Upcoming Events section
              const Text(
                "Upcoming Events",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Swipable Event Cards
              SizedBox(
                height: 220,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    // Smooth infinite looping effect
                    if (index == _events.length + 1) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        _pageController.jumpToPage(1);
                      });
                    } else if (index == 0) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        _pageController.jumpToPage(_events.length);
                      });
                    }
                  },
                  itemCount: _events.length + 2, // +2 for fake first/last items
                  itemBuilder: (context, index) {
                    int realIndex;
                    if (index == 0) {
                      realIndex = _events.length - 1;
                    } else if (index == _events.length + 1) {
                      realIndex = 0;
                    } else {
                      realIndex = index - 1;
                    }

                    final event = _events[realIndex];

                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double scale = 1.0;
                        if (_pageController.position.haveDimensions) {
                          scale = (_pageController.page! - index).abs();
                          scale = (1 - (scale * 0.1)).clamp(0.9, 1.0);
                        }
                        return Transform.scale(
                          scale: scale,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: FrostedGlassCard(
                              title: event['title']!,
                              location: event['location']!,
                              image: event['image'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: _events.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: Colors.green.shade400,
                    dotColor: Colors.green.shade100,
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "Sports at IITRPR",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  physics: const ClampingScrollPhysics(),
                  children: _sports.map((sport) {
                    final name = sport.keys.first;
                    final imagePath = sport.values.first;
                    return FrostedIconCard(name: name, imagePath: imagePath);
                  }).toList(),
                ),
              ),

              // ✅ No extra bottom padding, fully flush
              SizedBox.shrink(),
            ],
          ),
        ),
      ),

      // ✅ Floating Dark Frosted Navigation Bar
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 20.0, left: 20, right: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.25), // ✅ darker green glass
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home, 0),
                  _buildNavItem(Icons.notifications, 1),
                  _buildNavItem(Icons.groups_rounded, 2),
                  _buildNavItem(Icons.book_online, 3),
                  _buildNavItem(Icons.person, 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.shade800.withOpacity(0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.shade900.withOpacity(0.25), // softer
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isSelected
              ? Colors.greenAccent.shade100
              : Colors.white.withOpacity(0.8),
          size: 26,
        ),
      ),
    );
  }
}

// ---- Frosted Glass Widgets ----

class FrostedGlassCard extends StatefulWidget {
  final String title;
  final String location;
  final String? image;

  const FrostedGlassCard({
    super.key,
    required this.title,
    required this.location,
    this.image,
  });

  @override
  State<FrostedGlassCard> createState() => _FrostedGlassCardState();
}

class _FrostedGlassCardState extends State<FrostedGlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Full image background
                  Positioned.fill(
                    child: widget.image != null
                        ? Image.asset(
                            'assets/${widget.image!}',
                            fit: BoxFit.cover,
                          )
                        : Container(color: Colors.green.withOpacity(0.1)),
                  ),

                  // Optional gradient overlay for better contrast
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.25),
                            Colors.black.withOpacity(0.35),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating glassy pill with event info
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE8F5E9,
                            ).withOpacity(0.35), // minty glass tint
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.location,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}

class FrostedIconCard extends StatelessWidget {
  final String name;
  final String imagePath;

  const FrostedIconCard({
    super.key,
    required this.name,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (name == 'Football') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GroundSelectionPage(),
            ),
          );
        } else if (name == 'Basketball') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BasketballGroundSelectionPage(),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  imagePath,
                  height: 50,
                  width: 50,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GroundSelectionPage extends StatelessWidget {
  const GroundSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main frosted glass body
        Scaffold(
          backgroundColor: const Color(0xFFE8F5E9),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Select Football Ground',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Icon(Icons.menu_rounded, color: Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Ground list
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: const [
                        GroundListTile(
                          imagePath: 'assets/football_ground.png',
                          title: 'Football Ground 1',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Transparent bottom spacer so bottom nav from Home stays visible
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: true,
            child: Container(height: 80, color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

class GroundListTile extends StatelessWidget {
  final String imagePath;
  final String title;

  const GroundListTile({
    super.key,
    required this.imagePath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Left side - clear background image
              Positioned.fill(child: Image.asset(imagePath, fit: BoxFit.cover)),

              // Right half - independent frosted mint glass (no image)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.45,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFD8E8D3,
                    ).withOpacity(0.6), // mint tint
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    backgroundBlendMode: BlendMode.srcOver,
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
              ),

              // Black text above frosted area
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 24.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BasketballGroundSelectionPage extends StatelessWidget {
  const BasketballGroundSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFE8F5E9),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Select Basketball Ground',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Icon(Icons.menu_rounded, color: Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Ground list
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: const [
                        GroundListTile(
                          imagePath: 'assets/basketball_ground1.png',
                          title: 'Basketball Ground 1',
                        ),
                        GroundListTile(
                          imagePath: 'assets/basketball_ground2.png',
                          title: 'Basketball Ground 2',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Spacer for bottom nav
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: true,
            child: Container(height: 80, color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}