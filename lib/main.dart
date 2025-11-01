import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

// If you use the FlutterFire CLI, import the generated options file:
// import 'firebase_options.dart';



// According to the code, specifically in the `_submit` method, the
// Firestore collection ID is 'users'. This is the string passed to
// `firestore.collection('users')`. A collection is a container for
// documents in Firestore.


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Firebase Login',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _showToast(String txt) async {
    Fluttertoast.showToast(msg: txt, toastLength: Toast.LENGTH_SHORT);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showToast('Please provide email and password.');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showToast('Please enter a valid email address.');
      return;
    }

    setState(() => _loading = true);

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    try {
      // Try signing in first
      final userCred = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Signed in successfully
      final uid = userCred.user?.uid;
      String displayName = userCred.user?.displayName ?? name;

      if (uid != null) {
        final doc = await firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['name'] != null) {
            displayName = data['name'] as String;
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(displayName: displayName)),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: code=${e.code}, message=${e.message}');
      if (e.code == 'user-not-found') {
        // Register new user: require name for registration
        if (name.isEmpty) {
          _showToast('No account found. Please enter a name to register.');
        } else {
          try {
            final newUser = await auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );

            final uid = newUser.user?.uid;
            if (uid != null) {
              // Save user details to Firestore
              await firestore.collection('users').doc(uid).set({
                'name': name,
                'email': email,
                'createdAt': FieldValue.serverTimestamp(),
              });
              // Optionally set displayName on the FirebaseAuth user
              await newUser.user?.updateDisplayName(name);
            }

            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => HomePage(displayName: name)),
            );
          } on FirebaseAuthException catch (err) {
            debugPrint('Registration failed: code=${err.code}, message=${err.message}');
            _showToast('Registration failed: ${err.message} (${err.code})');
          } catch (err) {
            debugPrint('Registration error: $err');
            _showToast('Registration error: $err');
          }
        }
      } else if (e.code == 'wrong-password') {
        _showToast('Wrong password.');
      } else if (e.code == 'invalid-email') {
        _showToast('Invalid email address.');
      } else {
        _showToast('Sign-in error: ${e.message} (${e.code})');
      }
    } catch (err) {
      debugPrint('Unexpected error: $err');
      _showToast('Error: $err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Sign in with email + password',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name (required only for registration)',
                            hintText: 'e.g. John Doe',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@example.com',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text('Login / Register'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Note: This demo uses email + password. New users will be registered and their name/email saved to Firestore.',
                          style: TextStyle(fontSize: 12),
                        )
                      ],
                    )),
              ),
            ),
          ),
        ));
  }
}

class HomePage extends StatelessWidget {
  final String displayName;
  const HomePage({super.key, required this.displayName});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // After sign-out, go back to login
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(context),
            )
          ],
        ),
        body: Center(
          child: Text(
            'Welcome, $displayName',
            style: const TextStyle(fontSize: 20),
          ),
        ));
  }
}