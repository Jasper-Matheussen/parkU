import 'dart:convert';
import 'dart:math';
import 'storage.dart';
import 'package:flutter/material.dart';
import 'package:parku/main.dart';
import 'package:parku/signupPage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hash/hash.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

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

class _LoginPageState extends State<LoginPage> {
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late final CollectionReference usersRef = firestore.collection('users');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Pagina'),
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
            SizedBox(height: 20),
            TextField(
              obscureText: true,
              controller: passwordController,
              decoration: const InputDecoration(
                hintText: 'Geef je wachtwoord',
                labelText: 'Wachtwoord',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Login

                if (usernameController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  const snackBar = SnackBar(
                    content: Text('fields cannot be empty.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  return;
                }

                var bytes = utf8.encode(passwordController.text);
                var sha256 = SHA256();
                var digest = sha256.update(bytes).digest();
                String hashedPassword = encodeHEX(digest);

                Future<bool> verifyLogin(
                    String username, String password) async {
                  final querySnapshot = await usersRef
                      .where('username', isEqualTo: username)
                      .where('password', isEqualTo: hashedPassword)
                      .get();

                  if (querySnapshot.docs.isNotEmpty) {
                    return true;
                  } else {
                    return false;
                  }
                }

                if (await verifyLogin(
                    usernameController.text, hashedPassword)) {
                  const snackBar = SnackBar(
                    content: Text('Login succesvol!'),
                    backgroundColor: Colors.green,
                  );
                  //set the logged in user
                  loggedInUser = usernameController.text;
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  Navigator.pop(context);
                } else {
                  const snackBar = SnackBar(
                    content: Text('Incorrect username or password.'),
                    backgroundColor: Colors.red,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                }
              },
              child: Text('Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignupPage()),
                );
              },
              child:
                  const Text('Nog geen account? Klik hier om te registreren'),
            ),
          ],
        ),
      ),
    );
  }
}
