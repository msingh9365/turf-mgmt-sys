import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';

// --- Shared navigation state controller ---
class NavController extends ChangeNotifier {
  int selectedIndex = 0;
  void setIndex(int index) {
    selectedIndex = index;
    notifyListeners();
  }
}

final navController = NavController();

final List<Map<String, dynamic>> globalBookings = [
  {
    'bookingDateTime': '25 Oct 2025, 9:32 PM',
    'slotDate': '27 Oct 2025',
    'slotTime': '7:00 AM - 9:00 AM',
    'sport': 'Football',
    'ground': 'Football Ground 1',
    'slots': '2',
    'team': [
      {'name': 'John Doe', 'email': 'john.doe@gmail.com'},
      {'name': 'Aarav Mehta', 'email': 'aarav@iitropar.ac.in'},
      {'name': 'Priya Singh', 'email': 'priya.singh@iitropar.ac.in'},
    ],
  },
  {
    'bookingDateTime': '22 Oct 2025, 6:48 PM',
    'slotDate': '24 Oct 2025',
    'slotTime': '6:00 PM - 8:00 PM',
    'sport': 'Badminton',
    'ground': 'Indoor Court 3',
    'slots': '1',
    'team': [
      {'name': 'Riya Sharma', 'email': 'riya.sharma@iitropar.ac.in'},
      {'name': 'Sahil Verma', 'email': 'sahil.v@iitropar.ac.in'},
    ],
  },
];
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const IntroScreen(),
    );
  }
}

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset('assets/intro.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        _controller
          ..setLooping(false)
          ..setVolume(0.0)
          ..play();

        setState(() {}); // refresh to show first frame immediately
      });

    _controller.addListener(() {
      if (_controller.value.isInitialized &&
          !_controller.value.isPlaying &&
          _controller.value.position >= _controller.value.duration &&
          !_navigated) {
        _navigated = true;
        _goToHome();
      }
    });
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // exact background color sampled from your intro video
    const Color bgColor = Color(0xFFAAC4A0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: bgColor),
          if (_controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
        ],
      ),
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
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = navController.selectedIndex;
    navController.addListener(() {
      setState(() => _selectedIndex = navController.selectedIndex);
    });
  }

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
      extendBody: true, // ✅ allow frosted nav to float

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: SafeArea(
          key: ValueKey<int>(_selectedIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
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
                const Text(
                  "Upcoming Events",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ Swipable Event Cards
                SizedBox(
                  height: 220,
                  width: double.infinity, // ✅ Force full width
                  child: PageView.builder(
                    controller: _pageController,
                    padEnds: false, // ✅ Removes automatic right-side gap
                    onPageChanged: (index) {
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
                    itemCount: _events.length + 2,
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
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ), // ✅ Equal on both sides
                              width: MediaQuery.of(
                                context,
                              ).size.width, // ✅ Fill screen width
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
                  "Sports at IIT RPR",
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
              ],
            ),
          ),
        ),
      ),

      // ✅ Shared persistent nav bar
      bottomNavigationBar: const PersistentNavBar(),
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
  final bool openTeams;

  const FrostedIconCard({
    super.key,
    required this.name,
    required this.imagePath,
    this.openTeams = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (openTeams) {
          // 🟢 Used in TeamsPage – open team list
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeamListPage(sportName: name),
            ),
          );
          return;
        } else if (name == 'Football') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GroundSelectionPage(),
            ),
          );
          return;
        } else if (name == 'Basketball') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BasketballGroundSelectionPage(),
            ),
          );
          return;
        }
        List<Map<String, String>> grounds = [];

        switch (name) {
          case 'Badminton':
            grounds = [
              {
                'image': 'assets/badminton_ground1.png',
                'title': 'Badminton Court 1',
              },
              {
                'image': 'assets/badminton_ground2.png',
                'title': 'Badminton Court 2',
              },
              {
                'image': 'assets/badminton_ground3.png',
                'title': 'Badminton Court 3',
              },
              {
                'image': 'assets/badminton_ground4.png',
                'title': 'Badminton Court 4',
              },
            ];
            break;

          case 'Cricket':
            grounds = [
              {
                'image': 'assets/cricket_ground1.png',
                'title': 'Cricket Ground 1',
              },
              {
                'image': 'assets/cricket_ground2.png',
                'title': 'Cricket Ground 2',
              },
            ];
            break;

          case 'Hockey':
            grounds = [
              {'image': 'assets/hockey_ground1.png', 'title': 'Hockey Field 1'},
            ];
            break;

          case 'Table Tennis':
            grounds = [
              {
                'image': 'assets/table_tennis_ground1.png',
                'title': 'Table Tennis Hall 1',
              },
              {
                'image': 'assets/table_tennis_ground2.png',
                'title': 'Table Tennis Hall 2',
              },
              {
                'image': 'assets/table_tennis_ground3.png',
                'title': 'Table Tennis Hall 3',
              },
              {
                'image': 'assets/table_tennis_ground4.png',
                'title': 'Table Tennis Hall 4',
              },
            ];
            break;

          case 'Tennis':
            grounds = [
              {'image': 'assets/tennis_ground1.png', 'title': 'Tennis Court 1'},
              {'image': 'assets/tennis_ground2.png', 'title': 'Tennis Court 2'},
            ];
            break;

          case 'Volleyball':
            grounds = [
              {
                'image': 'assets/volleyball_ground1.png',
                'title': 'Volleyball Court 1',
              },
            ];
            break;

          default:
            return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                GroundSelectionPageCommon(sportName: name, grounds: grounds),
          ),
        );
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
    navController.setIndex(-1); // deselect all icons on subpage
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}

