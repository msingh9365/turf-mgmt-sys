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
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseMessaging.instance.requestPermission();

  // ✅ Always keep this here
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString("access_token");
    if (jwt == null) return;

    await http.post(
      Uri.parse(
        "https://turf-mgmt-sys.onrender.com/api/notifications/register/",
      ),
      headers: {
        "Authorization": "Bearer $jwt",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"device_token": newToken, "device_type": "android"}),
    );
  });

  // Your existing listeners (unchanged)
  FirebaseMessaging.onMessage.listen((message) {
    globalNotifications.insert(0, {
      "title": message.notification?.title ?? "Notification",
      "message": message.notification?.body ?? "",
      "time": "Just now",
      "is_read": false,
    });
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    globalNotifications.insert(0, {
      "title": message.notification?.title ?? "Notification",
      "message": message.notification?.body ?? "",
      "time": "Just now",
      "is_read": false,
    });
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

  void _goToHome() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString("refresh_token");

    Widget nextScreen = const LoginPage();

    if (refreshToken != null) {
      final newToken = await AuthService().refreshAccessToken();
      if (newToken != null) {
        nextScreen = const HomePage();
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextScreen,
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

// ---------------------- Auth placeholder + helper UI ----------------------
class AuthService {
  Future<bool> login({required String email, required String password}) async {
    try {
      final uri = Uri.parse(
        'https://turf-mgmt-sys.onrender.com/api/auth/login/',
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey('access') && data.containsKey('refresh')) {
          final accessToken = data['access'];
          final refreshToken = data['refresh'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken);
          await prefs.setString('refresh_token', refreshToken);

          // ✅ Register device token ONCE per login
          await _registerFcmDeviceWithBackend();

          return true; // ✅ Do NOT return before this line
        }
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
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
    final uri = Uri.parse("https://turf-mgmt-sys.onrender.com//send-otp/");
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    return res.statusCode == 200;
  }

  Future<bool> verifyOtp({required String email, required String otp}) async {
    final uri = Uri.parse("https://turf-mgmt-sys.onrender.com//verify-otp/");
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp": otp}),
    );
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

        return true;
      }

      return false;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return false;
    }
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

                            final nextScreen =
                                await _decideNextScreen(); // ✅ Await here
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => nextScreen),
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

                // --- Updated Google Sign-In button ---
                GestureDetector(
                  onTap: () async {
                    final ok = await GoogleAuthService.signInWithGoogle();
                    if (ok) {
                      showGlassAlert(context, "Signed in Successfully");

                      final nextScreen =
                          await _decideNextScreen(); // ✅ Await here
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
                          color: const Color(0xFF4CAF50).withOpacity(0.35),
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
  //bool _otpStep = false;
  //final _otpCtrl = TextEditingController();

  bool _loading = false;

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
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
            ),
          ),
        ),
      ),
    );
  }

  /*Future<void> _trySignup() async {
    if (!_otpStep) {
      setState(() => _loading = true);
      final sent = await _authService.sendOtp(email: _email.text.trim());
      setState(() => _loading = false);

      if (sent) {
        showGlassAlert(context, "OTP Sent to Email");
        setState(() => _otpStep = true);
      } else {
        showGlassAlert(context, "OTP Send Failed");
      }
      return;
    }

    setState(() => _loading = true);
    final ok = await _authService.register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      mobile: _mobile.text.trim(),
      password: _pass.text.trim(),
    );
    setState(() => _loading = false);

    if (ok) {
      showGlassAlert(context, "Signup Successful ✅");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      showGlassAlert(context, "Signup Failed");
    }
  }*/

  Future<void> _trySignup() async {
    if (_pass.text.trim() != _repass.text.trim()) {
      showGlassAlert(context, "Passwords do not match");
      return;
    }

    setState(() => _loading = true);
    final ok = await _authService.register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      mobile: _mobile.text.trim(),
      password: _pass.text.trim(),
    );
    setState(() => _loading = false);

    if (ok) {
      showGlassAlert(context, "Signup Successful");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      showGlassAlert(context, "Signup Failed");
    }
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
                _frostedField(_email, "Email", kb: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _frostedField(
                  _mobile,
                  "Mobile number",
                  kb: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _frostedField(_pass, "Password", obscure: true),
                const SizedBox(height: 10),
                _frostedField(_repass, "Re-enter password", obscure: true),
                const SizedBox(height: 18),
                /*if (_loading)
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
                  ),*/
                _loading
                    ? const CircularProgressIndicator(color: Colors.green)
                    : glassActionButton(
                        context: context,
                        label: "Submit",
                        onTap: _trySignup,
                      ),
                const SizedBox(height: 12),

                /*GestureDetector(
                  onTap: () async {
                    final ok = await _authService.verifyOtp(
                      email: _email.text.trim(),
                      otp: _otpCtrl.text.trim(),
                    );
                    if (ok) {
                      showGlassAlert(context, "OTP Verified ✅");
                      setState(() {});
                    } else {
                      showGlassAlert(context, "Invalid OTP ❌");
                    }
                  },
                  child: Text(
                    "Verify OTP",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Opacity(
                  opacity: _otpCtrl.text.trim().length == 6 ? 1 : 0.4,
                  child: IgnorePointer(
                    ignoring: _otpCtrl.text.trim().length != 6,
                    child: glassActionButton(
                      context: context,
                      label: "Signup",
                      onTap: _trySignup,
                    ),
                  ),
                ),
              ],*/

                //if (!_otpStep) ...[
                const SizedBox(height: 18),
                _dividerLine(),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () async {
                    final ok = await GoogleAuthService.signInWithGoogle();
                    if (ok) {
                      showGlassAlert(context, "Signed in Successfully");

                      final nextScreen =
                          await _decideNextScreen(); // ✅ Await here
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
                          color: const Color(0xFF4CAF50).withOpacity(0.35),
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
                //],
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestLocationPermission(context);
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Upcoming Events",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                    // ✅ Subtle Add Event Icon Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddEventPage(),
                          ),
                        );
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

class EventDetailsPage extends StatelessWidget {
  final String title;
  final String location;
  final String? image;

  const EventDetailsPage({
    super.key,
    required this.title,
    required this.location,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
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
                "assets/$image",
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 20),

            _infoTile("Tournament Title", title, Icons.emoji_events_outlined),
            _infoTile("Location", location, Icons.place_outlined),
            _infoTile("Sport", "Football", Icons.sports_soccer),
            _infoTile("Date & Time", "12 Feb 2025 • 4:00 PM", Icons.schedule),
            _infoTile(
              "Organizer Contact",
              "+91 9876543210",
              Icons.call_outlined,
            ),

            _contentTile(
              "Tournament Description",
              "Join the most competitive sports event at IIT RPR. Register soon before slots are full.",
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
    // Add remaining sports the same way
  };

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
                  labelText: "Date & Time (e.g. 12 Feb 2025 • 4:00 PM)",
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
                color: const Color(0xFF2E7D32), // ✅ same dark green
                opacity: 0.3,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 40),
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
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailsPage(
              title: widget.title,
              location: widget.location,
              image: widget.image,
            ),
          ),
        );
      },
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

                    // Gradient overlay for readability
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

                    // Glass info pill
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
                                  widget.title, // ✅ always shows title
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
              builder: (context) =>
                  TeamListPage(sportName: name, sportId: 'football123'),
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
