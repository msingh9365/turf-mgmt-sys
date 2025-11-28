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

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  void initState() {
    super.initState();
    _loadAndMarkRead();

    // Live updates from FCM: pull fresh list each time
    FirebaseMessaging.onMessage.listen((_) => _loadAndRecount());
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _loadAndRecount());
  }

  Future<void> _loadAndMarkRead() async {
    await _loadAndRecount();
    await markAllNotificationsRead(); // <-- mark on open
    setState(() {}); // refresh to clear badges
  }

  Future<void> _loadAndRecount() async {
    final list = await fetchNotificationsFromBackend();
    if (mounted) {
      globalNotifications = list;
      globalUnreadCount = list.where((n) => !(n['is_read'] ?? false)).length;
      setState(() {});
    }
  }

  // --- Call your backend best-effort ---
  Future<void> markAllNotificationsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('access_token');
    if (jwt == null) return;

    // Adjust this URL if your backend exposes a different path
    final resp = await http.post(
      Uri.parse(
        'https://turf-mgmt-sys.onrender.com/api/notifications/mark-all-read/',
      ),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    if (resp.statusCode == 200) {
      // Update local state instantly
      for (final n in globalNotifications) {
        n['is_read'] = true;
      }
      globalUnreadCount = 0;
    } else {
      // If your backend doesn't have the endpoint, nothing breaks.
      // You can optionally iterate and mark individually if you do have a per-ID endpoint.
    }
  }

  @override
  Widget build(BuildContext context) {
    // No full-screen loader anymore; keep scaffold so bottom nav never disappears
    final notifications = globalNotifications.isNotEmpty
        ? globalNotifications
        : [
            {
              'title': 'No Notifications',
              'message': 'You will see them here once received.',
              'time': '',
              'is_read': true,
            },
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAndRecount, // pull to refresh
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Notifications',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              for (final item in notifications)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _NotificationTile(item: item),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(), // always visible
    );
  }
}
class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] ?? '') as String;
    final body = (item['message'] ?? '') as String;
    final time = (item['time'] ?? '') as String;
    final isRead = (item['is_read'] ?? false) as bool;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
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
                  if (!isRead)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 0, right: 0),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(color: Colors.black.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      time,
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
    );
  }
}