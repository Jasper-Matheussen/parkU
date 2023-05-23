import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parku/storage.dart';

class ReservedSpotsPage extends StatefulWidget {
  @override
  _ReservedSpotsPageState createState() => _ReservedSpotsPageState();
}

class _ReservedSpotsPageState extends State<ReservedSpotsPage> {
  Future<List<QueryDocumentSnapshot>> getReservedSpots() async {
    final userId = await getUserId(); // Replace with your logic to get the user ID

    final querySnapshot = await FirebaseFirestore.instance
        .collection('markers')
        .where('status', isEqualTo: 'unavailable')
        .where('reserved', isEqualTo: userId)
        .get();

    return querySnapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rating Parkeerplekken'),
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: getReservedSpots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasData) {
            final reservedSpots = snapshot.data!;

            if (reservedSpots.isEmpty) {
              return const Center(
                child: Text('Geen plekken gereserveerd die zijn afgelopen.'),
              );
            }

            return ListView.builder(
              itemCount: reservedSpots.length,
              itemBuilder: (context, index) {
                final spot = reservedSpots[index];
                final spotId = spot.id;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(spot['user'])
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // While the snapshot is loading, show a loading indicator
                      return const CircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      // If there was an error fetching the user, show an error message
                      return Text('Error: ${snapshot.error}');
                    } else if (!snapshot.hasData) {
                      // If the user data is not available, show a placeholder
                      return ListTile(
                        title: const Text('User: Loading...'),
                        subtitle: const Text('Status: '),
                        trailing: IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: () {
                            // Implement logic to cancel the reservation for this spot
                            deleteReservation(spotId);
                            setState(() {
                              reservedSpots.removeAt(index);
                            });
                          },
                        ),
                      );
                    } else {
                      // If the user data is available, display the user's name
                      String userName = snapshot
                          .data!['username'];

                      return ListTile(
                        title: Text('Gebruiker: $userName'),
                        subtitle: Text('Tot datum: '  + spot['time'].substring(0, 16)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.thumb_up, color: Colors.green,),
                              onPressed: () {
                                //update the user rating in the database
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(spot['user'])
                                    .update({
                                  'thumbsUp': FieldValue.increment(1),
                                });
                                deleteReservation(spotId);
                                setState(() {
                                  reservedSpots.removeAt(index);
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.thumb_down, color: Colors.red,),
                              onPressed: () {
                                //update the user rating in the database
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(spot['user'])
                                    .update({
                                  'thumbsDown': FieldValue.increment(1),
                                });
                                deleteReservation(spotId);
                                setState(() {
                                  reservedSpots.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );

                    }
                  },
                );
              },
            );

          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            return const Center(
              child: Text('No data available.'),
            );
          }
        },
      ),
    );
  }

  // Replace this with your implementation for canceling a reservation
  void deleteReservation(String spotId) {
//remove the marker from the database
    FirebaseFirestore.instance
        .collection('markers')
        .doc(spotId)
        .delete();
  }

  Future<String> getUserId() async {
    final user = await getLoggedInUser();
    return user.docs.first.id;
  }
}
