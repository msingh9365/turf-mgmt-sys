import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'profile/create_profile_page.dart';
import 'api/notifications_api.dart';
import 'dart:async';

List<Map<String, dynamic>> globalNotifications = [];
int globalUnreadCount = 0;

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
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.requestPermission();

  // 🔐 Repair session if app opened after long inactive time
  final prefs = await SharedPreferences.getInstance();
  final jwt = prefs.getString("access_token");
  if (jwt != null) {
    print("🔍 Checking token validity on app startup…");
    if (!await AuthService().isTokenValid()) {
      print("⚠️ Access expired → attempting refresh…");
      final newToken = await AuthService().refreshAccessToken();
      if (newToken != null) {
        print("🔓 Refresh success → re-registering FCM");
        await PushTokenService.registerDeviceToken();
      } else {
        print("🚫 Refresh failed → user logged out automatically");
        await prefs.clear();
      }
    } else {
      print("🔑 Token still valid → re-registering FCM to be safe");
      await PushTokenService.registerDeviceToken();
    }
  }

  // 🔄 Auto re-register refreshed FCM tokens
  FirebaseMessaging.instance.onTokenRefresh.listen((_) {
    PushTokenService.registerDeviceToken();
  });

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

  // ⭐ store future target screen decided during intro
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();

    // ⭐ Start backend/auth check in background immediately
    _prepareNextScreen();

    _controller = VideoPlayerController.asset('assets/intro.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        _controller
          ..setLooping(false)
          ..setVolume(0.0)
          ..play();
        setState(() {});
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

  // ⭐ Background check asynchronous
  Future<void> _prepareNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString("access_token");
    final refresh = prefs.getString("refresh_token");

    if (access == null && refresh == null) {
      _targetScreen = const LoginPage();
      return;
    }

    final valid = await AuthService().isTokenValid();
    if (!valid && refresh != null) {
      final newAccess = await AuthService().refreshAccessToken();
      if (newAccess == null) {
        await prefs.clear();
        _targetScreen = const LoginPage();
        return;
      }
    }

    try {
      final response = await _authService.authGet(
        Uri.parse("https://turf-mgmt-sys.onrender.com/api/profile/me/"),
      );

      if (response.statusCode == 200) {
        await prefs.setBool("profile_created", true);
        _targetScreen = const HomePage();
        return;
      }
    } catch (_) {}

    _targetScreen = const CreateProfilePage();
  }

  void _goToHome() async {
    if (!mounted) return;

    // ⭐ If background check already done → direct skip to result
    if (_targetScreen != null) {
      _safeGo(_targetScreen!);
      return;
    }

    // ⚙️ Else, fallback to Splash Loading Screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashLoadingScreen()),
    );
  }

  // Prevents crashes + repeated navigation
  void _safeGo(Widget screen) {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    });
  }

  void _navigate(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

// ---------------------- Auth placeholder + helper UI ----------------------
class AuthService {
  Future<bool> login({required String email, required String password}) async {
    print("=== AuthService.login CALLED ===");
    print("Login email: $email, password length: ${password.length}");

    try {
      final uri = Uri.parse(
        'https://turf-mgmt-sys.onrender.com/api/auth/login/',
      );

      print("Sending POST to $uri");

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      print("Login response status: ${response.statusCode}");
      print("Login response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey('access') && data.containsKey('refresh')) {
          final accessToken = data['access'];
          final refreshToken = data['refresh'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken);
          await prefs.setString('refresh_token', refreshToken);

          await PushTokenService.registerDeviceToken();

          print("=== LOGIN SUCCESS: tokens saved ===");
          return true;
        } else {
          print("!!! LOGIN ERROR: 200 but no tokens in body");
        }
      } else {
        print("!!! LOGIN FAILED with status ${response.statusCode}");
      }
      return false;
    } catch (e, st) {
      print('!!! Login error (exception): $e');
      print(st);
      return false;
    }
  }
  // ==================== TEAM API CALLS ====================

  Future<http.Response> bulkUpdateMembers(
    int teamId,
    List<String> emails,
  ) async {
    final url = Uri.parse(
      "https://turf-mgmt-sys.onrender.com/api/teams/$teamId/bulk-update-members/",
    );
    return authPost(url, {"member_emails": emails});
  }

  Future<http.Response> transferCaptain(
    int teamId,
    int newCaptainUserId,
  ) async {
    final url = Uri.parse(
      "https://turf-mgmt-sys.onrender.com/api/teams/$teamId/transfer-captain/",
    );
    return authPost(url, {"new_captain_user_id": newCaptainUserId});
  }

  Future<bool> register({
    required String name,
    required String email,
    required String mobile,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(
        'https://turf-mgmt-sys.onrender.com/api/auth/register/',
      );

      // Extract sort_key (part before '@')
      final sortKey = email.split('@').first;
      print('${sortKey}');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'sort_key': sortKey,
          'phone': mobile,
        }),
      );

      print('Register response: ${response.statusCode}');
      print('Register body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  Future<bool> sendOtp({required String email}) async {
    final uri = Uri.parse("https://turf-mgmt-sys.onrender.com/api/otp/send/");
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    print("OTP SEND STATUS: ${res.statusCode} - ${res.body}");
    return res.statusCode == 200;
  }

  Future<bool> verifyOtp({required String email, required String otp}) async {
    final uri = Uri.parse("https://turf-mgmt-sys.onrender.com/api/otp/verify/");
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp": otp}),
    );
    print("OTP VERIFY STATUS: ${res.statusCode} - ${res.body}");
    return res.statusCode == 200;
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) async {
    final uri = Uri.parse(
      "https://turf-mgmt-sys.onrender.com/api/auth/reset-password/",
    );

    print("🔐 CALLING RESET PASSWORD API");
    print("📩 Email: $email");
    print("🔢 OTP: $otp");
    print("🔑 New Password Length: ${password.length}");

    final body = {"email": email, "otp": otp, "new_password": password};

    print("📦 REQUEST BODY: ${jsonEncode(body)}");

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("📡 RESET RESPONSE STATUS: ${res.statusCode}");
    print("📝 RESET RESPONSE BODY: ${res.body}");

    return res.statusCode == 200;
  }

  Future<bool> isTokenValid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");

    if (token == null) return false;

    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(token.split(".")[1]))),
    );

    final exp = payload["exp"] * 1000;
    return DateTime.now().millisecondsSinceEpoch < exp;
  }

  Future<String?> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString("refresh_token");

    if (refreshToken == null) return null;

    final uri = Uri.parse(
      "https://turf-mgmt-sys.onrender.com/api/auth/token/refresh/",
    );
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": refreshToken}),
    );

    if (res.statusCode == 200) {
      final newToken = jsonDecode(res.body)["access"];
      await prefs.setString("access_token", newToken);
      return newToken;
    }

    // ✅ Refresh failed → logout automatically
    await prefs.clear();
    return null;
  }

  Future<http.Response> authPut(Uri url, Map data) async {
    final prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString("access_token");

    if (!await isTokenValid()) {
      accessToken = await refreshAccessToken();
      if (accessToken == null) {
        await prefs.clear();
        throw Exception("Session expired. Please login again.");
      }
    }

    return http.put(
      url,
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );
  }

  Future<http.Response> authGet(Uri url) async {
    final prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString("access_token");

    if (!await isTokenValid()) {
      accessToken = await refreshAccessToken();
      if (accessToken == null) {
        await prefs.clear();
        throw Exception("Session expired. Please login again.");
      }
    }

    return http.get(url, headers: {"Authorization": "Bearer $accessToken"});
  }

  Future<void> _registerFcmDeviceWithBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('access_token');
    if (jwt == null) return;

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;

    await http.post(
      Uri.parse(
        'https://turf-mgmt-sys.onrender.com/api/notifications/register/',
      ),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'device_token': fcmToken, 'device_type': 'android'}),
    );
  }

  Future<http.Response> authDelete(Uri url) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token") ?? prefs.getString("token");

    return http.delete(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );
  }

  Future<http.Response> authPost(Uri url, Map data) async {
    final prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString("access_token");

    if (!await isTokenValid()) {
      accessToken = await refreshAccessToken();
      if (accessToken == null) {
        await prefs.clear();
        throw Exception("Session expired. Please login again.");
      }
    }

    return http.post(
      url,
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );
  }
}

final _authService = AuthService();

void showGlassAlert(BuildContext context, String message) {
  final overlay = OverlayEntry(
    builder: (context) => Positioned(
      top: 60, // top position
      left: MediaQuery.of(context).size.width * 0.1,
      right: MediaQuery.of(context).size.width * 0.1,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.25),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Overlay.of(context).insert(overlay);
  Future.delayed(const Duration(seconds: 2), () {
    overlay.remove();
  });
}

class PushTokenService {
  static Future<void> registerDeviceToken() async {
    print("🚀 registerDeviceToken() triggered");

    final prefs = await SharedPreferences.getInstance();
    String? jwt = prefs.getString("access_token");

    // No login yet → skip silently
    if (jwt == null) {
      print("⚠️ No JWT — skipping FCM registration");
      return;
    }

    // Refresh JWT if expired
    if (!await AuthService().isTokenValid()) {
      print("🔄 Access Token expired → refreshing...");
      jwt = await AuthService().refreshAccessToken();

      if (jwt == null) {
        print("❌ Refresh failed — skipping push token update");
        return;
      }
    }

    String? token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print("⚠️ No FCM Token yet — will auto retry later");
      return;
    }

    print("📲 FCM TOKEN: $token");

    try {
      final response = await http.post(
        Uri.parse(
          "https://turf-mgmt-sys.onrender.com/api/notifications/register/",
        ),
        headers: {
          "Authorization": "Bearer $jwt",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"device_token": token, "device_type": "android"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("🔥 Token Registered OK");
      } else {
        print(
          "❌ Device Token Register Failed → ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      print("⚠️ Device Token Register Error: $e");
    }
  }
}

// ---------------------- Glass Button ----------------------
Widget glassActionButton({
  required BuildContext context,
  required String label,
  required VoidCallback onTap,
  double height = 55,
  double radius = 18,
}) {
  return GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.35),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'], // ensures name/email/image come in token
    serverClientId:
        '806464575327-0sej44tk5f6ur3r4uiu1b1a8ht43eudv.apps.googleusercontent.com',
  );
  static Future<void> signOutFromGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
  }

  static Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) return false;

      print("ID TOKEN = $idToken\n"); // This is the token backend needs

      // Send exact backend required JSON format
      final response = await http.post(
        Uri.parse(
          "https://turf-mgmt-sys.onrender.com/api/auth/google/android/",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id_token": idToken}),
      );

      print("Google Login Response: ${response.statusCode} - ${response.body}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("access_token", data["access"]);
        await prefs.setString("refresh_token", data["refresh"]);

        // Wait and ensure token exists before sending to backend
        String? token = await FirebaseMessaging.instance.getToken();
        int attempts = 0;

        while (token == null && attempts < 5) {
          await Future.delayed(const Duration(seconds: 1));
          token = await FirebaseMessaging.instance.getToken();
          attempts++;
          print("Waiting for FCM token... attempt $attempts");
        }

        if (token != null) {
          print("🔥 Sending token to backend => $token");
          await PushTokenService.registerDeviceToken();
        } else {
          print("⚠️ Failed to fetch FCM token even after retries!");
        }

        print("=== GOOGLE LOGIN SUCCESS ===");
        return true;
      }

      return false;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) async {
    final uri = Uri.parse(
      "https://turf-mgmt-sys.onrender.com/api/auth/reset-password/",
    );

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp": otp, "new_password": password}),
    );

    print("RESET-PASSWORD STATUS: ${res.statusCode} - ${res.body}");

    return res.statusCode == 200;
  }
}

