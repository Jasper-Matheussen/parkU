import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hash/hash.dart';
import 'package:email_validator/email_validator.dart';

import 'loginPage.dart';

/// hex encode
String encodeHEX(List<int> bytes) {
  var str = '';
  for (var i = 0; i < bytes.length; i++) {
    var s = bytes[i].toRadixString(16);
    str += s.padLeft(2 - s.length, '0');
  }
  return str;
}

/// hex decode
List<int> decodeHEX(String hex) {
  var bytes = <int>[];
  var len = hex.length ~/ 2;
  for (var i = 0; i < len; i++) {
    bytes.add(int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
  }
  return bytes;
}

bool isValidEmail(String email) {
  return EmailValidator.validate(email);
}

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late final CollectionReference usersRef = firestore.collection('users');

  Future<bool> isUsernameOrEmailAlreadyInUse(
      String username, String email) async {
    // Check if the username is already in use
    QuerySnapshot usernameSnapshot =
        await usersRef.where('username', isEqualTo: username).get();
    if (usernameSnapshot.docs.isNotEmpty) {
      return true;
    }

    // Check if the email is already in use
    QuerySnapshot emailSnapshot =
        await usersRef.where('email', isEqualTo: email).get();
    if (emailSnapshot.docs.isNotEmpty) {
      return true;
    }

    return false;
  }
}

class _SignupPageState extends State<SignupPage> {
  TextEditingController usernameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registratie Pagina'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                hintText: 'Geef je gebruikersnaam',
                labelText: 'Gebruikersnaam',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                hintText: 'Geef je emai',
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              obscureText: true,
              controller: passwordController,
              decoration: const InputDecoration(
                hintText: 'Geef je wachtwoord',
                labelText: 'Wachtwoord',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              obscureText: true,
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                hintText: 'Herhaal je wachtwoord',
                labelText: 'Herhaal wachtwoord',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Your sign up logic her

                String username = usernameController.text.trim();
                String email = emailController.text.trim();
                String password = passwordController.text;
                String confirmPassword = confirmPasswordController.text;

                if (username.isEmpty) {
                  // show an error message
                  const snackBar = SnackBar(
                    content: Text('Username cannot be empty.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  return;
                }
                if (email.isEmpty) {
                  // show an error message
                  const snackBar = SnackBar(
                    content: Text('Email cannot be empty.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  return;
                }
                if (!isValidEmail(email)) {
                  // show an error message
                  const snackBar = SnackBar(
                    content: Text('Email is not valid.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  return;
                }
                if (password.isEmpty) {
                  // show an error message
                  const snackBar = SnackBar(
                    content: Text('Password cannot be empty.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  return;
                }
                if (confirmPassword.isEmpty) {
                  // show an error message
                  const snackBar = SnackBar(
                    content: Text('Confirm password cannot be empty.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  return;
                }
                if (password.length < 6) {
                  // show an error message
                  const snackBar = SnackBar(
                    content: Text('Password must be at least 6 characters.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  return;
                }

                if (password != confirmPassword) {
                  // show an error message
                  const snackBar = SnackBar(
                    content: Text('Passwords do not match.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  passwordController.clear();
                  confirmPasswordController.clear();
                  return;
                }
                if (await widget.isUsernameOrEmailAlreadyInUse(
                    username, email)) {
                  // show an error message
                  const snackBar = SnackBar(
                    content: Text('Username or email is already in use.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  return;
                }

                // hash the password
                var bytes = utf8.encode(password);
                var sha256 = SHA256();
                var digest = sha256.update(bytes).digest();
                String hashedPassword = encodeHEX(digest);

                // create a new document in the 'users' collection
                try {
                  await widget.firestore.collection('users').add({
                    'username': username,
                    'email': email,
                    'password': hashedPassword,
                    'thumbsUp': 0,
                    'thumbsDown': 0,
                  });

                  // navigate to the next screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                } catch (e) {
                  // handle any errors
                }
              },
              child: const Text('Registreer'),
            ),
          ],
        ),
      ),
    );
  }
}
