import 'dart:html';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

// Firebase packages.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  // Ensure Flutter and Firebase are initialized.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyAnKF31ldQCmllCpDvyB5Q0xnZLdQx1WaQ",
      authDomain: "fluttert-map-mapbox-gl-js.firebaseapp.com",
      projectId: "fluttert-map-mapbox-gl-js",
      storageBucket: "fluttert-map-mapbox-gl-js.firebasestorage.app",
      messagingSenderId: "565383023365",
      appId: "1:565383023365:web:aafa2cc0fd3c32aea3856c",
    ),
  );

  // Register the Mapbox view.
  ui.platformViewRegistry.registerViewFactory('mapbox-gl-element', (int viewId) {
    final div = DivElement()
      ..id = 'mapbox-map'
      ..style.width = '100%'
      ..style.height = '100%';
    return div;
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox & Firebase Integration',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => MapScreen(),
        '/signup': (context) => SignUpPage(),
      },
    );
  }
}

class MapScreen extends StatelessWidget {
  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'sign_in':
        // TODO: Implement Sign In logic.
        print("Sign In clicked");
        break;
      case 'sign_up':
        Navigator.pushNamed(context, '/signup');
        break;
      case 'sign_out':
        FirebaseAuth.instance.signOut();
        print("Sign Out clicked");
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mapbox GL JS in Flutter"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuSelection(context, value),
            icon: Icon(Icons.account_circle),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'sign_in',
                child: Text("Sign In"),
              ),
              PopupMenuItem<String>(
                value: 'sign_up',
                child: Text("Sign Up"),
              ),
              PopupMenuItem<String>(
                value: 'sign_out',
                child: Text("Sign Out"),
              ),
            ],
          ),
        ],
      ),
      body: HtmlElementView(viewType: 'mapbox-gl-element'),
    );
  }
}

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  // Form fields.
  String _email = '';
  String _password = '';
  String _displayName = '';
  String _errorMessage = '';

  // Create user account and store info in Firestore.
  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: _email, password: _password);
        User? user = userCredential.user;
        if (user != null) {
          // Update display name.
          await user.updateDisplayName(_displayName);

          // Save additional user info in Firestore.
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'displayName': _displayName,
            'email': _email,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Navigate back to the map screen.
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'This email is already registered. Please sign in.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is not valid.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Email/Password sign-in is not enabled. Contact support.';
            break;
          case 'weak-password':
            errorMessage = 'The password is too weak. Please choose a stronger password.';
            break;
          default:
            errorMessage = e.message ?? 'An error occurred during sign up.';
        }
        setState(() {
          _errorMessage = errorMessage;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'An unknown error occurred.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
                ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Display Name'),
                onSaved: (value) => _displayName = value!.trim(),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your display name.' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Email'),
                onSaved: (value) => _email = value!.trim(),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your email.' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Password'),
                onSaved: (value) => _password = value!.trim(),
                obscureText: true,
                validator: (value) =>
                    value!.length < 6 ? 'Password must be at least 6 characters.' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUp,
                child: Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}