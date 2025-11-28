import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

Widget appPrimaryButton({required String text, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppGreen.deep.withOpacity(0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: AppGreen.deep.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: AppGreen.deep,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );
}

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _sportsCtrl = TextEditingController();

  late String _selectedAvatar;
  final List<String> avatarImages = [
    "avatar_1.png",
    "avatar_2.png",
    "avatar_3.png",
    "avatar_4.png",
    "avatar_5.png",
    "avatar_6.png",
    "avatar_7.png",
    "avatar_8.png",
    "avatar_9.png",
    "avatar_10.png",
    "avatar_11.png",
    "avatar_12.png",
  ];

  List<Map<String, dynamic>> achievements = [
    {
      "sport": "",
      "experience": "",
      "records": [
        {"tournament": "", "year": "", "achievement": ""},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = "avatar_1.png";
    _loadEmailFromToken();
  }

  Future<void> _loadEmailFromToken() async {
    final prefs = await SharedPreferences.getInstance();
    _emailCtrl.text = prefs.getString("user_email") ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDEEE1),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Let's create your profile ✨",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _openAvatarSelector(),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFD4E7D0),
                backgroundImage: AssetImage(
                  "assets/profile_avatars/$_selectedAvatar",
                ),
              ),
            ),
            const SizedBox(height: 20),
            _field("Name", _nameCtrl),
            _emailDisabledField(),
            _field("Mobile", _phoneCtrl),
            _field("Interested Sports", _sportsCtrl),

            const SizedBox(height: 20),
            _achievementsSection(),
            const SizedBox(height: 25),

            _submitButton(),
          ],
        ),
      ),
    );
  }

  Widget _emailDisabledField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _emailCtrl,
        enabled: false,
        style: const TextStyle(color: Colors.grey),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade300,
          labelText: "Email",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.green.withOpacity(0.15),
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _achievementsSection() {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Achievements",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        ...achievements.asMap().entries.map((entry) {
          int s = entry.key;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: "Sport"),
                  onChanged: (v) => achievements[s]["sport"] = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: "Experience"),
                  onChanged: (v) => achievements[s]["experience"] = v,
                ),
                const SizedBox(height: 8),
                ...achievements[s]["records"].asMap().entries.map((rec) {
                  int r = rec.key;
                  return Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Tournament",
                        ),
                        onChanged: (v) =>
                            achievements[s]["records"][r]["tournament"] = v,
                      ),
                      TextField(
                        decoration: const InputDecoration(labelText: "Year"),
                        onChanged: (v) =>
                            achievements[s]["records"][r]["year"] = v,
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Achievement",
                        ),
                        onChanged: (v) =>
                            achievements[s]["records"][r]["achievement"] = v,
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _openAvatarSelector() {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      backgroundColor: Colors.transparent,
      builder: (_) => _avatarSelector(),
    );
  }

  Widget _avatarSelector() {
    final pageController = PageController(viewportFraction: 0.85);

    return Container(
      height: 350,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: PageView.builder(
              controller: pageController,
              itemCount: avatarImages.length,
              itemBuilder: (_, i) {
                final avatar = avatarImages[i];
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAvatar = avatar);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        "assets/profile_avatars/$avatar",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _submitButton() {
    return appPrimaryButton(text: "Submit & Continue", onTap: _submitProfile);
  }

  Future<void> _submitProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showGlassAlert(context, "Name is required!");
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      showGlassAlert(context, "Mobile number is required!");
      return;
    }

    final data = {
      "name": _nameCtrl.text.trim(),
      "email": _emailCtrl.text.trim(),
      "phone": _phoneCtrl.text.trim(),
      "sports": _sportsCtrl.text.trim(),
      "avatar": _selectedAvatar,
      "achievements": achievements,
    };

    final res = await _authService.authPost(
      Uri.parse("https://turf-mgmt-sys.onrender.com/api/profile/create/"),
      data,
    );

    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      await ProfileCache.saveProfile(data); // 🔥 Save new profile
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      showGlassAlert(context, "Failed: ${res.body}");
    }
  }
}

final _authService = AuthService();