// ---------------------- LOGIN PAGE ----------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Widget _dividerLine() => Row(
    children: const [
      Expanded(child: Divider(thickness: 1.2, color: Colors.black26)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text("or", style: TextStyle(color: Colors.black54)),
      ),
      Expanded(child: Divider(thickness: 1.2, color: Colors.black26)),
    ],
  );

  Widget _frostedField(
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFAED581).withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
            ),
          ),
        ),
      ),
    );
  }

  Future<Widget> _decideNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");
    if (token == null) return const LoginPage();

    try {
      final res = await _authService.authGet(
        Uri.parse("https://turf-mgmt-sys.onrender.com/api/profile/me/"),
      );
      if (res.statusCode == 200) {
        return const HomePage(); // ✅ Profile exists
      }
    } catch (_) {}

    return const CreateProfilePage(); // ✅ No profile yet → move to create profile
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDECD6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Welcome to Campus Court",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Built by IITians for IITians",
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
                const SizedBox(height: 28),

                _frostedField(_emailCtrl, "Email"),
                const SizedBox(height: 12),
                _frostedField(_passCtrl, "Password", obscure: true),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: Text(
                      "Forgot password?",
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _loading
                    ? const CircularProgressIndicator(color: Colors.green)
                    : glassActionButton(
                        context: context,
                        label: "Login",
                        onTap: () async {
                          setState(() => _loading = true);

                          final ok = await _authService.login(
                            email: _emailCtrl.text.trim(),
                            password: _passCtrl.text,
                          );

                          setState(() => _loading = false);

                          if (ok) {
                            showGlassAlert(context, "Successfully logged in");
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SplashLoadingScreen(),
                              ),
                              (r) => false,
                            );
                          } else {
                            showGlassAlert(
                              context,
                              "Incorrect Email ID or Password",
                            );
                          }
                        },
                      ),

                const SizedBox(height: 18),

                _dividerLine(),
                const SizedBox(height: 18),

                _googleLoading
                    ? const CircularProgressIndicator(color: Colors.green)
                    : GestureDetector(
                        onTap: () async {
                          setState(() => _googleLoading = true);

                          await GoogleAuthService.signOutFromGoogle(); // Ensure email selection prompt
                          final ok = await GoogleAuthService.signInWithGoogle();

                          setState(() => _googleLoading = false);

                          if (ok) {
                            showGlassAlert(context, "Signed in Successfully");

                            // ⭐ Ensures token registered AFTER login + UI refresh
                            await PushTokenService.registerDeviceToken();

                            final nextScreen = await _decideNextScreen();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => nextScreen),
                              (r) => false,
                            );
                          } else {
                            showGlassAlert(context, "Google Sign-In Failed");
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF4CAF50,
                                ).withOpacity(0.35),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/google_logo.png',
                                    height: 24,
                                    width: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Sign in with Google",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don’t have an account? ",
                      style: TextStyle(fontSize: 15),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupPage()),
                        );
                      },
                      child: Text(
                        "Create account",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _repassCtrl = TextEditingController();

  bool _loading = false;
  bool _otpStep = false;
  bool _passwordStep = false;

  Widget _frostedField(
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
    TextInputType? kb,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFAED581).withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: kb,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (!_emailCtrl.text.trim().endsWith("@iitrpr.ac.in")) {
      showGlassAlert(context, "Use @iitrpr.ac.in Email");
      return;
    }

    setState(() => _loading = true);

    final success = await _authService.sendOtp(email: _emailCtrl.text.trim());

    setState(() => _loading = false);

    if (success) {
      showGlassAlert(context, "OTP Sent");
      setState(() => _otpStep = true);
    } else {
      showGlassAlert(context, "Invalid Email");
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _loading = true);

    final verified = await _authService.verifyOtp(
      email: _emailCtrl.text.trim(),
      otp: _otpCtrl.text.trim(),
    );

    setState(() => _loading = false);

    if (verified) {
      showGlassAlert(context, "OTP Verified");
      setState(() => _passwordStep = true);
    } else {
      showGlassAlert(context, "Incorrect OTP");
    }
  }

  Future<void> _resetPassword() async {
    if (_passCtrl.text.trim() != _repassCtrl.text.trim()) {
      showGlassAlert(context, "Passwords do not match");
      return;
    }

    setState(() => _loading = true);

    final ok = await _authService.resetPassword(
      email: _emailCtrl.text.trim(),
      otp: _otpCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );

    setState(() => _loading = false);

    if (ok) {
      showGlassAlert(context, "Password Reset Successful");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      showGlassAlert(context, "Failed to reset password");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDECD6),
      appBar: AppBar(
        backgroundColor: Colors.green.withOpacity(0.1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Forgot Password",
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _frostedField(
                  _emailCtrl,
                  "Enter IIT Ropar Email",
                  kb: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),

                if (_otpStep)
                  Column(
                    children: [
                      _frostedField(
                        _otpCtrl,
                        "Enter OTP",
                        kb: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                if (_passwordStep)
                  Column(
                    children: [
                      _frostedField(
                        _passCtrl,
                        "New Password (Minimum 6 char)",
                        obscure: true,
                      ),
                      const SizedBox(height: 12),
                      _frostedField(
                        _repassCtrl,
                        "Re-enter Password",
                        obscure: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                _loading
                    ? const CircularProgressIndicator(color: Colors.green)
                    : glassActionButton(
                        context: context,
                        label: !_otpStep
                            ? "Send OTP"
                            : !_passwordStep
                            ? "Verify OTP"
                            : "Submit",
                        onTap: !_otpStep
                            ? _sendOtp
                            : !_passwordStep
                            ? _verifyOtp
                            : _resetPassword,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------- SIGNUP PAGE ----------------------
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _pass = TextEditingController();
  final _repass = TextEditingController();
  bool _googleLoading = false;
  bool _otpStep = false;
  final _otpCtrl = TextEditingController();

  bool _loading = false;
  bool _otpVerified = false;

  Widget _dividerLine() => Row(
    children: const [
      Expanded(child: Divider(thickness: 1.2, color: Colors.black26)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text("or", style: TextStyle(color: Colors.black54)),
      ),
      Expanded(child: Divider(thickness: 1.2, color: Colors.black26)),
    ],
  );

  Widget _frostedField(
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
    TextInputType? kb,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFAED581).withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: kb,
            onChanged: (_) =>
                setState(() {}), // 🔥 Rebuild UI when text changes
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _trySignup() async {
    if (_pass.text.trim() != _repass.text.trim()) {
      showGlassAlert(context, "Passwords do not match");
      return;
    }

    // STEP 1 → Send OTP
    if (!_otpStep) {
      setState(() => _loading = true);
      final sent = await _authService.sendOtp(email: _email.text.trim());
      setState(() => _loading = false);

      if (sent) {
        showGlassAlert(context, "OTP Sent to your IITRPR Email 📩");
        setState(() => _otpStep = true);
      } else {
        showGlassAlert(context, "OTP Sending Failed ❌");
      }
      return;
    }

    // STEP 2 → Verify OTP then Register
    setState(() => _loading = true);
    final otpOk = await _authService.verifyOtp(
      email: _email.text.trim(),
      otp: _otpCtrl.text.trim(),
    );

    if (!otpOk) {
      setState(() => _loading = false);
      showGlassAlert(context, "Invalid OTP ❌");
      return;
    }

    showGlassAlert(context, "OTP Verified Successfully 🎉");

    final ok = await _authService.register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      mobile: _mobile.text.trim(),
      password: _pass.text.trim(),
    );
    setState(() => _loading = false);

    if (ok) {
      showGlassAlert(context, "Signup Successful 🚀");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      showGlassAlert(context, "Signup Failed ⚠️");
    }
  }

  Future<Widget> _decideNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString("access_token");

    // 🔐 No token at all → go to Login
    if (access == null) {
      return const LoginPage();
    }

    try {
      final res = await _authService.authGet(
        Uri.parse("https://turf-mgmt-sys.onrender.com/api/profile/me/"),
      );

      // ✅ Profile exists → straight to Home
      if (res.statusCode == 200) {
        return const HomePage();
      }

      // ❌ Any non-200 (404 / 403 / etc) → force Create Profile
      return const CreateProfilePage();
    } catch (e) {
      // 🌐 Network / parsing error → still push user to CreateProfile
      return const CreateProfilePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDECD6),
      appBar: AppBar(
        backgroundColor: Colors.green.withOpacity(0.1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Create Account",
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _frostedField(_name, "Full name"),
                const SizedBox(height: 10),
                _frostedField(
                  _email,
                  "Email (@iitrpr.ac.in)",
                  kb: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                _frostedField(
                  _mobile,
                  "Mobile number",
                  kb: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _frostedField(
                  _pass,
                  "Password (minimum 6 character)",
                  obscure: true,
                ),
                const SizedBox(height: 10),
                _frostedField(_repass, "Re-enter password", obscure: true),
                const SizedBox(height: 18),
                if (_loading)
                  const CircularProgressIndicator(color: Colors.green)
                else if (!_otpStep)
                  glassActionButton(
                    context: context,
                    label: "Submit",
                    onTap: _trySignup,
                  )
                else if (_otpStep) ...[
                  _frostedField(
                    _otpCtrl,
                    "Enter OTP",
                    kb: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // 🔹 Verify OTP Button (before signup)
                  Opacity(
                    opacity: _otpCtrl.text.trim().length == 6 ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: _otpCtrl.text.trim().length != 6,
                      child: glassActionButton(
                        context: context,
                        label: "Verify OTP",
                        onTap: () async {
                          setState(() => _loading = true);
                          final ok = await _authService.verifyOtp(
                            email: _email.text.trim(),
                            otp: _otpCtrl.text.trim(),
                          );
                          setState(() => _loading = false);

                          if (ok) {
                            showGlassAlert(context, "OTP Verified 🎉");
                            setState(
                              () => _otpVerified = true,
                            ); // 🔓 unlock signup button
                          } else {
                            showGlassAlert(context, "Invalid OTP ❌");
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 🔹 Resend OTP (instead of verify text)
                  GestureDetector(
                    onTap: () async {
                      final sent = await _authService.sendOtp(
                        email: _email.text.trim(),
                      );
                      if (sent) {
                        showGlassAlert(context, "OTP Resent 📩");
                      } else {
                        showGlassAlert(context, "Failed to resend OTP ❌");
                      }
                    },
                    child: Text(
                      "Resend OTP",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔹 Signup Only after OTP verified
                  Opacity(
                    opacity: _otpVerified ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: !_otpVerified,
                      child: glassActionButton(
                        context: context,
                        label: "Signup",
                        onTap: () async {
                          setState(() => _loading = true);
                          final ok = await _authService.register(
                            name: _name.text.trim(),
                            email: _email.text.trim(),
                            mobile: _mobile.text.trim(),
                            password: _pass.text.trim(),
                          );
                          setState(() => _loading = false);

                          if (ok) {
                            showGlassAlert(context, "Signup Successful 🚀");
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          } else {
                            showGlassAlert(context, "Signup Failed ⚠️");
                          }
                        },
                      ),
                    ),
                  ),
                ],
                if (!_otpStep) ...[
                  const SizedBox(height: 18),
                  _dividerLine(),
                  const SizedBox(height: 18),

                  _googleLoading
                      ? const CircularProgressIndicator(color: Colors.green)
                      : GestureDetector(
                          onTap: () async {
                            setState(() => _googleLoading = true);

                            await GoogleAuthService.signOutFromGoogle(); // Makes Google re-prompt email
                            final ok =
                                await GoogleAuthService.signInWithGoogle();

                            setState(() => _googleLoading = false);

                            if (ok) {
                              showGlassAlert(context, "Signed in Successfully");

                              // ⭐ Ensures token registered AFTER login + UI refresh
                              await PushTokenService.registerDeviceToken();

                              final nextScreen = await _decideNextScreen();
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => nextScreen),
                                (r) => false,
                              );
                            } else {
                              showGlassAlert(context, "Google Sign-In Failed");
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/google_logo.png',
                                      height: 24,
                                      width: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      "Sign up with Google",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> requestLocationPermission(BuildContext context) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    showGlassAlert(
      context,
      "Please enable location services for better experience",
    );
    return;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever ||
      permission == LocationPermission.denied) {
    showGlassAlert(
      context,
      "Location access is needed for campus-based features",
    );
    return;
  }
  final pos = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
  print("User Location: ${pos.latitude}, ${pos.longitude}");
}

Future<bool> isInsideCampus() async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false; // can't get location
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    const double campusLat = 30.9686;
    const double campusLon = 76.4733;
    const double allowedRadiusMeters = 2000;

    double distance = Geolocator.distanceBetween(
      campusLat,
      campusLon,
      pos.latitude,
      pos.longitude,
    );

    print("Current distance from campus: $distance meters");
    return distance <= allowedRadiusMeters;
  } catch (e) {
    print("Error checking location: $e");
    return false;
  }
}

// ---------------------- EVENT TRANSLATION + CACHE ----------------------

const Map<String, int> sportNameToId = {
  "Football": 1,
  "Basketball": 2,
  "Cricket": 3,
  "Tennis": 4,
  "Badminton": 5,
  "Volleyball": 6,
  "Hockey": 7,
  "Table Tennis": 8,
};

// Lowercase helper for free-text sport name input
final Map<String, int> sportNameToIdLower = {
  for (final e in sportNameToId.entries) e.key.toLowerCase(): e.value,
};

// Poster filename -> unique poster_id sent to backend
const Map<String, String> posterAssetToId = {
  // FOOTBALL
  "football_1.png": "101",
  "football_2.png": "102",
  "football_3.png": "103",
  "football_4.png": "104",
  "football_5.png": "105",

  // BASKETBALL
  "basketball_1.png": "201",
  "basketball_2.png": "202",
  "basketball_3.png": "203",
  "basketball_4.png": "204",
  "basketball_5.png": "205",

  // CRICKET
  "cricket_1.png": "301",
  "cricket_2.png": "302",
  "cricket_3.png": "303",
  "cricket_4.png": "304",
  "cricket_5.png": "305",

  // BADMINTON
  "badminton_1.png": "401",
  "badminton_2.png": "402",
  "badminton_3.png": "403",
  "badminton_4.png": "404",
  "badminton_5.png": "405",

  "hockey_1.jpg": "501",
  "table_tennis_1.jpg": "601",
  "volley_ball_1.jpg": "701",
  "tennis_1.jpg": "801",
};

// Reverse map: poster_id from backend -> asset filename
final Map<String, String> posterIdToAsset = {
  for (final e in posterAssetToId.entries) e.value: e.key,
};

// sport_id -> name (for details page)
final Map<int, String> sportIdToName = {
  for (final e in sportNameToId.entries) e.value: e.key,
};

class AppEvent {
  final int id;
  final String sportName;
  final String posterId;
  final String posterAsset;
  final String title;
  final String description;
  final String locationText;
  final DateTime startsAt;
  final String organizerContact;
  final String organizerName;
  final DateTime endsAt;

  AppEvent({
    required this.id,
    required this.sportName,
    required this.posterId,
    required this.posterAsset,
    required this.title,
    required this.description,
    required this.locationText,
    required this.startsAt,
    required this.endsAt,
    required this.organizerContact,
    required this.organizerName,
  });

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    final int sportId = json['sport_id'] is int ? json['sport_id'] as int : 0;

    // sport_id → sport_name mapping
    final String sportName = sportNameToId.entries
        .firstWhere(
          (e) => e.value == sportId,
          orElse: () => const MapEntry("Unknown", -1),
        )
        .key;

    // Poster mapping table (Backend poster_id → Asset)
    const Map<String, String> posterIdToAsset = {
      // Football
      "101": "football_1.png",
      "102": "football_2.png",
      "103": "football_3.png",
      "104": "football_4.png",
      "105": "football_5.png",

      // Basketball
      "201": "basketball_1.png",
      "202": "basketball_2.png",
      "203": "basketball_3.png",
      "204": "basketball_4.png",
      "205": "basketball_5.png",

      // Cricket
      "301": "cricket_1.png",
      "302": "cricket_2.png",
      "303": "cricket_3.png",
      "304": "cricket_4.png",
      "305": "cricket_5.png",

      // Badminton
      "401": "badminton_1.png",
      "402": "badminton_2.png",
      "403": "badminton_3.png",
      "404": "badminton_4.png",
      "405": "badminton_5.png",

      "501": "hockey_1.jpg",
      "601": "table_tennis_1.jpg",
      "701": "volley_ball_1.jpg",
      "801": "tennis_1.jpg",
    };

    final String posterId = json['poster_id']?.toString() ?? '';
    final String posterAsset = posterIdToAsset[posterId] ?? "default_event.png";

    return AppEvent(
      id: json['id'] ?? 0,
      sportName: sportName,
      posterId: posterId,
      posterAsset: posterAsset,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      locationText: json['location_text']?.toString() ?? '',
      startsAt:
          DateTime.tryParse(json['starts_at'] ?? '')?.toLocal() ??
          DateTime.now(),
      endsAt:
          DateTime.tryParse(json['ends_at'] ?? '')?.toLocal() ?? DateTime.now(),
      organizerContact: json['organizer_contact']?.toString() ?? '',
      organizerName: json['organizer_name']?.toString() ?? '',
    );
  }
}

class EventCache {
  static List<AppEvent> _events = [];

  static List<AppEvent> get events => _events;

  static void setEvents(List<AppEvent> newEvents) {
    _events = newEvents;
  }

  static AppEvent? getById(int id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static void clear() {
    _events = [];
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController(initialPage: 1000);
  late int _selectedIndex;

  bool _isLoadingEvents = false;
  String? _eventsError;
  List<AppEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _selectedIndex = navController.selectedIndex;
    navController.addListener(() {
      setState(() => _selectedIndex = navController.selectedIndex);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestLocationPermission(context);
      _loadEvents();
      _fetchProfileAndCache();
    });
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _eventsError = null;
    });

    try {
      final uri = Uri.parse("https://turf-mgmt-sys.onrender.com/api/events/");
      final res = await _authService.authGet(uri);

      print("EVENTS GET STATUS: ${res.statusCode}");
      print("EVENTS GET BODY: ${res.body}");

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        final List<dynamic> results =
            (decoded["results"] ?? []) as List<dynamic>;

        final events = results
            .map((e) => AppEvent.fromJson(e as Map<String, dynamic>))
            .toList();

        final now = DateTime.now();
        final activeEvents = events
            .where((e) => e.endsAt.isAfter(now))
            .toList();

        EventCache.setEvents(activeEvents);

        if (!mounted) return;
        setState(() {
          _events = activeEvents;
        });
      } else {
        if (!mounted) return;
        _eventsError = "Failed: ${res.statusCode}";
        showGlassAlert(context, _eventsError!);
      }
    } catch (e) {
      print("EVENTS GET ERROR: $e");
      if (!mounted) return;
      _eventsError = "Network error";
      showGlassAlert(context, "Network error while loading events");
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _fetchProfileAndCache() async {
    try {
      final res = await _authService.authGet(
        Uri.parse("https://turf-mgmt-sys.onrender.com/api/profile/me/"),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await ProfileCache.saveProfile(data);
        print("Profile updated in cache");
      }
    } catch (e) {
      print("Profile fetch failed: $e");
    }
  }

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Upcoming Events",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _loadEvents, // 👈 Manual refresh button
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 22,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),

                    // Add Event Button
                    GestureDetector(
                      onTap: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddEventPage(),
                          ),
                        );
                        if (created == true) {
                          await _loadEvents(); // 👈 Refresh fresh data after create
                        }
                      },
                      child: Icon(
                        Icons.add_circle_outline,
                        size: 26,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ✅ Swipable Event Cards
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Builder(
                    builder: (context) {
                      if (_isLoadingEvents) {
                        return Center(
                          child: SizedBox(
                            width: 420, // Increased from 120 → 220
                            height: 420,
                            child: Image.asset(
                              "assets/custom_loader.gif",
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      }

                      if (_events.isEmpty) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.green.shade100.withOpacity(0.5),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: const Text(
                              "No events to display",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }

                      return PageView.builder(
                        controller: _pageController,
                        itemCount: null, // infinite scrolling
                        itemBuilder: (context, index) {
                          final event =
                              _events[index % _events.length]; // LOOPING

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EventDetailsPage(eventId: event.id),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: FrostedGlassCard(
                                title: event.title,
                                location: event.locationText,
                                image: event.posterAsset.isNotEmpty
                                    ? "event_posters/${event.posterAsset}"
                                    : null,

                                endsAt: event.endsAt,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EventDetailsPage(eventId: event.id),
                                    ),
                                  );
                                },
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
                    onDotClicked: (index) {
                      _pageController.animateToPage(
                        _pageController.page!.toInt() -
                            (_pageController.page!.toInt() % _events.length) +
                            index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    },
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

class EventDetailsPage extends StatelessWidget {
  final int eventId;

  const EventDetailsPage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final event = EventCache.getById(eventId);

    if (event == null) {
      // Should not normally happen, but safe fallback
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: const Text(
            "Event Details",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(child: Text("Event not found in cache.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Event Details",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Top Image
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                "assets/event_posters/${event.posterAsset}",
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 20),
            _infoTile(
              "Tournament Title",
              event.title,
              Icons.emoji_events_outlined,
            ),

            _infoTile(
              "Organizer Name",
              event.organizerName.isEmpty
                  ? "Not provided"
                  : event.organizerName,
              Icons.person_outline,
            ),

            _infoTile(
              "Organizer Contact",
              event.organizerContact,
              Icons.call_outlined,
            ),

            _infoTile("Location", event.locationText, Icons.place_outlined),
            _infoTile("Sport", event.sportName, Icons.sports_soccer),

            _infoTile(
              "Start Date & Time",
              "${event.startsAt.day}-${event.startsAt.month}-${event.startsAt.year} • "
                  "${event.startsAt.hour.toString().padLeft(2, '0')}:${event.startsAt.minute.toString().padLeft(2, '0')}",
              Icons.schedule,
            ),

            _infoTile(
              "End Date & Time",
              "${event.endsAt.day}-${event.endsAt.month}-${event.endsAt.year} • "
                  "${event.endsAt.hour.toString().padLeft(2, '0')}:${event.endsAt.minute.toString().padLeft(2, '0')}",
              Icons.event_available_outlined,
            ),

            _contentTile(
              "Tournament Description",
              event.description.isEmpty
                  ? "No description provided."
                  : event.description,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green.shade200.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade400.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
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
                    color: Colors.black87,
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

  Widget _contentTile(String title, String content) {
    return Container(
      width: double.infinity, // 🟢 FULL WIDTH LIKE INFO TILES
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green.shade200.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade400.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class SplashLoadingScreen extends StatefulWidget {
  const SplashLoadingScreen({super.key});

  @override
  State<SplashLoadingScreen> createState() => _SplashLoadingScreenState();
}

class _SplashLoadingScreenState extends State<SplashLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");
    final profileCreated = prefs.getBool("profile_created") ?? false;

    await Future.delayed(const Duration(milliseconds: 800)); // smooth UX

    if (token == null) {
      _go(const LoginPage());
      return;
    }

    try {
      final res = await AuthService().authGet(
        Uri.parse("https://turf-mgmt-sys.onrender.com/api/profile/me/"),
      );

      if (res.statusCode == 200) {
        await prefs.setBool("profile_created", true);
        _go(const HomePage());
        return;
      }
    } catch (_) {}

    if (!profileCreated) {
      _go(const CreateProfilePage());
      return;
    }

    _go(const HomePage());
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFAAC4A0),
      body: Center(
        child: SizedBox(
          height: 420,
          width: 420,
          child: Image(
            image: AssetImage('assets/custom_loader.gif'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class ProfileCache {
  static const _key = "cached_profile";

  static Future<void> saveProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class AddEventPage extends StatefulWidget {
  const AddEventPage({super.key});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _sportController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _organizerNameController =
      TextEditingController();
  final TextEditingController _endDateTimeController = TextEditingController();

  String? _selectedPosterId;
  final Map<String, List<String>> sportPosters = {
    "football": [
      "football_1.png",
      "football_2.png",
      "football_3.png",
      "football_4.png",
      "football_5.png",
    ],
    "basketball": [
      "basketball_1.png",
      "basketball_2.png",
      "basketball_3.png",
      "basketball_4.png",
      "basketball_5.png",
    ],
    "cricket": [
      "cricket_1.png",
      "cricket_2.png",
      "cricket_3.png",
      "cricket_4.png",
      "cricket_5.png",
    ],
    "badminton": [
      "badminton_1.png",
      "badminton_2.png",
      "badminton_3.png",
      "badminton_4.png",
      "badminton_5.png",
    ],
    "hockey": ["hockey_1.jpg"],
    "table tennis": ["table_tennis_1.jpg"],
    "volley ball": ["volley_ball_1.jpg"],
    "tennis": ["tennis_1.jpg"],
    // Add remaining sports the same way
  };
  DateTime? _parsePrettyDateTime(String raw) {
    try {
      raw = raw.trim();

      // Expect format: "31 Dec 2025 , 4:00 PM"
      final parts = raw.split(',');
      if (parts.length != 2) return null;

      final datePart = parts[0].trim(); // "31 Dec 2025"
      final timePart = parts[1].trim().toUpperCase().replaceAll(" ", "");
      // Cleanup → "4:00PM"

      // Parse Date
      final dateElements = datePart.split(RegExp(r"\s+")); // spaces may vary
      if (dateElements.length != 3) return null;

      final day = int.parse(dateElements[0]);
      final monthName = dateElements[1];
      final year = int.parse(dateElements[2]);

      const months = {
        "JAN": 1,
        "FEB": 2,
        "MAR": 3,
        "APR": 4,
        "MAY": 5,
        "JUN": 6,
        "JUL": 7,
        "AUG": 8,
        "SEP": 9,
        "OCT": 10,
        "NOV": 11,
        "DEC": 12,
      };

      final month = months[monthName.toUpperCase()];
      if (month == null) return null;

      // Parse Time ("4:00PM")
      final match = RegExp(r'^(\d{1,2}):(\d{2})(AM|PM)$').firstMatch(timePart);
      if (match == null) return null;

      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      String period = match.group(3)!;

      // Convert PM → 24-hour
      if (period == "PM" && hour < 12) hour += 12;
      if (period == "AM" && hour == 12) hour = 0;

      // Construct local time → Convert to UTC
      return DateTime(year, month, day, hour, minute).toUtc();
    } catch (e) {
      print("Date Parse ERROR: $e");
      return null;
    }
  }

  Widget glassButton(
    String text, {
    required Color color,
    required VoidCallback onTap,
    double blur = 14,
    double opacity = 0.25,
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

  Widget _buildPosterSelector(String sport) {
    final posters = sportPosters[sport]!;
    final PageController pageController = PageController(
      viewportFraction: 0.98,
    );

    return Container(
      height: 380,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        color: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                // ✅ Circular Swipe Indicator
                SmoothPageIndicator(
                  controller: pageController,
                  count: posters.length,
                  effect: WormEffect(
                    dotHeight: 9,
                    dotWidth: 9,
                    type: WormType.thinUnderground,
                    spacing: 8,
                    activeDotColor: Colors.white,
                    dotColor: Colors.white.withOpacity(0.4),
                  ),
                ),

                const SizedBox(height: 20),

                // ✅ Poster Swiper (Wider + Shorter + Full visible)
                Expanded(
                  child: PageView.builder(
                    controller: pageController,
                    scrollDirection: Axis.horizontal,
                    itemCount: posters.length,
                    itemBuilder: (context, index) {
                      final posterId = posters[index];

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedPosterId = posterId);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: double.infinity,
                          height: 180, // << Reduced Height Here ✅
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              "assets/event_posters/$posterId",
                              fit: BoxFit.contain, // << Full Image Visible ✅
                              alignment: Alignment.center,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDEEE1), // ✅ EXACT SAME BACKGROUND
      appBar: AppBar(
        backgroundColor: Colors.green.withOpacity(0.05),
        elevation: 0,
        title: const Text(
          "Post Event",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------- EVENT DETAILS INPUTS (Same UI as AddTeamPage) --------
              TextField(
                controller: _sportController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFBFE3C0).withOpacity(0.3),
                  labelText: "Sport Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() => _selectedPosterId = null),
              ),
              const SizedBox(height: 12),

              // ✅ POSTER SELECTION BOX
              GestureDetector(
                onTap: () {
                  final sport = _sportController.text.trim().toLowerCase();
                  if (!sportPosters.containsKey(sport)) {
                    showGlassAlert(
                      context,
                      "Please enter a valid sport name first.",
                    );
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    barrierColor: Colors.black.withOpacity(0.35),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) => _buildPosterSelector(sport.toLowerCase()),
                  );
                },
                child: Container(
                  height: 240,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: _selectedPosterId == null
                      ? const Center(
                          child: Text(
                            "Tap to Select Event Poster",
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            "assets/event_posters/$_selectedPosterId",
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFBFE3C0).withOpacity(0.3),
                  labelText: "Event Title",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 🔹 Event Location
              TextField(
                controller: _locationController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFBFE3C0).withOpacity(0.3),
                  labelText: "Event Location",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _dateTimeController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFBFE3C0).withOpacity(0.3),
                  labelText: "Start Date (e.g. 12 Feb 2025 , 4:00 PM)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _contactController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFBFE3C0).withOpacity(0.3),
                  labelText: "Organizer Contact",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _organizerNameController,
                decoration: InputDecoration(
                  labelText: "Organizer Name",
                  filled: true,
                  fillColor: const Color(0xFFBFE3C0).withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _endDateTimeController,
                decoration: InputDecoration(
                  labelText: "End Date (e.g. 12 Feb 2025 , 4:00 PM)",
                  filled: true,
                  fillColor: const Color(0xFFBFE3C0).withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _detailsController,
                maxLines: 4,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFBFE3C0).withOpacity(0.3),
                  labelText: "Event Description",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // -------- POST BUTTON (Same as Create Team Button) --------
              glassButton(
                "Post Event",
                color: const Color(0xFF2E7D32),
                opacity: 0.3,
                onTap: () async {
                  final title = _titleController.text.trim();
                  final sportName = _sportController.text.trim();
                  final location = _locationController.text.trim();
                  final contact = _contactController.text.trim();
                  final description = _detailsController.text.trim();
                  final organizerName = _organizerNameController.text.trim();

                  if (title.isEmpty ||
                      sportName.isEmpty ||
                      location.isEmpty ||
                      contact.isEmpty ||
                      description.isEmpty ||
                      _selectedPosterId == null) {
                    showGlassAlert(
                      context,
                      "Please fill all fields and select a poster.",
                    );
                    return;
                  }

                  final sportId = sportNameToIdLower[sportName.toLowerCase()];
                  if (sportId == null) {
                    showGlassAlert(
                      context,
                      "Invalid sport name. Use one of: ${sportNameToId.keys.join(", ")}",
                    );
                    return;
                  }
                  // Translate selected poster filename -> unique poster_id
                  final posterId =
                      posterAssetToId[_selectedPosterId!] ?? _selectedPosterId!;

                  final startsAt = _parsePrettyDateTime(
                    _dateTimeController.text.trim(),
                  );
                  final endsAt = _parsePrettyDateTime(
                    _endDateTimeController.text.trim(),
                  );

                  if (startsAt == null || endsAt == null) {
                    showGlassAlert(
                      context,
                      "Invalid date format. Example:\n12 Feb 2025 , 4:00 PM",
                    );
                    return;
                  }

                  final payload = {
                    "title": title,
                    "description": description,
                    "organizer_name": organizerName,
                    "organizer_contact": contact,
                    "starts_at": startsAt.toIso8601String(),
                    "ends_at": endsAt.toIso8601String(),
                    "poster_id": posterId,
                    "sport_id": sportId,
                    "location_text": location,
                  };

                  print("EVENT CREATE PAYLOAD: $payload");

                  try {
                    final uri = Uri.parse(
                      "https://turf-mgmt-sys.onrender.com/api/events/",
                    );
                    final res = await _authService.authPost(uri, payload);

                    print(
                      "EVENT CREATE STATUS: ${res.statusCode} - ${res.body}",
                    );

                    if (res.statusCode == 200 || res.statusCode == 201) {
                      if (!context.mounted) return;
                      showGlassAlert(context, "Event created successfully");
                      Navigator.pop(context, true);
                      return;
                    }

                    // ❌ Any error response becomes:
                    if (!context.mounted) return;
                    showGlassAlert(
                      context,
                      "You are not authorized to post an event",
                    );
                  } catch (e) {
                    print("EVENT CREATE ERROR: $e");

                    if (!context.mounted) return;
                    showGlassAlert(
                      context,
                      "You are not authorized to post an event",
                    );
                    const SizedBox(height: 30);
                  }
                  ;
                },
              ),
            ],
          ),
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
  final VoidCallback? onTap;
  final DateTime endsAt;

  const FrostedGlassCard({
    super.key,
    required this.title,
    required this.location,
    this.image,
    required this.endsAt,
    this.onTap,
  });

  @override
  State<FrostedGlassCard> createState() => _FrostedGlassCardState();
}

class _FrostedGlassCardState extends State<FrostedGlassCard> {
  bool _isHovered = false;

  String _getRemainingTime(DateTime endsAt) {
    final now = DateTime.now();
    final diff = endsAt.difference(now);

    if (diff.isNegative) return "Ended";

    if (diff.inDays >= 1) {
      return "Ends in ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}";
    } else if (diff.inHours >= 1) {
      return "Ends in ${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}";
    } else if (diff.inMinutes >= 1) {
      return "Ends in ${diff.inMinutes} min";
    } else {
      return "Ending soon!";
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap, // 👈 navigation handled by parent only
      child: MouseRegion(
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

                    // Gradient overlay for better text readability
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

                    // 🔥 Countdown badge (time remaining)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getRemainingTime(widget.endsAt),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Bottom Info (Glass pill)
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
                              color: const Color(0xFFE8F5E9).withOpacity(0.35),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.location,
                                  textAlign: TextAlign.center,
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
              {
                'image': 'assets/hockey_ground1.png',
                'title': 'Hockey Ground 1',
              },
            ];
            break;

          case 'Table Tennis':
            grounds = [
              {
                'image': 'assets/table_tennis_ground1.png',
                'title': 'Table Tennis Room 1',
              },
              {
                'image': 'assets/table_tennis_ground2.png',
                'title': 'Table Tennis Room 2',
              },
              {
                'image': 'assets/table_tennis_ground3.png',
                'title': 'Table Tennis Room 3',
              },
              {
                'image': 'assets/table_tennis_ground4.png',
                'title': 'Table Tennis Room 4',
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
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Football Ground',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
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
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Basketball Ground',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
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

int _globalSelectedDateIndex = 0; // persists last selected date globally

class SlotBookingPage extends StatefulWidget {
  final String sportName;
  final String groundName;
  String slotDate;
  final List<String>? customSlots;

  SlotBookingPage({
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
  'Table Tennis': {
    'Table Tennis Room 1': [
      '4:00 PM - 4:30 PM',
      '4:30 PM - 5:00 PM',
      '5:00 PM - 5:30 PM',
      '5:30 PM - 6:00 PM',
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
      '7:00 PM - 7:30 PM',
      '7:30 PM - 8:00 PM',
    ],
    'Table Tennis Room 2': [
      '4:00 PM - 4:30 PM',
      '4:30 PM - 5:00 PM',
      '5:00 PM - 5:30 PM',
      '5:30 PM - 6:00 PM',
    ],
    'Table Tennis Room 3': [
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
      '7:00 PM - 7:30 PM',
      '7:30 PM - 8:00 PM',
    ],
    'Table Tennis Room 4': [
      '5:30 PM - 6:00 PM',
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
      '7:00 PM - 7:30 PM',
    ],
  },

  'Volleyball': {
    'Volleyball Court 1': [
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
      '7:00 PM - 7:30 PM',
      '7:30 PM - 8:00 PM',
      '8:00 PM - 8:30 PM',
    ],
  },

  'Hockey': {
    'Hockey Ground 1': [
      '4:00 PM - 4:30 PM',
      '4:30 PM - 5:00 PM',
      '5:00 PM - 5:30 PM',
      '5:30 PM - 6:00 PM',
      '6:00 PM - 6:30 PM',
      '6:30 PM - 7:00 PM',
    ],
  },
};
final Map<String, int> slotNameToId = slotIdMap.map(
  (key, value) => MapEntry(value, key),
);

final Map<int, String> slotIdToName = slotIdMap;

class _SlotBookingPageState extends State<SlotBookingPage> {
  late List<String> _slots;
  final Set<String> _selectedSlots = {};
  int _selectedDateIndex = 0;
  final ScrollController _dateScrollController = ScrollController();
  Set<String> _bookedSlots = {};
  bool _loadingSlots = true;

  @override
  void initState() {
    super.initState();
    _ensureMinPlayers();
    _selectedDateIndex = _globalSelectedDateIndex;
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
    _fetchBookedSlots();
  }

  @override
  void dispose() {
    _dateScrollController.dispose(); // clean up controller memory
    super.dispose();
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

  Future<void> _fetchBookedSlots() async {
    setState(() => _loadingSlots = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");
    if (token == null) return;

    final groundId = groundNameToId[widget.groundName]; // reverse lookup
    final date = widget.slotDate; // already YYYY-MM-DD
    print("DEBUG - sport: ${widget.sportName}");
    print("DEBUG - groundName: '${widget.groundName}'");
    print("DEBUG - groundId lookup: ${groundNameToId[widget.groundName]}");
    print("ALL groundNameToId KEYS: ${groundNameToId.keys.toList()}");

    final response = await _authService.authGet(
      Uri.parse(
        "https://turf-mgmt-sys.onrender.com/api/bookings/booked-slots/?date=$date&ground_id=$groundId",
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> ids = data["booked_slot_ids"];

      setState(() {
        _bookedSlots = ids
            .map((id) => slotIdToName[id] ?? "")
            .where((name) => name.isNotEmpty)
            .toSet();
        _loadingSlots = false;
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
                      color: const Color(0xFFCDE7C4),
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

            // --- 7-Day Date Selector (refined UI + auto-scroll + color matched) ---
            SizedBox(
              height: 82,
              child: ListView.builder(
                controller: _dateScrollController, // ✅ new scroll controller
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));

                  final formatted =
                      "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                  final weekday = [
                    "Sun",
                    "Mon",
                    "Tue",
                    "Wed",
                    "Thu",
                    "Fri",
                    "Sat",
                  ][date.weekday % 7];

                  final isSelected = _selectedDateIndex == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDateIndex = index;
                        _globalSelectedDateIndex = index;

                        // ✅ Update the current selected date string
                        final newDate = DateTime.now().add(
                          Duration(days: index),
                        );
                        final formattedDate =
                            "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";

                        // ✅ Update the widget's current slot date (no page reload)
                        widget.slotDate = formattedDate;

                        // ✅ Optionally clear previous slot selections (if needed)
                        _selectedSlots.clear();
                        _fetchBookedSlots();
                      });

                      // ✅ Smooth scroll keeps selected date in view
                      _dateScrollController.animateTo(
                        (index - 1).clamp(0, 6) * 105.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 95,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green.shade800.withOpacity(0.25)
                            : Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.shade800.withOpacity(
                                  0.45,
                                ) // same as selected slot
                              : Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              weekday,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatted,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // --- Slot grid (Glass effect) ---
            Expanded(
              child: _loadingSlots
                  ? Center(
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Image.asset(
                          "assets/custom_loader.gif",
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 2.7,
                          ),
                      itemCount: _slots.length,
                      itemBuilder: (context, index) {
                        final time = _slots[index];
                        final isSelected = _selectedSlots.contains(time);
                        final isBooked = _bookedSlots.contains(time);

                        return GestureDetector(
                          onTap: isBooked ? null : () => _toggleSlot(time),
                          child: Opacity(
                            opacity: isBooked ? 0.45 : 1.0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 15,
                                  sigmaY: 15,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isBooked
                                        ? Colors.red.shade900.withOpacity(0.22)
                                        : isSelected
                                        ? Colors.green.shade800.withOpacity(
                                            0.65,
                                          )
                                        : Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isBooked
                                          ? Colors.red.shade900.withOpacity(
                                              0.35,
                                            )
                                          : Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    time,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isBooked
                                          ? Colors.red.shade900
                                          : isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                    showGlassAlert(context, "Please select at least one slot");
                    return;
                  }

                  //  Sort slots in chronological order for checking continuity
                  final sortedSlots =
                      _slots.where((s) => _selectedSlots.contains(s)).toList()
                        ..sort(
                          (a, b) =>
                              _slots.indexOf(a).compareTo(_slots.indexOf(b)),
                        );

                  bool continuous = true;
                  for (int i = 1; i < sortedSlots.length; i++) {
                    int prevIndex = _slots.indexOf(sortedSlots[i - 1]);
                    int currIndex = _slots.indexOf(sortedSlots[i]);
                    if (currIndex - prevIndex != 1) {
                      continuous = false;
                      break;
                    }
                  }

                  if (!continuous) {
                    showGlassAlert(
                      context,
                      "Please select continuous slots only",
                    );
                    return;
                  }

                  // ✅ All good → Navigate to next screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FinalSlotBookingPage(
                        sport: widget.sportName,
                        ground: widget.groundName,
                        slotDate: widget.slotDate,
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
                        color: Color(0xFF4CAF50).withOpacity(0.45),
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

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final PageController _pageController = PageController();

  final List<Widget> pages = [
    HomePage(),
    NotificationPage(),
    TeamsPage(),
    BookingHistoryPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    navController.addListener(() {
      _pageController.animateToPage(
        navController.selectedIndex,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDECD6),

      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => navController.setIndex(i),
        children: pages,
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
    FirebaseMessaging.onMessage.listen((_) => setState(() {}));
    FirebaseMessaging.onMessageOpenedApp.listen((_) => setState(() {}));
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
                      case 0:
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const HomePage(),
                          ),
                          (route) => false,
                        );
                        break;
                      case 1:
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => NotificationPage(),
                          ),
                          (route) => false,
                        );
                        break;
                      case 2:
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const TeamsPage(),
                          ),
                          (route) => false,
                        );
                        break;
                      case 3:
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const BookingHistoryPage(),
                          ),
                          (route) => false,
                        );
                        break;
                      case 4:
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const ProfilePage(),
                          ),
                          (route) => false,
                        );
                        break;
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
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          icons[index],
                          color: isSelected
                              ? Colors.greenAccent.shade100
                              : Colors.white.withOpacity(0.8),
                          size: 26,
                        ),

                        // ✅ Only show badge on Notifications icon
                        if (index == 1 && globalNotifications.isNotEmpty)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                globalNotifications.length > 99
                                    ? "99+"
                                    : globalNotifications.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
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
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select $sportName Ground',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // to balance the back button space
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
    FirebaseMessaging.onMessage.listen((_) => _loadAndRecount());
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _loadAndRecount());
  }

  Future<void> _loadAndMarkRead() async {
    await _loadAndRecount();
    await markAllNotificationsRead();
    setState(() {});
  }

  Future<void> _loadAndRecount() async {
    final list = await fetchNotificationsFromBackend();
    if (!mounted) return;
    globalNotifications = list;
    globalUnreadCount = list.where((n) => !(n['is_read'] ?? false)).length;
    setState(() {});
  }

  // ⭐ ADDED — CLEAR ALL NOTIFICATIONS ⭐
  void _clearAllNotifications() {
    setState(() {
      globalNotifications.clear();
      globalUnreadCount = 0;
    });
  }

  Future<void> markAllNotificationsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('access_token');
    if (jwt == null) return;

    await http.post(
      Uri.parse(
        'https://turf-mgmt-sys.onrender.com/api/notifications/mark-all-read/',
      ),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    for (final n in globalNotifications) {
      n['is_read'] = true;
    }
    globalUnreadCount = 0;
  }

  @override
  Widget build(BuildContext context) {
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
          onRefresh: _loadAndRecount,
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

              // ⭐ Swipable notifications
              for (final item in notifications)
                Dismissible(
                  key: Key(item.hashCode.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() {
                      globalNotifications.remove(item);
                      globalUnreadCount = globalNotifications
                          .where((n) => !(n['is_read'] ?? false))
                          .length;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _NotificationTile(item: item),
                  ),
                ),

              const SizedBox(height: 20),

              // ⭐ CLEAR ALL BUTTON — bottom right alignment
              if (globalNotifications.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _clearAllNotifications,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.green.shade700.withOpacity(0.4),
                        ),
                      ),
                      child: const Text(
                        "Clear All",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
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

    // ⭐ If it's the placeholder "No Notifications" message → show plain centered text ⭐
    if (title == "No Notifications") {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Center(
          child: Text(
            "No Notifications Yet",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              color: Colors.black.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // ⭐ Normal Notification Tile ⭐
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
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.45),
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

// ================== 🔗 BACKEND CONFIG ==================
const String BASE_URL = "https://turf-mgmt-sys.onrender.com";

// Endpoints
const String TEAMS_LIST_PATH = "/api/teams/"; // GET all, POST create
const String TEAMS_BY_SPORT_PATH = "/api/teams/by-sport/"; // GET ?sport_id=
const String TEAM_DETAILS_PATH = "/api/teams/{id}/"; // GET /api/teams/3/

// ================== 🧱 DATA MODELS ==================
// ================== 🧱 DATA MODELS ==================
class TeamSummary {
  final String id;
  final String name;

  TeamSummary({required this.id, required this.name});

  factory TeamSummary.fromJson(Map<String, dynamic> j) => TeamSummary(
    id: "${j['team_id'] ?? j['id']}",
    name: "${j['team_name'] ?? j['name']}",
  );
}

class TeamMember {
  final int userId;
  final String name;
  final String role;

  TeamMember({required this.userId, required this.name, required this.role});

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    userId: j['user_id'] ?? 0,
    name: j['name'] ?? '',
    role: j['role'] ?? '',
  );
}

class TeamDetails {
  final int teamId;
  final String teamName;
  final String captainName;
  final String sportName;
  final int sportId;
  final int memberCount;
  final DateTime createdAt;
  final List<TeamAchievement> achievements;
  final List<TeamMember> members;

  TeamDetails({
    required this.teamId,
    required this.teamName,
    required this.captainName,
    required this.sportName,
    required this.sportId,
    required this.memberCount,
    required this.createdAt,
    required this.achievements,
    required this.members,
  });

  factory TeamDetails.fromJson(Map<String, dynamic> j) {
    final captain = j['captain'] as Map<String, dynamic>?;
    final sport = j['sport'] as Map<String, dynamic>?;

    return TeamDetails(
      teamId: j['team_id'] ?? 0,
      teamName: j['team_name'] ?? '',
      captainName: captain?['name'] ?? '',
      sportName: sport?['sport_name'] ?? '',
      sportId: sport?['sport_id'] ?? 0,
      memberCount: j['member_count'] ?? 0,
      createdAt:
          DateTime.tryParse(j['created_at'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      achievements: (j['achievements'] as List<dynamic>? ?? [])
          .map((x) => TeamAchievement.fromJson(x as Map<String, dynamic>))
          .toList(),
      members: (j['members'] as List<dynamic>? ?? [])
          .map((x) => TeamMember.fromJson(x as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TeamAchievement {
  final String title;
  final String description;
  final DateTime? date;

  TeamAchievement({
    required this.title,
    required this.description,
    required this.date,
  });

  factory TeamAchievement.fromJson(Map<String, dynamic> j) => TeamAchievement(
    title: j['title']?.toString() ?? '',
    description: j['description']?.toString() ?? '',
    date: j['date'] != null ? DateTime.tryParse(j['date'].toString()) : null,
  );
}

// ================== 🔐 API CLIENT ==================
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token") ?? prefs.getString("token");
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Uri _buildUri(String path, [Map<String, String>? q]) {
    final uri = Uri.parse(BASE_URL + path);
    return q == null ? uri : uri.replace(queryParameters: q);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    Map<String, String>? pathParams,
  }) async {
    String resolved = path;
    pathParams?.forEach((k, v) => resolved = resolved.replaceAll("{$k}", v));

    final res = await http.get(
      _buildUri(resolved, query),
      headers: await _headers(),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : {"data": data};
    }
    throw Exception("GET $resolved failed: ${res.statusCode} ${res.body}");
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? pathParams,
  }) async {
    String resolved = path;
    pathParams?.forEach((k, v) => resolved = resolved.replaceAll("{$k}", v));

    final res = await http.post(
      _buildUri(resolved),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : {"data": data};
    }

    throw Exception("POST $resolved failed: ${res.statusCode} ${res.body}");
  }
}

// ================== 📦 REPOSITORY ==================
class TeamsRepository {
  final _api = ApiClient.instance;

  /// 1) Teams for a sport (backend: GET /api/teams/by-sport/?sport_id=ID)
  Future<List<TeamSummary>> fetchTeamsBySport(String sportId) async {
    final j = await _api.getJson(
      TEAMS_BY_SPORT_PATH,
      query: {"sport_id": sportId},
    );

    final list = (j["data"] as List<dynamic>? ?? []);
    return list
        .map((e) => TeamSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 2) Team details (backend: GET /api/teams/{id}/)
  Future<TeamDetails> fetchTeamDetails(String teamId) async {
    final j = await _api.getJson(TEAM_DETAILS_PATH, pathParams: {"id": teamId});
    // /api/teams/{id}/ returns a plain object
    final data = (j["data"] as Map<String, dynamic>?) ?? j;
    return TeamDetails.fromJson(data);
  }

  /// 3) Create team (backend: POST /api/teams/)
  Future<TeamDetails> createTeam(Map<String, dynamic> payload) async {
    final j = await _api.postJson(TEAMS_LIST_PATH, body: payload);
    final data = (j["data"] as Map<String, dynamic>?) ?? j;
    return TeamDetails.fromJson(data);
  }

  // ================= 🔥 New API Calls for Invitations =================
  Future<void> sendMatchInvite({
    required int senderTeamId,
    required int targetTeamId,
    required String preferredDate,
    required int groundId,
    String? message,
  }) async {
    final body = {
      "sender_team_id": senderTeamId,
      "target_team_id": targetTeamId,
      "preferred_date": preferredDate,
      "ground_id": groundId,
    };

    if (message != null && message.isNotEmpty) {
      body["message"] = message;
    }

    print("📤 Sending Invite Request: $body");

    final res = await _api.postJson(
      "/api/teams/invitations/match-invite/",
      body: body,
    );

    print("📬 Invite Sent Response: $res");
  }

  Future<List<dynamic>> fetchSentInvites() async {
    print("📡 Fetching SENT invitations...");
    print("📌 API: /api/teams/invitations/sent/");

    final res = await _api.getJson("/api/teams/invitations/sent/");

    print("📬 SENT API Response:");
    print(res);

    final list = (res["invitations"] as List<dynamic>? ?? []);
    print("📊 Total SENT invitations loaded: ${list.length}");

    return res["invitations"] ?? [];
  }

  Future<List<dynamic>> fetchReceivedInvites() async {
    print("📡 Fetching RECEIVED invitations...");
    print("📌 API: /api/teams/invitations/received/");

    final res = await _api.getJson("/api/teams/invitations/received/");

    print("📬 RECEIVED API Response:");
    print(res);

    final list = (res["invitations"] as List<dynamic>? ?? []);
    print("📊 Total RECEIVED invitations loaded: ${list.length}");

    return res["invitations"] ?? [];
  }

  Future<List<Map<String, dynamic>>> fetchCaptainTeams(int sportId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");

    final uri = Uri.parse(
      "https://turf-mgmt-sys.onrender.com/api/teams/captain/?sport_id=$sportId",
    );

    print("📡 FETCHING CAPTAIN TEAMS for sport_id=$sportId");

    final res = await http.get(
      uri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    print("CAPTAIN TEAM STATUS: ${res.statusCode}");
    print("BODY: ${res.body}");

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }
}

final TeamsRepository teamsRepo = TeamsRepository();

// ================== 🆕 TEAMS MAIN PAGE (UI UNCHANGED) ==================
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

      // 🆕 AppBar Added Here
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5E9),
        elevation: 0,
        title: const Text(
          "Teams List",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeamInviteHistoryPage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history_rounded, color: Colors.green, size: 22),
                  SizedBox(width: 4),
                  Text(
                    "Invitation History",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

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
                        final int? id = sportNameToId[name.trim()];
                        if (id == null) {
                          print("❌ No id mapping for: $name");
                          showGlassAlert(context, "Invalid sport selected");
                          return;
                        }

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

final Map<String, List<int>> sportGrounds = {
  "Football": [1],
  "Cricket": [2, 3],
  "Hockey": [4],
  "Basketball": [5, 6],
  "Badminton": [7, 8, 9, 10],
  "Tennis": [11, 12],
  "Table Tennis": [13, 14, 15, 16],
  "Volleyball": [17],
};

class TeamInviteHistoryPage extends StatefulWidget {
  const TeamInviteHistoryPage({super.key});

  @override
  State<TeamInviteHistoryPage> createState() => _TeamInviteHistoryPageState();
}

class _TeamInviteHistoryPageState extends State<TeamInviteHistoryPage> {
  bool showSent = true;

  Future<List<dynamic>> _load() {
    return showSent
        ? teamsRepo.fetchSentInvites()
        : teamsRepo.fetchReceivedInvites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5E9),
        elevation: 0,
        title: const Text(
          "Team Invite History",
          style: TextStyle(color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // Toggle Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _tab("Sent", showSent, () {
                setState(() => showSent = true);
              }),
              const SizedBox(width: 10),
              _tab("Received", !showSent, () {
                setState(() => showSent = false);
              }),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _load(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      "Error: ${snap.error}",
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final invites = snap.data ?? [];
                if (invites.isEmpty) {
                  return const Center(
                    child: Text(
                      "No invitations found",
                      style: TextStyle(color: Colors.black87),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: invites.length,
                  itemBuilder: (_, i) {
                    final inv = invites[i];

                    // Map response data
                    final teamName = inv["team_name"] ?? "Unknown Team";
                    final sport = inv["sport_name"] ?? "Unknown Sport";
                    final status =
                        inv["status_display"] ?? inv["status"] ?? "-";
                    final created = (inv["created_at"] ?? "")
                        .toString()
                        .split("T")
                        .first;

                    final matchDetails = inv["match_details"] ?? {};
                    final message = matchDetails["message"] ?? "";

                    final senderName = inv["sender_name"] ?? "";
                    final senderEmail = inv["sender_email"] ?? "";
                    final recipientName = inv["recipient_name"] ?? "";
                    final recipientEmail = inv["recipient_email"] ?? "";

                    final preferredDate = matchDetails["preferred_date"] ?? "";
                    final groundId = matchDetails["ground_id"];
                    final groundName = groundId != null
                        ? groundIdMap[groundId] ?? ""
                        : "";

                    final isSent = showSent;

                    print("📌 Invite: $teamName | $sport | $status");
                    print(
                      "🗓️ Date: $preferredDate | GroundId: $groundId → $groundName",
                    );

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
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
                          // Team + Status Row
                          Row(
                            children: [
                              const Icon(Icons.groups, color: Colors.green),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "$teamName ($sport)",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: status == "ACCEPTED"
                                      ? Colors.green.shade700
                                      : status == "DECLINED"
                                      ? Colors.red.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Created: $created",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          if (message.trim().isNotEmpty) ...[
                            Text(
                              "“$message”",
                              style: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          Text(
                            isSent
                                ? "Sent To: $recipientName\nEmail: $recipientEmail"
                                : "Sent By: $senderName\nEmail: $senderEmail",
                            style: const TextStyle(fontSize: 14),
                          ),

                          const SizedBox(height: 6),

                          // 🆕 Show match date
                          if (preferredDate.isNotEmpty)
                            Text(
                              "Match Date: $preferredDate",
                              style: const TextStyle(fontSize: 14),
                            ),

                          // 🆕 Show translated ground name
                          if (groundName.isNotEmpty)
                            Text(
                              "Ground: $groundName",
                              style: const TextStyle(fontSize: 14),
                            ),

                          const SizedBox(height: 10),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.green.shade700.withOpacity(0.4)
              : Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ================== 🆕 TEAM LIST PAGE (UI LOOK KEPT) ==================
class TeamListPage extends StatelessWidget {
  final String sportName;

  const TeamListPage({super.key, required this.sportName});
  Future<List<TeamSummary>> _fetch() {
    final int? sportId = sportNameToId[sportName.trim()];
    if (sportId == null) return Future.value([]);
    return teamsRepo.fetchTeamsBySport(sportId.toString());
  }

  @override
  Widget build(BuildContext context) {
    navController.setIndex(-1);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5E9),
        elevation: 0,
        title: Text(
          "$sportName Teams",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTeamPage(sportName: sportName),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: FutureBuilder<List<TeamSummary>>(
          future: _fetch(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  "Failed to load teams\n${snap.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              );
            }
            final teams = snap.data ?? <TeamSummary>[];
            if (teams.isEmpty) {
              return const Center(
                child: Text(
                  "No teams found.",
                  style: TextStyle(color: Colors.black87),
                ),
              );
            }

            return ListView.builder(
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: GestureDetector(
                    onTap: () async {
                      // 🔹 Send teamId to backend, details page will fetch and render
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamDetailsPage(
                            teamId: team.id,
                            teamName: team.name,
                            sportName: sportName,
                          ),
                        ),
                      );
                    },
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
                                team.name,
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
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}

// ================== 🆕 TEAM DETAILS PAGE (UI KEPT, DATA FROM BACKEND) ==================
// ================== 🆕 UPDATED TEAM DETAILS PAGE ==================
class TeamDetailsPage extends StatefulWidget {
  final String teamId;
  final String teamName;
  final String sportName;

  const TeamDetailsPage({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.sportName,
  });

  @override
  State<TeamDetailsPage> createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  List<Map<String, dynamic>> captainTeams = [];
  bool _isInviting = false;

  @override
  void initState() {
    super.initState();
    _loadCaptainTeams();
  }

  Future<void> _loadCaptainTeams() async {
    final sportId = sportNameToId[widget.sportName.trim()] ?? -1;

    print(
      "🎯 Fetching captain teams for sport: ${widget.sportName}, id=$sportId",
    );

    try {
      final result = await teamsRepo.fetchCaptainTeams(sportId);
      print("📌 Captain Teams Loaded: $result");

      if (!mounted) return;
      setState(() {
        captainTeams = result;
      });
    } catch (e) {
      print("❌ Error loading captain teams: $e");
      // leave captainTeams empty → invite button disabled
    }
  }

  Future<TeamDetails> _fetch() {
    return teamsRepo.fetchTeamDetails(widget.teamId);
  }

  String _fmtYMD(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')} ${_mon(d.month)} ${d.year}";

  String _mon(int m) {
    const mm = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (m >= 1 && m <= 12) ? mm[m - 1] : '';
  }

  void _showInviteDialog(BuildContext context, int targetTeamId) {
    // Option A: button is disabled when captainTeams.isEmpty
    if (captainTeams.isEmpty) return;

    int? selectedSenderTeamId = captainTeams.first["team_id"];
    String? selectedDate;
    TextEditingController msgCtrl = TextEditingController();
    int? selectedGroundId;

    final List<String> dateOptions = List.generate(30, (i) {
      final d = DateTime.now().add(Duration(days: i));
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    });

    final String sport = widget.sportName.trim();
    final List<int> allowedGrounds = sportGrounds[sport] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFE8F5E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Match Invite Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 🆕 Sender Team Dropdown
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: "Select Your Team (Sender)",
                        border: OutlineInputBorder(),
                      ),
                      value: selectedSenderTeamId,
                      items: captainTeams.map((t) {
                        return DropdownMenuItem(
                          value: t["team_id"] as int,
                          child: Text(
                            "${t["team_name"]} (ID: ${t["team_id"]})",
                          ),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedSenderTeamId = v),
                    ),
                    const SizedBox(height: 15),

                    // Preferred Date
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Preferred Match Date",
                        border: OutlineInputBorder(),
                      ),
                      value: selectedDate,
                      items: dateOptions
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: (v) => setSheetState(() => selectedDate = v),
                    ),
                    const SizedBox(height: 15),

                    // Ground Dropdown
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: "Select Ground",
                        border: OutlineInputBorder(),
                      ),
                      value: selectedGroundId,
                      items: allowedGrounds
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Text(groundIdMap[g] ?? "Ground $g"),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedGroundId = v),
                    ),
                    const SizedBox(height: 15),

                    // Message
                    TextField(
                      controller: msgCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Message (Optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 25),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700.withOpacity(0.5),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () async {
                        if (selectedSenderTeamId == null ||
                            selectedDate == null ||
                            selectedGroundId == null) {
                          showGlassAlert(ctx, "Fill all required fields");
                          return;
                        }

                        Navigator.pop(ctx);

                        setState(
                          () => _isInviting = true,
                        ); // ⏳ Start Loading UI

                        print("============== Invite Request ==============");
                        print("Sender Team ID: $selectedSenderTeamId");
                        print("Target Team ID: $targetTeamId");
                        print("Preferred Date: $selectedDate");
                        print("Ground ID: $selectedGroundId");
                        print("Message: ${msgCtrl.text}");
                        print("============================================");

                        try {
                          await teamsRepo.sendMatchInvite(
                            senderTeamId: selectedSenderTeamId!,
                            targetTeamId: targetTeamId,
                            preferredDate: selectedDate!,
                            groundId: selectedGroundId!,
                            message: msgCtrl.text.trim().isEmpty
                                ? null
                                : msgCtrl.text.trim(),
                          );

                          if (!mounted) return;
                          showGlassAlert(
                            context,
                            "Invitation Sent Successfully!",
                          );
                        } catch (e) {
                          print("❌ Invite Error: $e");
                          if (!mounted) return;
                          showGlassAlert(context, "Failed to send invite");
                        }

                        if (!mounted) return;
                        setState(() => _isInviting = false); // 🛑 Stop loading
                      },
                      child: const Text("Invite Team"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTile(String title, String value, IconData icon) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5E9),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.teamName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: FutureBuilder<TeamDetails>(
        future: _fetch(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            print("❌ ERROR loading team details: ${snap.error}");
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  "Failed to load team details.\nPlease try again later.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(
              child: Text(
                "No data available.",
                style: TextStyle(color: Colors.black87),
              ),
            );
          }

          final data = snap.data!;

          final achievementsStrings = data.achievements.map((a) {
            final dateStr = a.date != null ? " (${_fmtYMD(a.date!)})" : "";
            return "🏆 ${a.title}${dateStr} — ${a.description}";
          }).toList();

          // ✅ Use the sport name passed from UI (your choice A)
          final String sportName = widget.sportName.trim().isEmpty
              ? "Unknown"
              : widget.sportName.trim();

          final membersCount = data.memberCount.toString();
          final leader = data.captainName.isEmpty ? "-" : data.captainName;
          final created = data.createdAt.millisecondsSinceEpoch == 0
              ? "-"
              : _fmtYMD(data.createdAt);

          print("📌 LOADED: sport_id=${data.sportId} → sport=$sportName");

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTile("Sport", sportName, Icons.sports_soccer_rounded),
                _buildTile(
                  "Date of Creation",
                  created,
                  Icons.calendar_today_rounded,
                ),
                _buildTile(
                  "Team Members",
                  membersCount,
                  Icons.people_alt_rounded,
                ),
                _buildTile("Team Leader", leader, Icons.person_rounded),

                // Members List
                Container(
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
                        children: const [
                          Icon(Icons.groups, color: Colors.green),
                          SizedBox(width: 10),
                          Text(
                            "Members List",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (data.members.isEmpty)
                        const Text(
                          "• No members yet",
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        )
                      else
                        ...data.members.map(
                          (m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  m.role == "captain"
                                      ? Icons.star_rounded
                                      : Icons.person_outline_rounded,
                                  color: m.role == "captain"
                                      ? Colors.orange
                                      : Colors.green,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "${m.name} — ${m.role}",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Achievements
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: Colors.green.shade700,
                          ),
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
                      if (achievementsStrings.isEmpty)
                        const Text(
                          "• No achievements yet",
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        )
                      else
                        ...achievementsStrings.map(
                          (a) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              "• $a",
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),

      // 🆕 New Invite Button UI + Captain check (Option A)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(14),
        child: GestureDetector(
          onTap: captainTeams.isEmpty
              ? null
              : () => _showInviteDialog(context, int.parse(widget.teamId)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Container(
              height: 55,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: captainTeams.isEmpty
                    ? Colors.grey.withOpacity(0.5)
                    : const Color(0xFF2E7D32).withOpacity(0.5),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Text(
                "Invite Team",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================== 🎨 YOUR EXISTING COLORS & ADD TEAM PAGE (UNCHANGED) ==================
class AppGreen {
  static const Color deep = Color(0xFF2E7D32); // primary action
  static const Color mid = Color(0xFF4CAF50); // secondary
  static const Color light = Color(0xFFBFE3C0); // fills
  static const Color card = Color(0xFFE8F5E9); // backgrounds
  static const Color ink = Colors.black87;
}

/// ------------------------------------
/// ADD / EDIT TEAM PAGE (exactly as you shared; no visual changes)
/// ------------------------------------
class AddTeamPage extends StatefulWidget {
  final String sportName;
  final Map<String, dynamic>? existingTeam;

  const AddTeamPage({super.key, required this.sportName, this.existingTeam});

  @override
  State<AddTeamPage> createState() => _AddTeamPageState();
}

class _AddTeamPageState extends State<AddTeamPage> {
  final TextEditingController _teamNameController = TextEditingController();
  final List<TextEditingController> _playerEmails = [];
  final List<Map<String, TextEditingController>> _achievements = [];
  final TextEditingController _leaderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Minimum 2 emails for racket sports, else follow your existing logic
    int minPlayers = _getMinPlayers(widget.sportName);

    // Init empty email fields
    for (int i = 0; i < minPlayers; i++) {
      _playerEmails.add(TextEditingController());
    }

    // One empty achievement by default
    _addAchievement();
  }

  int _getMinPlayers(String sport) {
    switch (sport) {
      case 'Football':
        return 7;
      case 'Basketball':
        return 5;
      case 'Cricket':
        return 11;
      case 'Volleyball':
        return 6;
      case 'Hockey':
        return 11;
      case 'Tennis':
      case 'Badminton':
      case 'Table Tennis':
        return 2;
      default:
        return 5;
    }
  }

  void _addPlayerEmail() {
    setState(() => _playerEmails.add(TextEditingController()));
  }

  void _addAchievement() {
    setState(() {
      _achievements.add({
        "title": TextEditingController(),
        "description": TextEditingController(),
        "date": TextEditingController(),
      });
    });
  }

  void _submitTeam() async {
    final teamName = _teamNameController.text.trim();
    if (teamName.isEmpty) return showGlassAlert(context, "Enter Team Name");

    final emails = _playerEmails
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final minPlayers = _getMinPlayers(widget.sportName);
    if (emails.length < minPlayers) {
      showGlassAlert(context, "At least $minPlayers players required.");
      return;
    }

    final int? sportId = sportNameToId[widget.sportName.trim()];
    if (sportId == null) {
      print("❌ No sport id for ${widget.sportName}");
      showGlassAlert(context, "Invalid sport");
      return;
    }

    List<Map<String, String>> achievementsList = _achievements
        .map(
          (a) => {
            "title": a["title"]!.text.trim(),
            "description": a["description"]!.text.trim(),
            "date": a["date"]!.text.trim(),
          },
        )
        .where((a) => a["title"]!.isNotEmpty)
        .toList();

    final payload = {
      "team_name": teamName,
      "sport_id": sportId,
      "member_emails": emails,
      "achievements": achievementsList,
    };

    print("📤 Sending Payload: $payload");

    try {
      final created = await teamsRepo.createTeam(payload);
      showGlassAlert(context, "Team '${created.teamName}' created!");
      Navigator.pop(context);
    } catch (e) {
      print("❌ Backend Error: $e");
      showGlassAlert(context, "Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final minPlayers = _getMinPlayers(widget.sportName);

    return Scaffold(
      backgroundColor: const Color(0xFFDDEEE1),
      appBar: AppBar(
        backgroundColor: AppGreen.card.withOpacity(0.25),
        elevation: 0,
        title: const Text(
          "Create Team",
          style: TextStyle(color: AppGreen.ink, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: AppGreen.ink),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ SPORT TITLE + MIN PLAYERS SPLASH CARD
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppGreen.card.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppGreen.mid.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sportName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppGreen.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Minimum players required: $minPlayers",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ✅ TEAM NAME
            TextField(
              controller: _teamNameController,
              decoration: _input("Team Name"),
              style: const TextStyle(color: AppGreen.ink),
            ),

            const SizedBox(height: 12),

            // ✅ TEAM LEADER NAME
            TextField(
              controller: _leaderNameController, // ADD THIS CONTROLLER UP TOP
              decoration: _input("Team Leader Name"),
              style: const TextStyle(color: AppGreen.ink),
            ),

            const SizedBox(height: 20),

            // ✅ PLAYER EMAIL LIST
            const Text(
              "Player Emails",
              style: TextStyle(
                color: AppGreen.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            ..._playerEmails.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controller,
                  decoration: _input("Player ${index + 1} Email"),
                  style: const TextStyle(color: AppGreen.ink),
                ),
              );
            }),

            Center(
              child: _glassButton("➕ Add Player Email", onTap: _addPlayerEmail),
            ),
            const SizedBox(height: 25),

            // ✅ ACHIEVEMENTS SECTION
            const Text(
              "Achievements",
              style: TextStyle(
                color: AppGreen.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            ..._achievements.asMap().entries.map((entry) {
              final map = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppGreen.card.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppGreen.mid.withOpacity(0.25)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: map["title"],
                      decoration: _input("Title"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: map["description"],
                      decoration: _input("Description"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: map["date"],
                      decoration: _input("Date (YYYY-MM-DD)"),
                    ),
                  ],
                ),
              );
            }),

            Center(
              child: _glassButton("➕ Add Achievement", onTap: _addAchievement),
            ),
            const SizedBox(height: 35),

            // ✅ SUBMIT BUTTON
            _glassButton("Create Team", onTap: _submitTeam, primary: true),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label) => InputDecoration(
    filled: true,
    fillColor: AppGreen.light.withOpacity(0.3),
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _glassButton(
    String text, {
    required Function() onTap,
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary
              ? AppGreen.deep.withOpacity(0.4)
              : AppGreen.mid.withOpacity(0.3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------
/// PROFILE PAGE
/// ------------------------------------
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String name = "John Doe";
  String email = "john.doe@gmail.com";
  String phone = "+91 9876543210";
  String sports = "Football, Cricket";

  List<Map<String, dynamic>> achievements = [];
  List<Map<String, dynamic>> teamsList = [];
  String? selectedAvatar = "avatar_1.png"; // default

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _fetchProfile(); // ✅ Fetch profile when page loads
  }

  Future<void> _loadCachedProfile() async {
    final cached = await ProfileCache.getProfile();
    if (cached != null && mounted) {
      setState(() {
        name = cached["name"];
        email = cached["email"];
        phone = cached["phone"];
        sports = cached["sports"];
        selectedAvatar =
            cached["avatar"] ?? cached["selectedAvatar"] ?? "avatar_1.png";
        achievements = List<Map<String, dynamic>>.from(
          cached["achievements"] ?? [],
        );
        teamsList = List<Map<String, dynamic>>.from(cached["teams"] ?? []);
      });
    }
  }

  Future<void> _fetchProfile() async {
    final res = await _authService.authGet(
      Uri.parse("https://turf-mgmt-sys.onrender.com/api/profile/me/"),
    );

    if (res.statusCode != 200) return;

    final raw = jsonDecode(res.body);
    final profile = raw["profile"];

    print("===== RAW PROFILE JSON =====");
    const JsonEncoder encoder = JsonEncoder.withIndent("  ");
    print(encoder.convert(profile));
    print("===== END OF PROFILE JSON =====");
    final teams = profile["teams"] ?? [];
    for (var i = 0; i < teams.length; i++) {
      final t = teams[i];
      print("--- TEAM $i ---");
      print("team_id: ${t['team_id']}");
      print("teamId: ${t['teamId']}");
      print("team_name: ${t['team_name']}");
      print("sport_name: ${t['sport_name']}");
      print("sport: ${t['sport']}");
      print("is_captain: ${t['is_captain']}");
      print(t);
    }
    print("===============");

    // ----------- GROUP ACHIEVEMENTS BY SPORT ----------
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var a in profile["achievements"] ?? []) {
      final sport = a["sport"] ?? "Unknown Sport";
      grouped[sport] ??= [];
      grouped[sport]!.add({
        "tournament": a["title"] ?? "",
        "year": a["year"]?.toString() ?? "",
        "achievement": a["achievement"] ?? "",
        "experience": a["experience"]?.toString() ?? "",
      });
    }

    achievements = grouped.entries
        .map((e) => {"sport": e.key, "records": e.value})
        .toList();

    // ----------- FIX TEAMS DATA  -----------
    // ----------- TEAMS DATA (NO FRONTEND FILTERING) -----------
    final rawTeams = (profile["teams"] ?? []) as List;

    teamsList = rawTeams.map<Map<String, dynamic>>((t) {
      return {
        "teamId": t["team_id"] ?? 0,
        "teamName": t["team_name"] ?? "",
        "sport": t["sport_name"] ?? "Unknown Sport",
        "leader": t["captain_name"] ?? "",
        "createdOn": t["created_on"] ?? "",
        "isLeader": (t["is_captain"] ?? 0) == 1,
        "is_captain": t["is_captain"] ?? 0, // keep raw value too
        "members": List<Map<String, dynamic>>.from(t["members"] ?? []),
      };
    }).toList();

    // ----------- BASIC FIELDS -----------
    selectedAvatar = profile["avatar_id"] ?? "avatar_1.png";
    name = profile["name"];
    email = profile["email"];
    phone = profile["phone"];

    sports = (profile["interested_sports"] ?? [])
        .map((s) => s["sport_name"])
        .join(", ");

    // ----------- CACHE LATEST DATA -----------
    await ProfileCache.saveProfile(profile);

    setState(() {});
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("access_token");
    await prefs.remove("token");

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _highlightTile({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade900.withOpacity(0.30)),
      ),
      child: child,
    );
  }

  bool get _isProfileLoaded =>
      name != "John Doe" &&
      email != "john.doe@gmail.com" &&
      email.isNotEmpty &&
      name.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF1),
      body: SafeArea(
        child: !_isProfileLoaded
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 25,
                ),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppGreen.ink,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            // Go to Edit Profile page
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditProfilePage(
                                  name: name,
                                  email: email,
                                  phone: phone,
                                  sports: sports,
                                  achievements: achievements,
                                  teamsList: teamsList,
                                  selectedAvatar:
                                      selectedAvatar, // pass current avatar
                                ),
                              ),
                            );

                            // 🔁 After returning, always pull latest profile from backend
                            await _fetchProfile();
                          },

                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.green.shade600.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.green.shade700.withOpacity(0.4),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: AppGreen.deep,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Edit Profile",
                                  style: TextStyle(
                                    color: AppGreen.deep,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Profile Avatar (NO CONST!)
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: const Color(0xFFD4E7D0),
                      backgroundImage: AssetImage(
                        'assets/profile_avatars/${selectedAvatar ?? "avatar_1.png"}',
                      ),
                    ),
                    const SizedBox(height: 25),

                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        color: AppGreen.ink,
                      ),
                    ),
                    const SizedBox(height: 25),

                    _buildInfoTile("Email", email, Icons.email),
                    _buildInfoTile("Mobile", phone, Icons.phone),
                    _buildInfoTile(
                      "Interested Sports",
                      sports,
                      Icons.sports_soccer,
                    ),

                    _buildAchievementsCard(),
                    _buildTeamsSection(),

                    const SizedBox(height: 30),

                    glassActionButton(
                      context: context,
                      label: "Sign Out",
                      onTap: () => _logout(),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }

  Widget _buildAchievementsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(15),
      decoration: _greenCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: AppGreen.deep),
              const SizedBox(width: 10),
              const Text(
                "Achievements",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppGreen.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...achievements.map((sportBlock) {
            final String sport = sportBlock['sport'];
            final List records = sportBlock['records'] ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: _innerTileDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sport,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppGreen.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...records.map((r) {
                    return _highlightTile(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${r['tournament']} • ${r['year']}",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (r['achievement'] != null)
                            Text("Achievement: ${r['achievement']}"),
                          if (r['experience'] != null)
                            Text("Experience: ${r['experience']}"),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTeamsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(15),
      decoration: _greenCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_rounded, color: AppGreen.deep),
              const SizedBox(width: 10),
              const Text(
                "Team Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppGreen.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...teamsList.map((team) {
            return _highlightTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team['teamName'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text("Sport: ${team['sport']}"),
                  Text("Leader: ${team['leader']}"),
                  Text("Created On: ${team['createdOn']}"),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  BoxDecoration _greenCardDecoration() {
    return BoxDecoration(
      color: AppGreen.card.withOpacity(0.9),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppGreen.mid.withOpacity(0.25)),
      boxShadow: [
        BoxShadow(
          color: AppGreen.mid.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  BoxDecoration _innerTileDecoration() {
    return BoxDecoration(
      color: AppGreen.light.withOpacity(0.35),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppGreen.mid.withOpacity(0.4)),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: _greenCardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: AppGreen.deep),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
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

class EditTeamPage extends StatefulWidget {
  final int teamId;
  final String sportName;

  const EditTeamPage({
    super.key,
    required this.teamId,
    required this.sportName,
  });

  @override
  State<EditTeamPage> createState() => _EditTeamPageState();
}

class _EditTeamPageState extends State<EditTeamPage> {
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _leaderNameController = TextEditingController();

  bool _isLeader = true; // ✅ You only reach here as captain from Profile

  List<TextEditingController> _memberEmails = [];
  List<Map<String, TextEditingController>> _achievements = [];

  bool _loading = true;
  List<Map<String, dynamic>> _members = [];
  String _captainEmail = "";

  @override
  void initState() {
    super.initState();
    _fetchTeam(); // ✅ single source of truth
  }

  Future<void> _fetchTeam() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");
      if (token == null) {
        showGlassAlert(context, "Not logged in");
        return;
      }

      final url = Uri.parse("$BASE_URL/api/teams/${widget.teamId}/");
      final res = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode != 200) {
        showGlassAlert(context, "Failed to load team details");
        setState(() => _loading = false);
        return;
      }

      final data = jsonDecode(res.body);

      // ✅ Basic info
      _teamNameController.text = data["team_name"] ?? "";
      _leaderNameController.text = data["captain"]?["name"] ?? "";
      _captainEmail = data["captain"]?["email"] ?? "";

      // ✅ Members from backend: expect user_id, name, email, role
      _members = List<Map<String, dynamic>>.from(data["members"] ?? []);

      // You’re opening as captain anyway, but keep this for safety
      _isLeader = true;

      // ✅ Prefill member emails (exclude captain)
      _memberEmails = _members
          .where((m) => m["role"] != "captain")
          .map((m) => TextEditingController(text: m["email"] ?? ""))
          .toList();

      // 🔥 FIXED – Prefill Achievements for both formats
      _achievements.clear();

      final ach = data["achievements"];

      if (ach is List) {
        // Normal backend format (list of objects)
        for (var a in ach) {
          _achievements.add({
            "title": TextEditingController(text: a["title"] ?? ""),
            "description": TextEditingController(text: a["description"] ?? ""),
            "date": TextEditingController(
              text: (a["date"]?.toString().split("T").first) ?? "",
            ),
          });
        }
      } else if (ach is String && ach.trim().isNotEmpty) {
        // New backend format: comma-separated string
        for (var item in ach.split(",")) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) {
            _achievements.add({
              "title": TextEditingController(text: trimmed),
              "description": TextEditingController(text: ""),
              "date": TextEditingController(text: ""),
            });
          }
        }
      }

      // If nothing parsed → ensure at least one field shows
      if (_achievements.isEmpty) _addAchievement();
    } catch (e) {
      print("❌ Team load failed: $e");
      showGlassAlert(context, "Failed to load team details!");
    }

    setState(() => _loading = false);
  }

  void _addEmail() {
    setState(() => _memberEmails.add(TextEditingController()));
  }

  void _addAchievement() {
    setState(() {
      _achievements.add({
        "title": TextEditingController(),
        "description": TextEditingController(),
        "date": TextEditingController(),
      });
    });
  }

  Future<void> _updateTeamDetails() async {
    // ✅ Convert controllers → plain list of emails
    final emails = _memberEmails
        .map((c) => c.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (emails.isEmpty) {
      showGlassAlert(context, "Team must have at least 1 member!");
      return;
    }

    final achievementsPayload = _achievements
        .where((a) => a["title"]!.text.trim().isNotEmpty)
        .map(
          (a) => {
            "title": a["title"]!.text.trim(),
            "description": a["description"]!.text.trim(),
            "date": a["date"]!.text.trim(),
          },
        )
        .toList();

    final payload = {
      "member_emails": emails,
      "achievements": achievementsPayload,
    };

    try {
      final res = await _authService.authPost(
        Uri.parse("$BASE_URL/api/teams/${widget.teamId}/bulk-update/"),
        payload,
      );

      if (res.statusCode == 200) {
        showGlassAlert(context, "Team Updated Successfully!");

        await Future.delayed(const Duration(milliseconds: 600));

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
          (route) => false,
        );
      } else {
        print("❌ Bulk update failed: ${res.statusCode} ${res.body}");
        showGlassAlert(context, "Failed to update team");
      }
    } catch (e) {
      print("❌ Bulk update error: $e");
      showGlassAlert(context, "Network error while updating team");
    }
  }

  Future<void> _transferCaptain(int newCaptainUserId) async {
    final payload = {"new_captain_user_id": newCaptainUserId};

    final res = await _authService.authPost(
      Uri.parse("$BASE_URL/api/teams/${widget.teamId}/transfer-captain/"),
      payload,
    );

    if (res.statusCode == 200) {
      showGlassAlert(context, "Captain Transferred Successfully!");

      await Future.delayed(const Duration(milliseconds: 600));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
        (route) => false,
      );
    } else {
      showGlassAlert(context, "Failed to transfer captain");
    }
  }

  void _showTransferCaptainModal() {
    int? _selectedUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                height:
                    MediaQuery.of(context).size.height *
                    0.55, // Responsive height
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 45,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    const Center(
                      child: Text(
                        "Select New Captain",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _members
                              .where((m) => m["role"] != "captain")
                              .map((m) {
                                final int id = m["user_id"] ?? 0;
                                return Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: RadioListTile<int>(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    title: Text(
                                      m["name"] ?? "Unknown",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(m["email"] ?? ""),
                                    value: id,
                                    groupValue: _selectedUserId,
                                    activeColor: Colors.green,
                                    onChanged: (value) => setModalState(
                                      () => _selectedUserId = value,
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Action button
                    _glassButton("Transfer Captaincy", () async {
                      if (_selectedUserId == null) {
                        showGlassAlert(context, "Select a member first!");
                        return;
                      }

                      Navigator.pop(context); // Close sheet

                      await Future.delayed(const Duration(milliseconds: 250));

                      await _transferCaptain(_selectedUserId!);
                    }, color: Colors.blue),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _glassButton(
    String text,
    VoidCallback tap, {
    Color color = Colors.green,
    double opacity = 0.25,
  }) {
    return GestureDetector(
      onTap: tap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFDDEEE1),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFDDEEE1),
      appBar: AppBar(
        title: const Text("Edit Team", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Name (Locked)
            TextField(
              controller: _teamNameController,
              enabled: false,
              decoration: _input("Team Name (Locked)"),
            ),
            const SizedBox(height: 12),

            // Captain Name (Locked)
            TextField(
              controller: _leaderNameController,
              enabled: false,
              decoration: _input("Captain (Locked)"),
            ),

            const SizedBox(height: 20),
            const Text(
              "Team Members",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            // ✅ Member Emails (editable, prefilled)
            ..._memberEmails.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: _input("Email ${index + 1}"),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      onPressed: () =>
                          setState(() => _memberEmails.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addEmail,
                icon: const Icon(Icons.add),
                label: const Text("Add Member"),
              ),
            ),

            const SizedBox(height: 25),
            const Text(
              "Achievements",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            // Achievements (editable)
            ..._achievements.asMap().entries.map((entry) {
              final index = entry.key;
              final a = entry.value;
              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: a["title"],
                      decoration: _input("Title"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: a["description"],
                      decoration: _input("Description"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: a["date"],
                      decoration: _input("Date YYYY-MM-DD"),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        onPressed: () =>
                            setState(() => _achievements.removeAt(index)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addAchievement,
                icon: const Icon(Icons.add),
                label: const Text("Add Achievement"),
              ),
            ),

            const SizedBox(height: 28),

            // ✅ Save button (bulk update)
            _glassButton(
              "Save Changes",
              _updateTeamDetails,
              color: Colors.green,
            ),
            const SizedBox(height: 15),

            // ✅ Transfer captaincy button (only for leader)
            if (_isLeader)
              _glassButton(
                "Transfer Captaincy",
                _showTransferCaptainModal,
                color: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white.withOpacity(0.25),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// ------------------------------------
/// EDIT PROFILE PAGE
/// ------------------------------------
class EditProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String sports;
  final List<Map<String, dynamic>> achievements; // grouped by sport
  final List<Map<String, dynamic>> teamsList;
  final String? selectedAvatar;

  const EditProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.sports,
    required this.achievements,
    required this.teamsList,
    this.selectedAvatar,
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
  late String? _selectedAvatar;
  bool _isSaving = false;
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
  void _showSavingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: AppGreen.deep),
          ),
        ),
      ),
    );
  }

  final BoxDecoration _tileBox = BoxDecoration(
    color: AppGreen.light.withOpacity(0.35),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppGreen.mid.withOpacity(0.5)),
  );

  Widget _buildAvatarSelector() {
    final PageController pageController = PageController(
      viewportFraction: 0.95,
    );

    return Container(
      height: 350,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                SmoothPageIndicator(
                  controller: pageController,
                  count: avatarImages.length,
                  effect: WormEffect(
                    dotHeight: 9,
                    dotWidth: 9,
                    type: WormType.thinUnderground,
                    spacing: 8,
                    activeDotColor: Colors.white,
                    dotColor: Colors.white.withOpacity(0.45),
                  ),
                ),
                const SizedBox(height: 20),

                // Swipe Avatars
                Expanded(
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: avatarImages.length,
                    itemBuilder: (context, index) {
                      final avatar = avatarImages[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedAvatar = avatar);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedAvatar =
        (widget.selectedAvatar != null && widget.selectedAvatar!.isNotEmpty)
        ? widget.selectedAvatar
        : "avatar_1.png";
    teamsList = widget.teamsList
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    achievements = widget.achievements.map((e) {
      return {
        "sport": e["sport"] ?? "",
        "records": [
          {
            "tournament": e["title"] ?? "",
            "year": e["year"]?.toString() ?? "",
            "achievement": e["achievement"] ?? "",
            "experience": e["experience"] ?? "",
          },
        ],
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
            // 👇👇 INSERT THIS HERE 👇👇
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  barrierColor: Colors.black.withOpacity(0.35),
                  backgroundColor: Colors.transparent,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) => _buildAvatarSelector(),
                );
              },
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFD4E7D0),
                backgroundImage: AssetImage(
                  'assets/profile_avatars/${_selectedAvatar ?? "avatar_1.png"}',
                ),
              ),
            ),
            const SizedBox(height: 25),

            // 👆👆 END OF INSERT 👆👆
            _field("Name", _name),
            _field("Email", _email, enabled: false),
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

  Widget _field(String label, TextEditingController c, {bool enabled = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        enabled: enabled,
        controller: c,
        style: const TextStyle(color: AppGreen.ink),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppGreen.light.withOpacity(0.3),
          labelText: label,
          labelStyle: TextStyle(
            color: enabled ? AppGreen.ink : Colors.black38,
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
                    child: (team['isLeader'] == true || team['is_captain'] == 1)
                        ? _glassTeamButton(
                            label: "Edit Team",
                            icon: Icons.edit,
                            onTap: () async {
                              // ✅ use teamId & sport from the mapped structure
                              final int teamId = team['teamId'] ?? 0;
                              final String sportName =
                                  team['sport'] ?? "Unknown";

                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditTeamPage(
                                    teamId: teamId,
                                    sportName: sportName,
                                  ),
                                ),
                              );

                              // if EditTeamPage returns "true" or {"reload": true}
                              if (updated == true ||
                                  (updated is Map &&
                                      updated['reload'] == true)) {
                                setState(() {});
                              }
                            },
                          )
                        : _glassTeamButton(
                            label: "Quit Team",
                            icon: Icons.exit_to_app,
                            onTap: () async {
                              final confirm = await _confirmQuitDialog(context);
                              if (confirm != true) return;

                              final res = await _authService.authPost(
                                Uri.parse(
                                  "$BASE_URL/api/teams/${team['teamId']}/leave/",
                                ),
                                {},
                              );

                              if (res.statusCode == 200) {
                                showGlassAlert(context, "You left the team!");

                                // Wait a moment so user can see alert
                                await Future.delayed(
                                  const Duration(milliseconds: 600),
                                );

                                // 👇 Redirect straight to Home & clear navigation stack
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HomePage(),
                                  ),
                                  (route) => false,
                                );
                              } else {
                                showGlassAlert(context, "Failed: ${res.body}");
                              }
                            },
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

  Widget _glassTeamButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppGreen.deep.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppGreen.deep.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppGreen.deep, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppGreen.deep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmQuitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Team?"),
        content: const Text("Are you sure you want to quit this team?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text("Leave", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
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
            child: Text(
              text, // 🔥 now using passed text
              style: const TextStyle(
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
      onTap: () async {
        if (_isSaving) return;

        setState(() => _isSaving = true);
        _showSavingDialog();

        List<int> sportIds = [];
        if (_sports.text.trim().isNotEmpty) {
          sportIds = _sports.text
              .split(",")
              .map((sport) {
                final s = sport.trim();
                final key = s[0].toUpperCase() + s.substring(1).toLowerCase();
                return sportNameToId[key] ?? 0;
              })
              .where((id) => id > 0)
              .toList();
        }

        final achievementsPayload = achievements.expand((block) {
          final sport = block["sport"] ?? "";
          final experience = block["experience"] ?? "";
          final records = block["records"] as List;

          return records.map(
            (r) => {
              "sport": sport,
              "title": r["tournament"] ?? "",
              "year": int.tryParse(r["year"].toString()) ?? DateTime.now().year,
              "achievement": r["achievement"] ?? "",
              "experience": experience,
            },
          );
        }).toList();

        final payload = {
          "name": _name.text.trim(),
          "phone": _phone.text.trim(),
          "avatar_id": _selectedAvatar,
          "interested_sports": sportIds,
          "achievements": achievementsPayload,
        };

        final res = await _authService.authPut(
          Uri.parse("https://turf-mgmt-sys.onrender.com/api/profile/me/"),
          payload,
        );

        Navigator.pop(context); // remove loader
        setState(() => _isSaving = false);

        if (res.statusCode == 200) {
          final refreshed = await _authService.authGet(
            Uri.parse("https://turf-mgmt-sys.onrender.com/api/profile/me/"),
          );

          if (refreshed.statusCode == 200) {
            final newData = jsonDecode(refreshed.body)["profile"];
            await ProfileCache.saveProfile(newData);

            Navigator.pop(context, newData);
            showGlassAlert(context, "Profile Updated Successfully!");
          }
        } else {
          showGlassAlert(context, "Failed to update profile");
        }
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
            ? Center(
                child: SizedBox(
                  width: 420, // keep large size
                  height: 420,
                  child: Image.asset(
                    "assets/custom_loader.gif",
                    fit: BoxFit.contain,
                  ),
                ),
              )
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
                    child: isLoading
                        ? const SizedBox.shrink()
                        : (bookings.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 80),
                                    child: Text(
                                      "No Booking History Yet",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 26,
                                        color: Colors.black.withOpacity(0.6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    children: bookings
                                        .map(
                                          (booking) => _buildBookingTile(
                                            context,
                                            booking,
                                          ),
                                        )
                                        .toList(),
                                  ),
                                )),
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
  4: "Hockey Ground 1",
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
  17: "Volleyball Court 1",
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
  bool _submitLoading = false;
  bool _inviteLoading = false;

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

  /// 1) Translate sport name to backend sport_id (unique translation table)
  /// No backend call — use local mapping only
  Future<String> translateSportNameToId(String sportName) async {
    // Use normalized lookup for safety
    final id = sportNameToId[sportName.trim()];
    if (id == null) {
      throw Exception("sport_id not found in local mapping for $sportName");
    }
    return id.toString();
  }

  Future<void> _broadcastLookingForPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");

    if (token == null) {
      showGlassAlert(context, "Session expired. Please log in again.");
      return;
    }

    // Normalize sport name
    final raw = widget.sport.trim().toLowerCase();
    final normalized = raw[0].toUpperCase() + raw.substring(1);

    // Translate to ID
    final sportId = sportNameToId[normalized];
    if (sportId == null) {
      showGlassAlert(context, "Sport not supported: ${widget.sport}");
      return;
    }

    // Validate slot
    final selectedSlot = widget.selectedSlots.isNotEmpty
        ? widget.selectedSlots.first
        : null;
    if (selectedSlot == null) {
      showGlassAlert(context, "No slot selected.");
      return;
    }

    final slotId = slotNameToId[selectedSlot];
    if (slotId == null) {
      showGlassAlert(context, "Unknown slot selected.");
      return;
    }

    // FINAL BROADCAST PAYLOAD
    final payload = {
      "sport_id": sportId,
      "date": widget.slotDate, // 🟢 Required by backend
      "slot_id": [slotId], // 🟢 Backend expects array or slot_ids
      "message": "Looking for players to join a match!", // optional
    };

    print("BROADCAST PAYLOAD: $payload");

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
      print("BROADCAST RESPONSE = ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 202) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        showGlassAlert(context, "Players invited successfully!");
      } else {
        showGlassAlert(
          context,
          "Failed to broadcast (${response.statusCode}) — try again.",
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
                                    labelText: "Email",
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
                    child: _submitLoading
                        ? const Center(
                            child: SizedBox(
                              height: 38,
                              width: 38,
                              child: CircularProgressIndicator(
                                color: Colors.green,
                              ),
                            ),
                          )
                        : glassButton(
                            "Submit",
                            color: const Color(0xFF4CAF50),
                            opacity: 0.25,
                            onTap: () async {
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

                              setState(() => _submitLoading = true);
                              await _submitBooking();
                              if (mounted)
                                setState(() => _submitLoading = false);
                            },
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _inviteLoading
                        ? const Center(
                            child: SizedBox(
                              height: 38,
                              width: 38,
                              child: CircularProgressIndicator(
                                color: Colors.green,
                              ),
                            ),
                          )
                        : glassButton(
                            "Invite Players",
                            color: const Color(0xFF81C784),
                            opacity: 0.25,
                            onTap: () async {
                              if (!_insideCampus) {
                                showGlassAlert(
                                  context,
                                  "You must be inside IIT Ropar campus to use this feature",
                                );
                                return;
                              }

                              setState(() => _inviteLoading = true);
                              await _broadcastLookingForPlayers();
                              if (mounted)
                                setState(() => _inviteLoading = false);
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
