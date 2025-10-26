import 'package:flutter/material.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  bool passVisible = false;
  bool loading = false;

  // design colors (kept as non-const where referenced in TextStyle)
  static const Color bgMint = Color(0xFFE8F5E9);
  static const Color pillGreenHex = Color(0xFFA7D7B0); // darker mint pill
  final Color accentGreen = Colors.green.shade800;
  final Color labelColor = Colors.black87;
  final Color hintColor = Colors.black54;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMint,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Welcome to EndGame',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: accentGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in to continue to your campus turf & teams.',
                style: TextStyle(fontSize: 14, color: hintColor),
              ),
              const SizedBox(height: 28),

              // Email field pill
              _pillField(
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: Colors.black54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: labelColor),
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Password field pill
              _pillField(
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.black54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: passCtrl,
                        obscureText: !passVisible,
                        style: TextStyle(color: labelColor),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        passVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.black54,
                      ),
                      onPressed: () => setState(() => passVisible = !passVisible),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Google sign-in button (pill)
              _centeredChild(_googleSignInButton()),
              const SizedBox(height: 18),

              // Login button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setState(() => loading = true);
                          await Future.delayed(const Duration(milliseconds: 700));
                          setState(() => loading = false);
                          // demo: navigate to home or wherever your app expects
                          // If you use named routes, replace below with Navigator.pushReplacementNamed(context,'/home');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logged in (demo)')),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())),
                    child: Text('Create account', style: TextStyle(color: accentGreen, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // central pill field builder
  Widget _pillField({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: pillGreenHex,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  // Google button (UI only)
  Widget _googleSignInButton() {
    return GestureDetector(
      onTap: () {
        // UI placeholder — replace with actual auth call later
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google sign-in tapped (placeholder)')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: pillGreenHex,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // If you add assets/google_logo.png and list it in pubspec.yaml, change _googleLogoExists to true.
            if (_googleLogoExists())
              Image.asset('assets/google_logo.png', height: 20, width: 20)
            else
              Container(
                height: 22,
                width: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Text('G', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            const SizedBox(width: 12),
            Text('Sign in with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: labelColor)),
          ],
        ),
      ),
    );
  }

  // helper (toggle to true after you add asset)
  bool _googleLogoExists() {
    return false;
  }

  // small helper to center and constrain width
  Widget _centeredChild(Widget child) => Center(child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 240), child: child));
}
