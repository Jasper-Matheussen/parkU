import 'package:cloud_firestore/cloud_firestore.dart';

import 'car.dart';

String? loggedInUser;

//get the loggedInUser from firebase
getLoggedInUser() async {
  final usersRef = FirebaseFirestore.instance.collection('users');
  final query = usersRef.where('username', isEqualTo: loggedInUser);
  //return the user reference
  return query.get();
}

//method
Future<void> addCarForUser(String merk, String kleur, String type) {
  // Add a new document with a generated id.
  //get the loggedInUser from firebase
  return getLoggedInUser().then((value) {
    final userRef = value.docs.first.reference;
    userRef.collection('cars').add({
      'merk': merk,
      'kleur': kleur,
      'type': type,
    });
  });
}

//method delete car
Future<void> deleteCarForUser(Car car) {
  //get the loggedInUser from firebase
  return getLoggedInUser().then((value) {
    final userRef = value.docs.first.reference;
    userRef.collection('cars').doc(car.id).delete();
  });
}





