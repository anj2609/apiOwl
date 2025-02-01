import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer' as developer;
import "package:cloud_firestore/cloud_firestore.dart";

class OauthService {
  Future<bool> login() async {
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      final GoogleSignIn googleSignIn = GoogleSignIn();
      print(googleSignIn.toString());
      final GoogleSignInAccount? useraccount = await googleSignIn.signIn();
      print(useraccount.toString());
      final GoogleSignInAuthentication? googleAuth =
          await useraccount?.authentication;
      print(googleAuth.toString());
      final AuthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );
      print(AuthCredential.toString());
      final UserCredential userCredential =
          await auth.signInWithCredential(AuthCredential);
      final User? user = userCredential.user;
      if (user != null) {
        print("****************" * 100);
        print("Sign-in successful: ${user.uid}");
        print(user.displayName);
        print(user.email);
        print(user.photoURL);
        print(user.phoneNumber);
        print(user.isAnonymous);
        print(user.metadata);
        print(user.providerData);
        print(user.refreshToken);
        print(user.tenantId);
        print(user.uid);
        await FirebaseFirestore.instance.collection("user").doc(user.displayName).set({
          "name": user.displayName,
          "email": user.email,
          "photoURL": user.photoURL,
          "phoneNumber": user.phoneNumber,
          "isAnonymous": user.isAnonymous,
          "metadata": {
            "creationTime": user.metadata.creationTime?.millisecondsSinceEpoch,
            "lastSignInTime":
                user.metadata.lastSignInTime?.millisecondsSinceEpoch,
          },
          "providerData": user.providerData
              .map((userInfo) => {
                    "providerId": userInfo.providerId,
                    "uid": userInfo.uid,
                    "email": userInfo.email,
                    "displayName": userInfo.displayName,
                    "photoURL": userInfo.photoURL,
                    "phoneNumber": userInfo.phoneNumber,
                  })
              .toList(),
          "refreshToken": user.refreshToken,
          "tenantId": user.tenantId,
        });
        return true;
      } else {
        print("Sign-in failed: User is null");
        return false;
      }
    } on FirebaseAuthException catch (e) {
      print("Sign-in failed: ${e.message}");
      return false;
    }
  }
}
