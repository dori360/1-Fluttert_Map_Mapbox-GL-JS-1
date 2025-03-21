import 'dart:html';
import 'dart:ui_web' as ui;
import 'dart:typed_data'; // For Uint8List
import 'dart:async'; // For Completer
import 'package:flutter/material.dart';

// Firebase packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<void> main() async {
  // Ensure Flutter and Firebase are initialized.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyArnp-m9We6czQVhW9Au98QnCoRE9gP3Lw",
      authDomain: "flutter-map-app-b1d43.firebaseapp.com",
      projectId: "flutter-map-app-b1d43",
      storageBucket: "flutter-map-app-b1d43.firebasestorage.app",
      messagingSenderId: "795028306182",
      appId: "1:795028306182:web:2cf52841931c37ad3f4687"
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
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatelessWidget {
  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'sign_in':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => Stack(
            children: [
              Positioned(
                top: kToolbarHeight,
                right: 0,
                width: MediaQuery.of(context).size.width * 0.3,
                child: SignInDialog(),
              ),
            ],
          ),
        );
        break;
      case 'sign_up':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => Stack(
            children: [
              Positioned(
                top: kToolbarHeight,
                right: 0,
                width: MediaQuery.of(context).size.width * 0.3,
                child: SignUpDialog(),
              ),
            ],
          ),
        );
        break;
      case 'change_profile_picture':
        _uploadProfilePicture(context);
        break;
      case 'sign_out':
        FirebaseAuth.instance.signOut();
        break;
      default:
        break;
    }
  }

  void _uploadProfilePicture(BuildContext context) {
    final input = FileUploadInputElement()..accept = 'image/*';
    input.onChange.listen((e) async {
      if (input.files != null && input.files!.isNotEmpty) { // Safety check
        final file = input.files!.first;
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            // Read file as Uint8List
            final reader = FileReader();
            final completer = Completer<Uint8List>();
            reader.onLoadEnd.listen((e) {
              if (reader.readyState == FileReader.DONE) {
                final data = reader.result as Uint8List; // Corrected cast
                completer.complete(data);
              }
            });
            reader.onError.listen((error) {
              completer.completeError(error);
            });
            reader.readAsArrayBuffer(file);
            final data = await completer.future;

            // Upload to Firebase Storage
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('profile_pictures/${user.uid}.jpg');
            final uploadTask = storageRef.putData(data);
            await uploadTask;
            final downloadUrl = await storageRef.getDownloadURL();
            await user.updateProfile(photoURL: downloadUrl);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profile picture updated')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update profile picture: $e')),
            );
          }
        }
      }
    });
    input.click();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mapbox GL JS in Flutter"),
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator(color: Colors.white);
              }
              final user = snapshot.data;
              final photoURL = user?.photoURL;
              return PopupMenuButton<String>(
                onSelected: (value) => _handleMenuSelection(context, value),
                icon: CircleAvatar(
                  radius: 20, // Diameter 40 pixels ≈ 1 cm on many screens
                  backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                  child: photoURL == null ? Icon(Icons.account_circle, size: 40) : null,
                ),
                tooltip: "Show menu",
                itemBuilder: (BuildContext context) {
                  if (user != null) {
                    return <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Text(user.displayName ?? 'User'),
                      ),
                      PopupMenuItem<String>(
                        value: 'change_profile_picture',
                        child: Text("Change Profile Picture"),
                      ),
                      PopupMenuItem<String>(
                        value: 'sign_out',
                        child: Text("Sign Out"),
                      ),
                    ];
                  } else {
                    return <PopupMenuEntry<String>>[
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
                    ];
                  }
                },
              );
            },
          ),
        ],
      ),
      body: HtmlElementView(viewType: 'mapbox-gl-element'),
    );
  }
}

// Sign-In Dialog
class SignInDialog extends StatefulWidget {
  @override
  _SignInDialogState createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _errorMessage = '';

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        Navigator.of(context).pop();
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'An error occurred during sign-in.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
                ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Email'),
                onSaved: (value) => _email = value!.trim(),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'Please enter your email.' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Password'),
                onSaved: (value) => _password = value!.trim(),
                obscureText: true,
                validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters.' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signIn,
                child: Text('Sign In'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sign-Up Dialog
class SignUpDialog extends StatefulWidget {
  @override
  _SignUpDialogState createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<SignUpDialog> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _displayName = '';
  String _errorMessage = '';

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: _email, password: _password);
        User? user = userCredential.user;
        if (user != null) {
          await user.updateDisplayName(_displayName);
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'displayName': _displayName,
            'email': _email,
            'createdAt': FieldValue.serverTimestamp(),
          });
          Navigator.of(context).pop();
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'An error occurred during sign up.';
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
    return Material(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
                ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Display Name'),
                onSaved: (value) => _displayName = value!.trim(),
                validator: (value) => value!.isEmpty ? 'Please enter your display name.' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Email'),
                onSaved: (value) => _email = value!.trim(),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'Please enter your email.' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Password'),
                onSaved: (value) => _password = value!.trim(),
                obscureText: true,
                validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters.' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUp,
                child: Text('Sign Up'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}