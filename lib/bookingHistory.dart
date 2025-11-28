
class EditProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String sports;
  final List<Map<String, dynamic>> achievements; // grouped by sport
  final List<Map<String, dynamic>> teamsList;

  const EditProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.sports,
    required this.achievements,
    required this.teamsList,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _name = TextEditingController(
    text: widget.name,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.email,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.phone,
  );
  late final TextEditingController _sports = TextEditingController(
    text: widget.sports,
  );

  late List<Map<String, dynamic>> teamsList;
  late List<Map<String, dynamic>>
  achievements; // [{sport:String, records: [ {...}, {...} ]}]

  final BoxDecoration _tileBox = BoxDecoration(
    color: AppGreen.light.withOpacity(0.35),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppGreen.mid.withOpacity(0.5)),
  );

  @override
  void initState() {
    super.initState();
    teamsList = widget.teamsList
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    achievements = widget.achievements.map((e) {
      return {
        "sport": e["sport"],
        "records": List<Map<String, dynamic>>.from(e["records"] ?? []),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDEEE1),
      appBar: AppBar(
        backgroundColor: AppGreen.card.withOpacity(0.25),
        elevation: 0,
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: AppGreen.ink, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: AppGreen.ink),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field("Name", _name),
            _field("Email", _email),
            _field("Mobile", _phone),
            _field("Interested Sports", _sports),
            const SizedBox(height: 20),
            _achievementsSection(),
            const SizedBox(height: 20),
            _teamsSection(),
            const SizedBox(height: 25),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        style: const TextStyle(color: AppGreen.ink),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppGreen.light.withOpacity(0.3),
          labelText: label,
          labelStyle: const TextStyle(
            color: AppGreen.ink,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _achievementsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppGreen.card.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppGreen.mid.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Achievements",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppGreen.ink,
            ),
          ),
          const SizedBox(height: 12),

          ...achievements.asMap().entries.map((entry) {
            final i = entry.key;
            final sportBlock = entry.value;

            final sportController = TextEditingController(
              text: sportBlock['sport'],
            );
            final experienceController = TextEditingController(
              text: sportBlock['experience'] ?? "",
            );
            final List<Map<String, dynamic>> records =
                List<Map<String, dynamic>>.from(sportBlock['records'] ?? []);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: _tileBox,
              child: Column(
                children: [
                  _inlineTextField(
                    "Sport",
                    sportController,
                    onChanged: (v) => achievements[i]['sport'] = v,
                  ),
                  _inlineTextField(
                    "Experience (e.g. 5 Years)",
                    experienceController,
                    onChanged: (v) => achievements[i]['experience'] = v,
                  ),

                  const SizedBox(height: 10),

                  ...records.asMap().entries.map((recEntry) {
                    final rIdx = recEntry.key;
                    final r = Map<String, dynamic>.from(recEntry.value);

                    final tournamentC = TextEditingController(
                      text: r['tournament'] ?? '',
                    );
                    final yearC = TextEditingController(text: r['year'] ?? '');
                    final achievementC = TextEditingController(
                      text: r['achievement'] ?? '',
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppGreen.light.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppGreen.mid.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          _inlineTextField(
                            "Tournament",
                            tournamentC,
                            onChanged: (v) =>
                                achievements[i]['records'][rIdx]['tournament'] =
                                    v,
                          ),
                          _inlineTextField(
                            "Year",
                            yearC,
                            onChanged: (v) =>
                                achievements[i]['records'][rIdx]['year'] = v,
                          ),
                          _inlineTextField(
                            "Achievement",
                            achievementC,
                            onChanged: (v) =>
                                achievements[i]['records'][rIdx]['achievement'] =
                                    v,
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                () => achievements[i]['records'].removeAt(rIdx),
                              ),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppGreen.deep,
                              ),
                              label: const Text(
                                "Remove Achievement",
                                style: TextStyle(color: AppGreen.deep),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          achievements[i]['records'].add({
                            "tournament": "",
                            "year": "",
                            "achievement": "",
                          });
                        });
                      },
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppGreen.deep,
                      ),
                      label: const Text(
                        "Add Achievement",
                        style: TextStyle(
                          color: AppGreen.deep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 20),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => achievements.removeAt(i)),
                      icon: const Icon(
                        Icons.delete_forever,
                        color: AppGreen.deep,
                      ),
                      label: const Text(
                        "Remove Sport",
                        style: TextStyle(color: AppGreen.deep),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  achievements.add({
                    "sport": "",
                    "experience": "",
                    "records": [
                      {"tournament": "", "year": "", "achievement": ""},
                    ],
                  });
                });
              },
              icon: const Icon(Icons.sports_handball, color: AppGreen.deep),
              label: const Text(
                "Add Sports Data",
                style: TextStyle(
                  color: AppGreen.deep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineTextField(
    String label,
    TextEditingController c, {
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        onChanged: onChanged,
        style: const TextStyle(color: AppGreen.ink),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppGreen.light.withOpacity(0.28),
          labelText: label,
          labelStyle: const TextStyle(
            color: AppGreen.ink,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _teamsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppGreen.card.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppGreen.mid.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Teams",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppGreen.ink,
            ),
          ),
          const SizedBox(height: 12),

          ...teamsList.asMap().entries.map((entry) {
            int i = entry.key;
            var team = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: _tileBox,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team['teamName'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppGreen.ink,
                    ),
                  ),
                  Text("Sport: ${team['sport']}"),
                  Text("Leader: ${team['leader']}"),
                  Text("Created On: ${team['createdOn']}"),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: (team['isLeader'] == true)
                        ? TextButton.icon(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: AppGreen.deep,
                            ),
                            label: const Text(
                              "Edit Team",
                              style: TextStyle(color: AppGreen.deep),
                            ),
                            onPressed: () async {
                              final updatedTeam = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddTeamPage(
                                    sportName: team['sport'],
                                    sportId: team['sport_id'].toString(),
                                    existingTeam: team,
                                  ),
                                ),
                              );
                              if (updatedTeam != null) {
                                setState(() => teamsList[i] = updatedTeam);
                              }
                            },
                          )
                        : TextButton.icon(
                            onPressed: () {
                              setState(() => teamsList.removeAt(i));
                            },
                            icon: const Icon(
                              Icons.exit_to_app,
                              color: AppGreen.deep,
                            ),
                            label: const Text(
                              "Quit Team",
                              style: TextStyle(color: AppGreen.deep),
                            ),
                          ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget glassButton(
    String text, {
    required Color color,
    required double opacity,
    required VoidCallback onTap,
    double blur = 14,
    double height = 52,
    double radius = 18,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: const Text(
              "Save Changes",
              style: TextStyle(
                color: Color(0xFF2E7D32), // AppGreen.deep
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return glassButton(
      "Save Changes",
      color: AppGreen.deep,
      opacity: 0.28,
      onTap: () {
        Navigator.pop(context, {
          "name": _name.text.trim(),
          "email": _email.text.trim(),
          "phone": _phone.text.trim(),
          "sports": _sports.text.trim(),
          "achievements": achievements,
          "teamsList": teamsList,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Profile Updated Successfully!"),
            backgroundColor: AppGreen.deep,
          ),
        );
      },
    );
  }
}

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});
  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _cancelBooking(String bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token") ?? prefs.getString("token");

    if (token == null) {
      showGlassAlert(context, "Session expired, login again.");
      return;
    }

    try {
      final response = await _authService.authDelete(
        Uri.parse(
          "https://turf-mgmt-sys.onrender.com/api/bookings/$bookingId/",
        ),
      );

      print("Cancel Response: ${response.statusCode} ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        showGlassAlert(context, "Booking cancelled successfully.");
        await _fetchBookings();
        if (mounted) setState(() {});
      } else {
        showGlassAlert(context, "Failed to cancel booking.");
      }
    } catch (e) {
      if (mounted) showGlassAlert(context, "Network Error: $e");
    }
  }

  Future<void> _fetchBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token") ?? prefs.getString("token");

    try {
      final response = await _authService.authGet(
        Uri.parse("https://turf-mgmt-sys.onrender.com/api/bookings/my/"),
      );

      print("BOOKING RESPONSE = ${response.statusCode} ${response.body}");

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final DateTime now = DateTime.now();

        if (!mounted) return;
        setState(() {
          bookings = data.map<Map<String, dynamic>>((b) {
            final DateTime bookedOn = DateTime.parse(b["created_at"]).toLocal();
            final DateTime slotDate = DateTime.parse(b["date"]).toLocal();
            final DateTime now = DateTime.now();

            final groundName = groundIdMap[b["ground_id"]] ?? "Unknown Ground";

            final slotIds = (b["slots"] as List).cast<int>();
            final slotNames = slotIds
                .map((id) => slotIdMap[id] ?? "Unknown Slot")
                .toList();

            String slotTimeRange = "No Slots";
            if (slotNames.isNotEmpty) {
              final startTime = slotNames.first.split(" - ")[0];
              final endTime = slotNames.last.split(" - ")[1];
              slotTimeRange = "$startTime - $endTime";
            }

            final split = slotTimeRange.split(" - ");
            final endTimeStr = split.length > 1 ? split[1] : slotTimeRange;

            final parsedEnd = _parseTime(endTimeStr);
            final endDateTime = DateTime(
              slotDate.year,
              slotDate.month,
              slotDate.day,
              parsedEnd.hour,
              parsedEnd.minute,
            );

            String status = (b["status"] ?? "").toString().toLowerCase();
            if (status == "rejected") status = "cancelled";
            if (status != "cancelled" && now.isAfter(endDateTime))
              status = "completed";

            return {
              "bookingId": b["booking_id"],
              "ground": groundName,
              "sport": groundToSportMap[b["ground_id"]] ?? "Sport",
              "slotCount": slotIds.length,
              "slotTimeRange": slotTimeRange,
              "slotDate": slotDate,
              "bookedOn": bookedOn,
              "players": b["players"],
              "status": status,
            };
          }).toList();
        });
      }
    } catch (e) {
      print("Fetch error: $e");
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    navController.setIndex(3);
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "Booking History",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.history_rounded,
                          color: Colors.black54,
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Column(
                        children: bookings
                            .map(
                              (booking) => _buildBookingTile(context, booking),
                            )
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

  Widget _buildBookingTile(BuildContext context, Map<String, dynamic> b) {
    bool isCancelled = b["status"] == "cancelled";
    bool isCompleted = b["status"] == "completed"; // expired slot

    Color cardColor;
    Color borderColor;

    if (isCancelled) {
      cardColor = Colors.red.withOpacity(0.15);
      borderColor = Colors.red.withOpacity(0.35);
    } else if (isCompleted) {
      cardColor = Colors.grey.withOpacity(0.20);
      borderColor = Colors.grey.withOpacity(0.35);
    } else {
      cardColor = Colors.green.withOpacity(0.10);
      borderColor = Colors.green.withOpacity(0.35);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 26),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          if (isCancelled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: const Text(
                "Cancelled",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.30)),
              ),
              child: const Text(
                "Completed",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 18),
              const SizedBox(width: 6),
              Text(
                "Booked On: ${b['bookedOn'].day} ${_month(b['bookedOn'].month)} ${b['bookedOn'].year}, ${_formatTime(b['bookedOn'])}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          _tag(
            Icons.sports_soccer,
            "Sport: ${b['sport']}",
            isCancelled,
            isCompleted,
          ),
          _tag(Icons.place, "Ground: ${b['ground']}", isCancelled, isCompleted),
          _tag(
            Icons.grid_view_rounded,
            "Slots: ${b['slotCount']}",
            isCancelled,
            isCompleted,
          ),
          _tag(
            Icons.calendar_month_rounded,
            "Slot Date: ${b['slotDate'].day} ${_month(b['slotDate'].month)} ${b['slotDate'].year}",
            isCancelled,
            isCompleted,
          ),
          _tag(
            Icons.access_time_rounded,
            "Time: ${b['slotTimeRange']}",
            isCancelled,
            isCompleted,
          ),

          const SizedBox(height: 18),
          const Text(
            "Team Members:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          ...b["players"].map<Widget>((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text("${p['name']} (${p['email']})")),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 18),

          // ✅ Show button only if active
          if (!isCancelled && !isCompleted)
            GestureDetector(
              onTap: () => _cancelBooking(b["bookingId"]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.withOpacity(0.35)),
                  ),
                  child: const Text(
                    "Cancel Booking",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(" ");
    final hm = parts[0].split(":");
    int hour = int.parse(hm[0]);
    int minute = int.parse(hm[1]);
    final amPm = parts[1];
    if (amPm == "PM" && hour != 12) hour += 12;
    if (amPm == "AM" && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Widget _tag(IconData icon, String text, bool isCancelled, bool isCompleted) {
    Color mainColor;

    if (isCancelled) {
      mainColor = Colors.red.shade900;
    } else if (isCompleted) {
      mainColor = Colors.grey.shade700;
    } else {
      mainColor = Colors.green.shade900;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mainColor.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mainColor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: mainColor.withOpacity(0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: mainColor.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  final Map<int, String> groundToSportMap = {
    1: "Football",
    2: "Cricket",
    3: "Cricket",
    4: "Hockey",
    5: "Basketball",
    6: "Basketball",
    7: "Badminton",
    8: "Badminton",
    9: "Badminton",
    10: "Badminton",
    11: "Tennis",
    12: "Tennis",
    13: "Table Tennis",
    14: "Table Tennis",
    15: "Table Tennis",
    16: "Table Tennis",
    17: "Volleyball",
  };

  String _month(int m) {
    const names = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return names[m];
  }
}

String _formatTime(DateTime dt) {
  int hour = dt.hour;
  String ampm = hour >= 12 ? "PM" : "AM";
  hour = hour % 12;
  if (hour == 0) hour = 12;
  String minute = dt.minute.toString().padLeft(2, '0');
  return "$hour:$minute $ampm";
}

final Map<int, String> groundIdMap = {
  1: "Football Ground 1",
  2: "Cricket Ground 1",
  3: "Cricket Ground 2",
  4: "Hockey Ground",
  5: "Basketball Ground 1",
  6: "Basketball Ground 2",
  7: "Badminton Court 1",
  8: "Badminton Court 2",
  9: "Badminton Court 3",
  10: "Badminton Court 4",
  11: "Tennis Court 1",
  12: "Tennis Court 2",
  13: "Table Tennis Room 1",
  14: "Table Tennis Room 2",
  15: "Table Tennis Room 3",
  16: "Table Tennis Room 4",
  17: "Volleyball Court",
};

final Map<int, String> slotIdMap = {
  1: "8:00 AM - 8:30 AM",
  2: "8:30 AM - 9:00 AM",
  3: "9:00 AM - 9:30 AM",
  4: "9:30 AM - 10:00 AM",
  5: "10:00 AM - 10:30 AM",
  6: "10:30 AM - 11:00 AM",
  7: "11:00 AM - 11:30 AM",
  8: "11:30 AM - 12:00 PM",
  9: "12:00 PM - 12:30 PM",
  10: "12:30 PM - 1:00 PM",
  11: "1:00 PM - 1:30 PM",
  12: "1:30 PM - 2:00 PM",
  13: "2:00 PM - 2:30 PM",
  14: "2:30 PM - 3:00 PM",
  15: "3:00 PM - 3:30 PM",
  16: "3:30 PM - 4:00 PM",
  17: "4:00 PM - 4:30 PM",
  18: "4:30 PM - 5:00 PM",
  19: "5:00 PM - 5:30 PM",
  20: "5:30 PM - 6:00 PM",
  21: "6:00 PM - 6:30 PM",
  22: "6:30 PM - 7:00 PM",
  23: "7:00 PM - 7:30 PM",
  24: "7:30 PM - 8:00 PM",
  25: "8:00 PM - 8:30 PM",
  26: "8:30 PM - 9:00 PM",
  27: "9:00 PM - 9:30 PM",
  28: "9:30 PM - 10:00 PM",
};

final Map<String, int> groundNameToId = {
  for (final e in groundIdMap.entries) e.value: e.key,
};

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
  bool _insideCampus = true; // ✅ by default true
  bool _checkingLocation = true;

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
    _checkCampusAccess(); // ✅ check campus location at start
  }

  Future<void> _checkCampusAccess() async {
    LocationPermission permission =
        await Geolocator.requestPermission(); // ✅ ADD THIS LINE

    bool allowed = await isInsideCampus();
    if (!mounted) return;
    setState(() {
      _insideCampus = allowed;
      _checkingLocation = false;
    });
    if (!allowed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showGlassAlert(
          context,
          "You must be inside IIT Ropar campus to use restricted features",
        );
      });
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

  final _api = ApiClient.instance;

  /// 1) Translate sport name to backend sport_id (unique translation table)
  Future<String> translateSportNameToId(String sportName) async {
    // Example: GET /sports/translate?name=Tennis  -> { "sport_id": 3, "sport_name": "Tennis" }
    final j = await _api.getJson(
      TRANSLATE_SPORT_PATH,
      query: {"name": sportName},
    );
    final id = j["sport_id"] ?? j["id"];
    if (id == null) throw Exception("sport_id not found for $sportName");
    return id.toString();
  }

  Future<void> _broadcastLookingForPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");

    if (token == null) {
      showGlassAlert(context, "Session expired. Please log in again.");
      return;
    }

    // ✅ Normalize sport name → clean case
    final raw = widget.sport.trim().toLowerCase();
    final normalized = raw[0].toUpperCase() + raw.substring(1);

    // ✅ Use your fixed ID table
    final sportId = sportNameToId[normalized];
    if (sportId == null) {
      showGlassAlert(context, "Sport not supported: ${widget.sport}");
      return;
    }

    // ✅ Use only one slot (backend expects ONE)
    final selectedSlot = widget.selectedSlots.isNotEmpty
        ? widget.selectedSlots.first
        : null;
    if (selectedSlot == null) {
      showGlassAlert(context, "No slot selected.");
      return;
    }

    final slotId = slotNameToId[selectedSlot];
    if (slotId == null) {
      showGlassAlert(context, "Could not match slot to backend slot ID.");
      return;
    }

    // ✅ FINAL PAYLOAD EXACTLY AS BACKEND EXPECTS
    final payload = {
      "sport_id": sportId, // integer ✅
      "date": widget.slotDate, // string ✅
      "slot_id": slotId, // integer ✅ NOT LIST
    };

    print("Sending Broadcast Payload: $payload");

    try {
      final response = await http.post(
        Uri.parse(
          "https://turf-mgmt-sys.onrender.com/api/notifications/broadcast/looking-for-players/",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      print("BROADCAST STATUS = ${response.statusCode}");
      print("BROADCAST BODY = ${response.body}");

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        showGlassAlert(context, "✅ Invitation sent successfully!");
      } else {
        showGlassAlert(
          context,
          "Failed to send invitation (${response.statusCode}).\nCheck console logs.",
        );
      }
    } catch (e) {
      showGlassAlert(context, "Network error: $e");
    }
  }

  Future<void> _submitBooking() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");

    if (token == null) {
      showGlassAlert(context, "Session expired. Please login again.");
      return;
    }
    print("GROUND NAME: ${widget.ground}");
    print("GROUND ID: ${groundIdMap[widget.ground]}");

    print("SELECTED SLOTS: ${widget.selectedSlots}");
    for (var s in widget.selectedSlots) {
      print("Slot '$s' → ${slotIdMap[s]}");
    }
    final groundId = groundNameToId[widget.ground];
    final slotIds = widget.selectedSlots
        .map((s) => slotNameToId[s])
        .whereType<int>() // filters out nulls safely
        .toList();

    print("RESOLVED groundId = $groundId");
    print("RESOLVED slotIds  = $slotIds");

    if (groundId == null) {
      showGlassAlert(context, "Unknown ground: ${widget.ground}");
      return;
    }
    if (slotIds.isEmpty) {
      showGlassAlert(context, "Selected slots could not be mapped.");
      return;
    }

    final bookingData = {
      "date": widget.slotDate,
      "ground_id": groundNameToId[widget.ground]!,
      "slot_id": widget.selectedSlots.map((s) => slotNameToId[s]!).toList(),
      "players": _collectPlayers(),
    };

    try {
      final response = await http.post(
        Uri.parse("https://turf-mgmt-sys.onrender.com/api/bookings/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(bookingData),
      );

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        globalNotifications.add({
          "title": "Booking Confirmed",
          "message":
              "Your booking for ${widget.sport} on ${widget.slotDate} is confirmed.",
          "time": "Just now",
        });

        globalBookings.add({
          "bookingDateTime": DateTime.now().toString(),
          "sport": widget.sport,
          "ground": widget.ground,
          "slots": widget.selectedSlots.join(", "),
          "slotDate": widget.slotDate,
          "slotTime": widget.selectedSlots.first,
          "team": _collectPlayers(),
        });

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          showGlassAlert(context, "Booking successful!");
        }
      } else {
        showGlassAlert(context, "Booking failed (${response.statusCode}).");
      }
    } catch (e) {
      showGlassAlert(context, "Network error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDEEE1),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.green.withOpacity(0.05),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // ✅ black icons
          statusBarBrightness: Brightness.light, // ✅ for iOS
        ),
        title: const Text(
          'Confirm Booking',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            onPressed: _checkCampusAccess,
            icon: const Icon(Icons.my_location, color: Colors.green),
            tooltip: "Recheck Campus Access",
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // --- Top Glass Info Card ---
              // (unchanged code)
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
                  padding: const EdgeInsets.only(bottom: 100),
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
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    Center(
                      child: glassButton(
                        "➕ Add Player",
                        color: const Color(0xFFB9E4B1),
                        opacity: 0.25,
                        height: 38,
                        radius: 80,
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
                        if (_checkingLocation) {
                          showGlassAlert(
                            context,
                            "Checking location… please wait.",
                          );
                          return;
                        }

                        if (!_insideCampus) {
                          showGlassAlert(
                            context,
                            "Location did not verify. Please move near window / enable GPS.",
                          );
                          return;
                        }
                        _submitBooking();
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
                        if (!_insideCampus) {
                          showGlassAlert(
                            context,
                            "You must be inside IIT Ropar campus to use this feature",
                          );
                          return;
                        }
                        _broadcastLookingForPlayers();
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