class GroundListTile extends StatelessWidget {
  final String imagePath;
  final String title;
  final String? sportName;

  const GroundListTile({
    super.key,
    required this.imagePath,
    required this.title,
    this.sportName,
  });

  @override
  Widget build(BuildContext context) {
    navController.setIndex(-1); // deselect all icons while in subpages
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SlotBookingPage(
              sportName: sportName ?? extractSportFromGround(title),
              groundName: title,
              slotDate:
                  "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}",
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    // ✅ Left side → clear image
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                        ),
                        child: Image.asset(imagePath, fit: BoxFit.cover),
                      ),
                    ),

                    // ✅ Right side → lighter frosted glass (like sports cards)
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(
                                0.12,
                              ), // 💚 green-tinted glass like slot tile
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ✅ Soft gradient overlay for subtle fading
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.transparent,
                          Colors.black.withOpacity(0.04),
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
    );
  }
}

String extractSportFromGround(String groundTitle) {
  final lower = groundTitle.toLowerCase();
  if (lower.contains('football')) return 'Football';
  if (lower.contains('basketball')) return 'Basketball';
  if (lower.contains('cricket')) return 'Cricket';
  if (lower.contains('badminton')) return 'Badminton';
  if (lower.contains('tennis')) return 'Tennis';
  if (lower.contains('hockey')) return 'Hockey';
  if (lower.contains('volleyball')) return 'Volleyball';
  if (lower.contains('table tennis')) return 'Table Tennis';
  return 'Unknown';
}

class BasketballGroundSelectionPage extends StatelessWidget {
  const BasketballGroundSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    navController.setIndex(-1); // deselect all icons while in subpages
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    GroundListTile(
                      imagePath: 'assets/basketball_ground1.png',
                      title: 'Basketball Ground 1',
                      sportName: 'Basketball',
                    ),
                    GroundListTile(
                      imagePath: 'assets/basketball_ground2.png',
                      title: 'Basketball Ground 2',
                      sportName: 'Basketball',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}

class SlotBookingPage extends StatefulWidget {
  final String sportName;
  final String groundName;
  final String slotDate;
  final List<String>? customSlots;

  const SlotBookingPage({
    super.key,
    required this.sportName,
    required this.groundName,
    required this.slotDate,
    this.customSlots,
  });

