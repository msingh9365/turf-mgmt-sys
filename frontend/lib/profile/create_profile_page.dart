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
            color: AppGreen.deep.withOpacity(0.28), // ✅ SAME COLOR
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
              color: AppGreen.deep, // ✅ SAME TEXT COLOR
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
  final _sportsCtrl = TextEditingController();

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDEEE1),

      // ❌ No back button → Custom AppBar
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Let's create your profile first ✨",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _sportsField(),
            const SizedBox(height: 20),
            _achievementsSection(),
            const SizedBox(height: 25),
            _submitButton(),
          ],
        ),
      ),
    );
  }

  Widget _sportsField() {
    return TextField(
      controller: _sportsCtrl,
      decoration: InputDecoration(
        labelText: "Interested Sports (e.g. Football, Badminton)",
        filled: true,
        fillColor: Colors.green.withOpacity(0.15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _achievementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Achievements",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),

        ...achievements.asMap().entries.map((sportEntry) {
          final sIndex = sportEntry.key;
          final sportBlock = sportEntry.value;
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
                  onChanged: (v) => achievements[sIndex]["sport"] = v,
                ),
                const SizedBox(height: 6),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Experience (optional)",
                  ),
                  onChanged: (v) => achievements[sIndex]["experience"] = v,
                ),
                const SizedBox(height: 12),

                ...sportBlock["records"].asMap().entries.map((rec) {
                  final rIndex = rec.key;
                  return Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Tournament",
                        ),
                        onChanged: (v) =>
                            achievements[sIndex]["records"][rIndex]["tournament"] =
                                v,
                      ),
                      TextField(
                        decoration: const InputDecoration(labelText: "Year"),
                        onChanged: (v) =>
                            achievements[sIndex]["records"][rIndex]["year"] = v,
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Achievement",
                        ),
                        onChanged: (v) =>
                            achievements[sIndex]["records"][rIndex]["achievement"] =
                                v,
                      ),
                      const Divider(),
                    ],
                  );
                }),

                TextButton(
                  onPressed: () {
                    setState(() {
                      achievements[sIndex]["records"].add({
                        "tournament": "",
                        "year": "",
                        "achievement": "",
                      });
                    });
                  },
                  child: const Text(
                    "+ Add More",
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
          );
        }),

        TextButton(
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
          child: const Text(
            "+ Add Another Sport",
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _submitButton() {
    return appPrimaryButton(text: "Submit & Continue", onTap: _submitProfile);
  }

  Future<void> _submitProfile() async {
    final uri = Uri.parse(
      "https://turf-mgmt-sys.onrender.com/api/profile/create/",
    );

    final body = {
      "sports": _sportsCtrl.text.trim(),
      "achievements": achievements,
    };

    final res = await _authService.authPost(uri, body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: ${res.body}")));
    }
  }
}

final _authService = AuthService();
