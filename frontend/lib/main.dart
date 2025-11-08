import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';

List<Map<String, String>> globalNotifications = [];

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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const IntroScreen(), // Always show intro first
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

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Detect success based on JWT token keys
        if (data.containsKey('access') && data.containsKey('refresh')) {
          final accessToken = data['access'];
          final refreshToken = data['refresh'];
          // store locally for later API calls
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken);
          await prefs.setString('refresh_token', refreshToken);
          return true;
        } else {
          return false;
        }
      } else {
        return false;
      }
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
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomePage(),
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

                // --- Updated Google Sign-In button ---
                GestureDetector(
                  onTap: () async {
                    final ok = await GoogleAuthService.signInWithGoogle();
                    if (ok) {
                      showGlassAlert(context, "Signed in Successfully");
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomePage()),
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
                      showGlassAlert(context, "Signed up Successfully");
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomePage()),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Please enter a valid sport name first."),
                      ),
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");
    if (token == null) return;

    final groundId = groundNameToId[widget.groundName]; // reverse lookup
    final date = widget.slotDate; // already YYYY-MM-DD

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
                  final isBooked = _bookedSlots.contains(time);

                  return GestureDetector(
                    onTap: isBooked ? null : () => _toggleSlot(time),
                    child: Opacity(
                      opacity: isBooked ? 0.45 : 1.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isBooked
                                  ? Colors.red.shade900.withOpacity(0.22)
                                  : isSelected
                                  ? Colors.green.shade800.withOpacity(0.65)
                                  : Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isBooked
                                    ? Colors.red.shade900.withOpacity(0.35)
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
  final List<Map<String, String>> notifications = globalNotifications.isNotEmpty
      ? globalNotifications
      : const [
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

  NotificationPage({super.key});

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
                      onTap: () async {
                        // 🔹 Backend Placeholder: Send sport ID to backend
                        final sportId = name.hashCode.toString();
                        // TODO: Replace with backend call using sportId

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeamListPage(sportName: name, sportId: sportId),
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
  final String sportId;

  const TeamListPage({
    super.key,
    required this.sportName,
    required this.sportId,
  });

  List<Map<String, String>> _getTeams() {
    // Mock backend data with teamId
    switch (sportName) {
      case 'Football':
        return [
          {'id': 't01', 'name': 'Rovers FC'},
          {'id': 't02', 'name': 'Campus United'},
          {'id': 't03', 'name': 'Mechanical XI'},
          {'id': 't04', 'name': 'Civil Stars'},
        ];
      case 'Cricket':
        return [
          {'id': 't11', 'name': 'RPR Blazers'},
          {'id': 't12', 'name': 'ECE Warriors'},
          {'id': 't13', 'name': 'Hostel Kings'},
          {'id': 't14', 'name': 'Phoenix XI'},
        ];
      case 'Basketball':
        return [
          {'id': 't21', 'name': 'Dunk Masters'},
          {'id': 't22', 'name': 'Tech Titans'},
          {'id': 't23', 'name': 'Campus Bulls'},
        ];
      default:
        return [
          {'id': 'x1', 'name': 'Team A'},
          {'id': 'x2', 'name': 'Team B'},
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final teams = _getTeams();
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
        child: ListView.builder(
          itemCount: teams.length,
          itemBuilder: (context, index) {
            final team = teams[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GestureDetector(
                onTap: () async {
                  final teamId = team['id']!;
                  // 🔹 Backend Placeholder: Send teamId to backend, get data
                  // TODO: Replace mock with backend call

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamDetailsPage(
                        teamId: teamId,
                        teamName: team['name']!,
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
                            team['name']!,
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
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}

class TeamDetailsPage extends StatelessWidget {
  final String teamId;
  final String teamName;
  final String sportName; // ✅ Added sport name

  const TeamDetailsPage({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.sportName,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> teamInfo = {
      "createdOn": "12 Jan 2024",
      "membersCount": "10",
      "leader": "Rahul Mehta",
      "members": ["Rahul", "Sanjay", "Amit", "Kiran", "Vishal", "Pranav"],
      "achievements": [
        "🏆 Inter-IIT Winners 2024",
        "🥈 Campus Cup Runners-Up 2023",
      ],
    };

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

    // ✅ Cast members and achievements safely
    final List<String> members = List<String>.from(teamInfo['members'] ?? []);
    final List<String> achievements = List<String>.from(
      teamInfo['achievements'] ?? [],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5E9),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Brightness.dark, // ✅ black status bar text/icons
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
          teamName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Sport Tile
            _buildTile("Sport", sportName, Icons.sports_soccer_rounded),

            _buildTile(
              "Date of Creation",
              teamInfo['createdOn'] as String,
              Icons.calendar_today_rounded,
            ),
            _buildTile(
              "Team Members",
              teamInfo['membersCount'] as String,
              Icons.people_alt_rounded,
            ),
            _buildTile(
              "Team Leader",
              teamInfo['leader'] as String,
              Icons.person_rounded,
            ),

            // ✅ Members List Tile
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
                    children: [
                      Icon(Icons.groups, color: Colors.green.shade700),
                      const SizedBox(width: 10),
                      const Text(
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
                  ...members.map(
                    (m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "• $m",
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

            // ✅ Achievements Tile
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
                  ...achievements.map(
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

            const SizedBox(height: 80), // space for button
          ],
        ),
      ),

      // ✅ Bottom Invite Team Button (same UI as Submit button)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(80),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: GestureDetector(
              onTap: () {
                showGlassAlert(context, "Team Invited Successfully!");
                return;
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.45),
                  borderRadius: BorderRadius.circular(80),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: const Text(
                  "Invite Team",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppGreen {
  static const Color deep = Color(0xFF2E7D32); // primary action
  static const Color mid = Color(0xFF4CAF50); // secondary
  static const Color light = Color(0xFFBFE3C0); // fills
  static const Color card = Color(0xFFE8F5E9); // backgrounds
  static const Color ink = Colors.black87;
}

/// ------------------------------------
/// ADD / EDIT TEAM PAGE
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
  final TextEditingController _memberCountController = TextEditingController();
  final TextEditingController _achievementsController = TextEditingController();
  final List<Map<String, TextEditingController>> _players = [];
  late bool isEditMode;
  late int _minPlayers;

  @override
  void initState() {
    super.initState();
    isEditMode = widget.existingTeam != null;
    _minPlayers = _getMinPlayers(widget.sportName);

    if (isEditMode) {
      _teamNameController.text = (widget.existingTeam!['teamName'] ?? '')
          .toString();
      _memberCountController.text = (widget.existingTeam!['memberCount'] ?? '')
          .toString();
      _achievementsController.text = widget.existingTeam!['achievements'] ?? '';
      final List players = widget.existingTeam!['players'] ?? [];
      for (var p in players) {
        _players.add({
          'name': TextEditingController(text: p['name'] ?? ''),
          'email': TextEditingController(text: p['email'] ?? ''),
        });
      }
      if (_players.length < _minPlayers) {
        for (int i = _players.length; i < _minPlayers; i++) {
          _addPlayer();
        }
      }
    } else {
      for (int i = 0; i < _minPlayers; i++) {
        _addPlayer();
      }
    }
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
          (p) => {
            'name': p['name']!.text.trim(),
            'email': p['email']!.text.trim(),
          },
        )
        .where((p) => p['name']!.isNotEmpty)
        .toList();
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
                color: AppGreen.deep.withOpacity(0.95),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitTeam() {
    final teamName = _teamNameController.text.trim();
    final memberCount = _memberCountController.text.trim();
    final achievements = _achievementsController.text.trim();
    final players = _collectPlayers();

    if (teamName.isEmpty) {
      showGlassAlert(context, "Please enter a team name.");
      return;
    }
    if (memberCount.isEmpty || int.tryParse(memberCount) == null) {
      showGlassAlert(context, "Please enter a valid number of members.");
      return;
    }
    if (players.length < _minPlayers) {
      showGlassAlert(
        context,
        "Minimum $_minPlayers players required for ${widget.sportName}.",
      );
      return;
    }

    final teamData = {
      'teamName': teamName,
      'sport': widget.sportName,
      'memberCount': int.parse(memberCount),
      'achievements': achievements,
      'players': players,
      'leader': widget.existingTeam != null
          ? (widget.existingTeam!['leader'] ?? '')
          : '',
      'createdOn': widget.existingTeam != null
          ? (widget.existingTeam!['createdOn'] ?? '')
          : '',
      'isLeader': widget.existingTeam != null
          ? (widget.existingTeam!['isLeader'] ?? false)
          : true,
    };

    Navigator.pop(context, teamData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDEEE1),
      appBar: AppBar(
        backgroundColor: AppGreen.card.withOpacity(0.25),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Text(
          isEditMode ? "Edit Team" : "Create Team",
          style: const TextStyle(
            color: AppGreen.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppGreen.ink),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppGreen.card.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppGreen.mid.withOpacity(0.25)),
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
                          "Minimum players required: $_minPlayers",
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
              const SizedBox(height: 18),

              TextField(
                controller: _teamNameController,
                style: const TextStyle(color: AppGreen.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppGreen.light.withOpacity(0.3),
                  labelText: "Team Name",
                  labelStyle: const TextStyle(
                    color: AppGreen.ink,
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _memberCountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppGreen.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppGreen.light.withOpacity(0.3),
                  labelText: "Team Members Count",
                  labelStyle: const TextStyle(
                    color: AppGreen.ink,
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _achievementsController,
                style: const TextStyle(color: AppGreen.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppGreen.light.withOpacity(0.3),
                  labelText: "Team Achievements (optional)",
                  hintText: "e.g. Inter IIT Champions 2024",
                  labelStyle: const TextStyle(
                    color: AppGreen.ink,
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Player Details",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppGreen.ink,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: ListView(
                  children: [
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
                              color: AppGreen.card.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppGreen.mid.withOpacity(0.25),
                              ),
                            ),
                            child: Column(
                              children: [
                                TextField(
                                  controller: player['name'],
                                  style: const TextStyle(color: AppGreen.ink),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppGreen.light.withOpacity(0.3),
                                    labelText: "Player ${index + 1} Name",
                                    labelStyle: const TextStyle(
                                      color: AppGreen.ink,
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
                                  style: const TextStyle(color: AppGreen.ink),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppGreen.light.withOpacity(0.3),
                                    labelText: "Email (optional)",
                                    labelStyle: const TextStyle(
                                      color: AppGreen.ink,
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
                        color: AppGreen.mid,
                        opacity: 0.22,
                        height: 38,
                        radius: 80,
                        onTap: _addPlayer,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              glassButton(
                isEditMode ? "Apply Changes" : "Create Team",
                color: AppGreen.deep,
                opacity: 0.28,
                onTap: _submitTeam,
              ),
            ],
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

  /// Achievements grouped by sport (Option A)
  /// Each sport has `records` (multiple achievements)
  List<Map<String, dynamic>> achievements = [
    {
      "sport": "Football",
      "experience": "5 Years",
      "records": [
        {
          "tournament": "Inter-IIT Sports Meet",
          "year": "2024",
          "achievement": "Gold Medal",
        },
        {
          "tournament": "City League",
          "year": "2023",
          "achievement": "Runner Up",
        },
      ],
    },
    {
      "sport": "Cricket",
      "experience": "3 Years",
      "records": [
        {
          "tournament": "Tech Premier League",
          "year": "2023",
          "achievement": "Runner Up",
        },
      ],
    },
    {
      "sport": "Badminton",
      "records": [
        {
          "tournament": "Campus Championship",
          "year": "2022",
          "achievement": "Champion",
        },
      ],
    },
  ];

  List<Map<String, dynamic>> teamsList = [
    {
      "teamName": "Rising Strikers",
      "sport": "Football",
      "leader": "Alex Johnson",
      "createdOn": "12 Mar 2023",
      "isLeader": true,
      "memberCount": 11,
      "players": const [],
      "achievements": "Inter-IIT 2024 Champions",
    },
    {
      "teamName": "Court Smashers",
      "sport": "Badminton",
      "leader": "Sanjay Kumar",
      "createdOn": "8 Jan 2024",
      "isLeader": false,
      "memberCount": 2,
      "players": const [],
      "achievements": "",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
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
              const SizedBox(height: 25),

              Stack(
                alignment: Alignment.center,
                children: [
                  const CircleAvatar(
                    radius: 70,
                    backgroundColor: Color(0xFFD4E7D0),
                    backgroundImage: AssetImage('assets/profile_pic.png'),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 8,
                    child: InkWell(
                      onTap: () {},
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(5),
                        child: const Icon(
                          Icons.edit,
                          color: AppGreen.ink,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

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
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfilePage(
                            name: name,
                            email: email,
                            phone: phone,
                            sports: sports,
                            achievements: achievements,
                            teamsList: teamsList,
                          ),
                        ),
                      );

                      if (result != null && result is Map<String, dynamic>) {
                        setState(() {
                          name = result['name'];
                          email = result['email'];
                          phone = result['phone'];
                          sports = result['sports'];
                          achievements = List<Map<String, dynamic>>.from(
                            result['achievements'],
                          );
                          teamsList = List<Map<String, dynamic>>.from(
                            result['teamsList'],
                          );
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildInfoTile("Email", email, Icons.email),
              _buildInfoTile("Mobile", phone, Icons.phone),
              _buildInfoTile("Interested Sports", sports, Icons.sports_soccer),

              _buildAchievementsCard(),
              _buildTeamsSection(),

              const SizedBox(height: 30),
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppGreen.light.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppGreen.mid.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${r['tournament']} • ${r['year']}",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text("Achievement: ${r['achievement']}"),
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
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: _innerTileDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team['teamName'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppGreen.ink,
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
            final DateTime createdAt =
                DateTime.tryParse(b["created_at"]) ?? now;

            // ✅ Normalize status from backend
            String status = (b["status"] ?? "active").toString().toLowerCase();
            if (status == "rejected") status = "cancelled";

            // ✅ Mark completed only if time passed and not cancelled
            if (status != "cancelled" &&
                now.difference(createdAt).inHours >= 3) {
              status = "completed";
            }

            final groundName = groundIdMap[b["ground_id"]] ?? "Unknown Ground";

            final slotNames = (b["slots"] as List)
                .map((id) => slotIdMap[id] ?? "Unknown Slot ($id)")
                .toList();

            final slotTimeRange = slotNames.isEmpty
                ? "No slots assigned"
                : "${slotNames.first} - ${slotNames.last}";

            return {
              "bookingId": b["booking_id"],
              "ground": groundName,
              "sport": b["players"].isNotEmpty
                  ? b["players"].first["sport"] ?? "Sport"
                  : "Sport",
              "slotCount": b["num_slots"],
              "slotTimeRange": slotTimeRange,
              "slotDate": createdAt,
              "bookedOn": createdAt,
              "players": b["players"] ?? [],
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
                        /*if (_checkingLocation) {
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
                        }*/
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
                        showGlassAlert(
                          context,
                          "Invitations sent successfully!",
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