  @override
  State<SlotBookingPage> createState() => _SlotBookingPageState();
}

// --- Sport + Ground Custom Time Rules ---
final Map<String, Map<String, List<String>>> groundSlotRules = {
  'Cricket': {
    'Cricket Ground 1': [
      '8:00 AM - 8:30 AM',
      '8:30 AM - 9:00 AM',
      '9:00 AM - 9:30 AM',
      '9:30 AM - 10:00 AM',
      '10:00 AM - 10:30 AM',
      '10:30 AM - 11:00 AM',
      '11:00 AM - 11:30 AM',
      '11:30 AM - 12:00 PM',
      '12:00 PM - 12:30 PM',
      '12:30 PM - 1:00 PM',
      '1:00 PM - 1:30 PM',
      '1:30 PM - 2:00 PM',
      '2:00 PM - 2:30 PM',
      '2:30 PM - 3:00 PM',
      '3:00 PM - 3:30 PM',
      '3:30 PM - 4:00 PM',
      '4:00 PM - 4:30 PM',
    ],
    'Cricket Ground 2': [
      '8:00 AM - 8:30 AM',
      '8:30 AM - 9:00 AM',
      '9:00 AM - 9:30 AM',
      '9:30 AM - 10:00 AM',
      '10:00 AM - 10:30 AM',
      '10:30 AM - 11:00 AM',
      '11:00 AM - 11:30 AM',
      '11:30 AM - 12:00 PM',
      '12:00 PM - 12:30 PM',
    ],
  },
  'Football': {
    'Football Ground 1': [
      '8:00 AM - 8:30 AM',
      '8:30 AM - 9:00 AM',
      '9:00 AM - 9:30 AM',
      '9:30 AM - 10:00 AM',
      '4:00 PM - 4:30 PM',
      '4:30 PM - 5:00 PM',
      '5:00 PM - 5:30 PM',
      '5:30 PM - 6:00 PM',
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
      '7:00 PM - 7:30 PM',
      '7:30 PM - 8:00 PM',
    ],
  },
  'Tennis': {
    'Tennis Court 1': [
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
      '7:00 PM - 7:30 PM',
      '7:30 PM - 8:00 PM',
      '8:00 PM - 8:30 PM',
      '8:30 PM - 9:00 PM',
      '9:00 PM - 9:30 PM',
      '9:30 PM - 10:00 PM',
      '10:00 PM - 10:30 PM',
      '10:30 PM - 11:00 PM',
      '11:00 PM - 11:30 PM',
    ],
    'Tennis Court 2': [
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
      '7:00 PM - 7:30 PM',
      '7:30 PM - 8:00 PM',
      '8:00 PM - 8:30 PM',
      '8:30 PM - 9:00 PM',
      '9:00 PM - 9:30 PM',
      '9:30 PM - 10:00 PM',
    ],
  },
  'Badminton': {
    'Badminton Court 1': [
      '8:00 AM - 8:30 AM',
      '8:30 AM - 9:00 AM',
      '9:00 AM - 9:30 AM',
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
      '7:00 PM - 7:30 PM',
      '7:30 PM - 8:00 PM',
      '8:00 PM - 8:30 PM',
      '8:30 PM - 9:00 PM',
      '9:00 PM - 9:30 PM',
      '9:30 PM - 10:00 PM',
      '10:00 PM - 10:30 PM',
      '10:30 PM - 11:00 PM',
      '11:00 PM - 11:30 PM',
    ],
    // More courts can be added easily
  },
  'Basketball': {
    'Basketball Ground 1': [
      '4:00 PM - 4:30 PM',
      '4:30 PM - 5:00 PM',
      '5:00 PM - 5:30 PM',
      '5:30 PM - 6:00 PM',
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
      '7:00 PM - 7:30 PM',
      '7:30 PM - 8:00 PM',
      '8:00 PM - 8:30 PM',
      '8:30 PM - 9:00 PM',
      '9:00 PM - 9:30 PM',
    ],
  },
};

class _SlotBookingPageState extends State<SlotBookingPage> {
  late List<String> _slots;
  final Set<String> _selectedSlots = {};

