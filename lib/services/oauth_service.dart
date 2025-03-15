import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import "package:cloud_firestore/cloud_firestore.dart";

class OauthService {
  Future<bool> login() async {
    try {
      final storage = FlutterSecureStorage();
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
        await FirebaseFirestore.instance
            .collection("user")
            .doc(user.displayName)
            .set({
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
        await storage.write(key: "username", value: user.displayName);
        await storage.write(key: "email", value: user.email);
        await storage.write(key: "uid", value: user.uid);
        await storage.write(key: "refreshToken", value: user.refreshToken);
        await storage.write(key: "tenantid", value: user.tenantId);
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
