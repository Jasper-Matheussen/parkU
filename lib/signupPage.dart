import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hash/hash.dart';

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

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
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
        title: Text('Registratie Pagina'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                hintText: 'Geef je gebruikersnaam',
                labelText: 'Gebruikersnaam',
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: 'Geef je emai',
                labelText: 'Email',
              ),
            ),
            SizedBox(height: 20),
            TextField(
              obscureText: true,
              controller: passwordController,
              decoration: InputDecoration(
                hintText: 'Geef je wachtwoord',
                labelText: 'Wachtwoord',
              ),
            ),
            SizedBox(height: 20),
            TextField(
              obscureText: true,
              controller: confirmPasswordController,
              decoration: InputDecoration(
                hintText: 'Herhaal je wachtwoord',
                labelText: 'Herhaal wachtwoord',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Your sign up logic her

                String username = usernameController.text.trim();
                String email = emailController.text.trim();
                String password = passwordController.text;
                String confirmPassword = confirmPasswordController.text;

                if (password != confirmPassword) {
                  // show an error message
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
                  });

                  // navigate to the next screen
                  //Navigator.pushNamed(context, '/login');
                } catch (e) {
                  // handle any errors
                  print(e);
                }
              },
              child: Text('Registreer'),
            ),
          ],
        ),
      ),
    );
  }
}