  @override
  void initState() {
    super.initState();
    _ensureMinPlayers();
    _slots =
        widget.customSlots ??
        groundSlotRules[widget.sportName]?[widget.groundName] ??
        [
          '8:00 AM - 8:30 AM',
          '8:30 AM - 9:00 AM',
          '9:00 AM - 9:30 AM',
          '9:30 AM - 10:00 AM',
          '10:00 AM - 10:30 AM',
          '10:30 AM - 11:00 AM',
          '11:00 AM - 11:30 AM',
          '11:30 AM - 12:00 PM',
          '12:00 PM - 12:30 PM',
          '12:30 PM - 1:00 PM',
          '1:00 PM - 1:30 PM',
          '1:30 PM - 2:00 PM',
          '2:00 PM - 2:30 PM',
          '2:30 PM - 3:00 PM',
          '3:00 PM - 3:30 PM',
          '3:30 PM - 4:00 PM',
          '4:00 PM - 4:30 PM',
          '4:30 PM - 5:00 PM',
          '5:00 PM - 5:30 PM',
          '5:30 PM - 6:00 PM',
          '6:00 PM - 6:30 PM',
          '6:30 PM - 7:00 PM',
          '7:00 PM - 7:30 PM',
          '7:30 PM - 8:00 PM',
          '8:00 PM - 8:30 PM',
          '8:30 PM - 9:00 PM',
          '9:00 PM - 9:30 PM',
          '9:30 PM - 10:00 PM',
        ];
  }

  // ---------- participants controllers ----------
  final List<Map<String, TextEditingController>> _participantCtrls = [];

  // call this in initState or add below to ensure min players exist
  void _ensureMinPlayers() {
    final minPlayers = _minPlayersForSport(widget.sportName);
    while (_participantCtrls.length < minPlayers) {
      _participantCtrls.add({
        'name': TextEditingController(),
        'email': TextEditingController(),
      });
    }
  }

  int _minPlayersForSport(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('tennis') ||
        s.contains('table tennis') ||
        s.contains('badminton')) {
      return 2;
    }
    return 1;
  }

  void _addPlayer() {
    setState(() {
      _participantCtrls.add({
        'name': TextEditingController(),
        'email': TextEditingController(),
      });
    });
  }

  // collect participants that have at least a name filled
  List<Map<String, String>> _collectTeam() {
    return _participantCtrls
        .map(
          (m) => {
            'name': m['name']!.text.trim(),
            'email': m['email']!.text.trim(),
          },
        )
        .where((m) => (m['name'] != null && (m['name'] as String).isNotEmpty))
        .toList();
  }

  void _toggleSlot(String time) {
    setState(() {
      if (_selectedSlots.contains(time)) {
        _selectedSlots.remove(time);
      } else {
        _selectedSlots.add(time);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    navController.setIndex(-1);
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: Column(
          children: [
            // --- Top bar ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
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
                    "Slot Booking",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Icon(Icons.menu_rounded, color: Colors.black54),
                ],
              ),
            ),

            // --- Sport + Ground name header (Glass style) ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 6.0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.sportName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.groundName,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- Slot grid (Glass effect) ---
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 2.7,
                ),
                itemCount: _slots.length,
                itemBuilder: (context, index) {
                  final time = _slots[index];
                  final isSelected = _selectedSlots.contains(time);

                  return GestureDetector(
                    onTap: () => _toggleSlot(time),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green.shade800.withOpacity(0.65)
                                : Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            time,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // --- Book Slot Button (Glass look) ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 6.0,
              ),
              child: GestureDetector(
                onTap: () {
                  if (_selectedSlots.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select at least one slot"),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FinalSlotBookingPage(
                        sport: widget.sportName,
                        ground: widget.groundName,
                        slotDate:
                            widget.slotDate, // ensure widget.slotDate exists
                        selectedSlots: _selectedSlots.toList(),
                        team: _collectTeam(),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      width: double.infinity,
                      height: 55,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        "Book Slot",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),
          ],
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}

// --- Shared persistent bottom navigation bar ---
class PersistentNavBar extends StatefulWidget {
  const PersistentNavBar({super.key});

  @override
  State<PersistentNavBar> createState() => _PersistentNavBarState();
}

class _PersistentNavBarState extends State<PersistentNavBar> {
  @override
  void initState() {
    super.initState();
    navController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.home,
      Icons.notifications,
      Icons.groups_rounded,
      Icons.book_online,
      Icons.person,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, left: 20, right: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.25),
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
              children: List.generate(icons.length, (index) {
                final isSelected = navController.selectedIndex == index;
                return GestureDetector(
                  onTap: () {
                    navController.setIndex(index);

                    // Navigate based on the selected icon
                    switch (index) {
                      case 0: // Home
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const HomePage(),
                          ),
                          (route) => false,
                        );
                        break;

                      case 1: // Notifications
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const NotificationPage(),
                          ),
                          (route) => false,
                        );
                        break;

                      case 2: // Teams List
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const TeamsPage(),
                          ),
                          (route) => false,
                        );
                        break;

                      case 3: // Booking History
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const BookingHistoryPage(),
                          ),
                          (route) => false,
                        );
                        break;

                      case 4: // Profile
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const ProfilePage(),
                          ),
                          (route) => false,
                        );
                        break;

                      // You can add more cases for other icons if needed
                      default:
                        break;
                    }
                  },

                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.green.shade800.withOpacity(0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.green.shade900.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      icons[index],
                      color: isSelected
                          ? Colors.greenAccent.shade100
                          : Colors.white.withOpacity(0.8),
                      size: 26,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Common Ground Selection Page for Remaining Sports ---
class GroundSelectionPageCommon extends StatelessWidget {
  final String sportName;
  final List<Map<String, String>> grounds;

  const GroundSelectionPageCommon({
    super.key,
    required this.sportName,
    required this.grounds,
  });

  @override
  Widget build(BuildContext context) {
    navController.setIndex(-1); // deselect bottom icons when on this page
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Top Bar ---
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
                  Text(
                    'Select $sportName Ground',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Icon(Icons.menu_rounded, color: Colors.black54),
                ],
              ),
              const SizedBox(height: 20),

              // --- Grounds List ---
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: grounds.length,
                  itemBuilder: (context, index) {
                    final ground = grounds[index];
                    return GroundListTile(
                      imagePath: ground['image']!,
                      title: ground['title']!,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      //Consistent Frosted Bottom Nav
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}

class NotificationPage extends StatelessWidget {
  final List<Map<String, String>> notifications = const [
    {
      "title": "Booking Confirmed",
      "message": "Your slot for 8:00 AM - 8:30 AM is confirmed.",
      "time": "5 min ago",
    },
    {
      "title": "Slot Cancelled",
      "message": "Your 9:00 AM - 9:30 AM slot was cancelled by admin.",
      "time": "1 hr ago",
    },
    {
      "title": "New Announcement",
      "message": "Football ground will undergo maintenance tomorrow.",
      "time": "2 hrs ago",
    },
  ];

  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9), // same background as slot page
      extendBody: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Top Bar ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: const [
                  Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // --- Notifications List ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Notification Icon
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.notifications_rounded,
                                  color: Colors.green,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Notification Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item["title"]!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item["message"]!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item["time"]!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // --- Bottom Status Bar (PersistentNavBar visible) ---
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}

// ================== 🆕 TEAMS MAIN PAGE ==================
class TeamsPage extends StatelessWidget {
  const TeamsPage({super.key});

  final List<Map<String, String>> _sports = const [
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
    navController.setIndex(2); // highlight Teams icon
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Teams List",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  physics: const BouncingScrollPhysics(),
                  children: _sports.map((sport) {
                    final name = sport.keys.first;
                    final image = sport.values.first;
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamListPage(sportName: name),
                          ),
                        );
                      },
                      child: FrostedIconCard(
                        name: name,
                        imagePath: image,
                        openTeams: true,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}

// ================== 🆕 TEAM LIST PAGE ==================
class TeamListPage extends StatelessWidget {
  final String sportName;

  const TeamListPage({super.key, required this.sportName});

  // Custom teams list by sport
  List<String> _getTeams() {
    switch (sportName) {
      case 'Football':
        return ['Rovers FC', 'Campus United', 'Mechanical XI', 'Civil Stars'];
      case 'Cricket':
        return ['RPR Blazers', 'ECE Warriors', 'Hostel Kings', 'Phoenix XI'];
      case 'Basketball':
        return ['Dunk Masters', 'Tech Titans', 'Campus Bulls'];
      case 'Badminton':
        return ['Shuttle Squad', 'Net Ninjas', 'Ace Breakers'];
      case 'Tennis':
        return ['Baseline Breakers', 'Racquet Rebels'];
      case 'Volleyball':
        return ['Spike Force', 'Campus Smashers'];
      case 'Hockey':
        return ['RPR Hawks', 'Steel Blades'];
      case 'Table Tennis':
        return ['Spin Masters', 'Topspin Titans', 'Net Ninjas'];
      default:
        return ['Team A', 'Team B'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final teams = _getTeams();
    navController.setIndex(-1);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Top bar with back
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$sportName Teams List",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 🔹 Team list
              Expanded(
                child: ListView.builder(
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.group_rounded,
                                  color: Colors.green,
                                  size: 28,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  teams[index],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isEditing = false;

  String name = "John Doe";
  String email = "john.doe@gmail.com";
  String phone = "+91 9876543210";
  String sports = "Football, Cricket";
  String achievements = "🏆 5 Tournaments | ⚽ 30 Matches | 🥇 12 Wins";

  @override
  Widget build(BuildContext context) {
    navController.setIndex(4); // highlight profile icon
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            children: [
              // --- Title ---
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Profile",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // --- Profile Picture ---
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: const Color(0xFFD4E7D0),
                    backgroundImage: const AssetImage('assets/profile_pic.png'),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 8,
                    child: InkWell(
                      onTap: () {
                        // TODO: Implement image picker
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(5),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.black87,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // --- Name and Edit Toggle ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.black54,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => isEditing = !isEditing);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Information Fields ---
              _buildInfoTile("Email", email, Icons.email),
              _buildInfoTile("Mobile", phone, Icons.phone),
              _buildInfoTile("Interested Sports", sports, Icons.sports_soccer),
              _buildAchievementsCard(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }

  Widget _buildAchievementsCard() {
    final achievementsList = [
      {
        "sport": "Football",
        "tournament": "Inter-IIT Sports Meet",
        "year": "2024",
        "achievement": "Gold Medal",
        "experience": "5 Years",
      },
      {
        "sport": "Cricket",
        "tournament": "Tech Premier League",
        "year": "2023",
        "achievement": "Runner Up",
        "experience": "3 Years",
      },
      {
        "sport": "Badminton",
        "tournament": "Campus Championship",
        "year": "2022",
        "achievement": "Champion",
        "experience": "4 Years",
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.green.shade700),
              const SizedBox(width: 10),
              const Text(
                "Achievements",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // --- Each Achievement Card ---
          ...achievementsList.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade200.withOpacity(0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.green.shade400.withOpacity(0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${item['sport']} • ${item['year']}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tournament: ${item['tournament']}",
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  Text(
                    "Achievement: ${item['achievement']}",
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  Text(
                    "Experience: ${item['experience']}",
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700),
          const SizedBox(width: 15),
          Expanded(
            child: isEditing
                ? TextFormField(
                    initialValue: value,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: const TextStyle(color: Colors.black54),
                      border: InputBorder.none,
                    ),
                    onChanged: (newVal) {
                      setState(() {
                        switch (label) {
                          case "Email":
                            email = newVal;
                            break;
                          case "Mobile":
                            phone = newVal;
                            break;
                          case "Interested Sports":
                            sports = newVal;
                            break;
                          case "Achievements":
                            achievements = newVal;
                            break;
                        }
                      });
                    },
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
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

class BookingHistoryPage extends StatelessWidget {
  const BookingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    navController.setIndex(3); // highlight booking icon
    // use the shared global bookings store so new bookings appear here
    final List<Map<String, dynamic>> bookings = globalBookings;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: Column(
          children: [
            // --- Static Title Bar ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Booking History",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Icon(Icons.history_rounded, color: Colors.black54, size: 26),
                ],
              ),
            ),

            // --- Scrollable Bookings Section ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: bookings
                      .map((booking) => _buildBookingTile(context, booking))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }

  Widget _buildBookingTile(BuildContext context, Map<String, dynamic> booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_note_rounded,
                color: Colors.black54,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                "Booked On: ${booking['bookingDateTime']}",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoPill(Icons.sports_soccer, "Sport", booking['sport']),
          const SizedBox(height: 8),
          _infoPill(Icons.place_rounded, "Ground", booking['ground']),
          const SizedBox(height: 8),
          _infoPill(
            Icons.confirmation_number_rounded,
            "Slots",
            booking['slots'],
          ),
          const SizedBox(height: 8),
          _infoPill(
            Icons.calendar_today_rounded,
            "Slot Date",
            booking['slotDate'],
          ),
          const SizedBox(height: 8),
          _infoPill(
            Icons.access_time_filled_rounded,
            "Time",
            booking['slotTime'],
          ),
          const SizedBox(height: 16),
          const Text(
            "Team Members:",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (booking['team'] as List<dynamic>)
                .map(
                  (member) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "${member['name']} (${member['email']})",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade200.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade400.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.green.shade800),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: TextStyle(
              color: Colors.green.shade900,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.green.shade900,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class FinalSlotBookingPage extends StatefulWidget {
  final String sport;
  final String ground;
  final String slotDate;
  final List<String> selectedSlots;
  final List<Map<String, String>> team;

  const FinalSlotBookingPage({
    super.key,
    required this.sport,
    required this.ground,
    required this.slotDate,
    required this.selectedSlots,
    required this.team,
  });

  @override
  State<FinalSlotBookingPage> createState() => _FinalSlotBookingPageState();
}

class _FinalSlotBookingPageState extends State<FinalSlotBookingPage> {
  final List<Map<String, TextEditingController>> _players = [];

  @override
  void initState() {
    super.initState();
    if (widget.team.isNotEmpty) {
      for (final p in widget.team) {
        _players.add({
          'name': TextEditingController(text: p['name'] ?? ''),
          'email': TextEditingController(text: p['email'] ?? ''),
        });
      }
    } else {
      _addPlayer();
    }
  }

  void _addPlayer() {
    setState(() {
      _players.add({
        'name': TextEditingController(),
        'email': TextEditingController(),
      });
    });
  }

  List<Map<String, String>> _collectPlayers() {
    return _players
        .map(
          (m) => {
            'name': m['name']!.text.trim(),
            'email': m['email']!.text.trim(),
          },
        )
        .where((m) => m['name']!.isNotEmpty)
        .toList();
  }

  // --- Reusable Glass Button ---
  Widget glassButton(
    String text, {
    required Color color,
    required VoidCallback onTap,
    double blur = 14,
    double opacity = 0.25,
    double height = 52,
    double radius = 18,
    EdgeInsetsGeometry? padding,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            height: height,
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.green.shade900.withOpacity(0.9),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDEEE1),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.green.withOpacity(0.05),
        elevation: 0,
        title: const Text(
          'Confirm Booking',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // --- Top Glass Info Card ---
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sport,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.ground,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Date: ${widget.slotDate}",
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Slots: ${widget.selectedSlots.join(', ')}",
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // --- Player Details ---
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      "Player Details",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ..._players.asMap().entries.map((entry) {
                      final index = entry.key;
                      final player = entry.value;

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                TextField(
                                  controller: player['name'],
                                  style: const TextStyle(color: Colors.black87),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(
                                      0xFFBFE3C0,
                                    ).withOpacity(0.3),
                                    labelText: "Player ${index + 1} Name",
                                    labelStyle: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: player['email'],
                                  style: const TextStyle(color: Colors.black87),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(
                                      0xFFBFE3C0,
                                    ).withOpacity(0.3),
                                    labelText: "Email (optional)",
                                    labelStyle: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // --- Add More Players (More pill shaped) ---
                    Center(
                      child: glassButton(
                        "➕ Add Player",
                        color: const Color(0xFFB9E4B1),
                        opacity: 0.25,
                        height: 38, // slimmer height
                        radius: 80, // smoother, more pill-like
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        onTap: _addPlayer,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // --- Submit + Invite Buttons ---
              Row(
                children: [
                  Expanded(
                    child: glassButton(
                      "Submit",
                      color: const Color(0xFF4CAF50),
                      opacity: 0.25,
                      onTap: () {
                        final players = _collectPlayers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Booking submitted for ${players.length} players",
                            ),
                          ),
                        );
                        Navigator.popUntil(context, (r) => r.isFirst);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: glassButton(
                      "Invite Players",
                      color: const Color(0xFF81C784),
                      opacity: 0.25,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Invitations sent successfully!"),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}
