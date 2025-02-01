import 'package:flutter/material.dart';
import '../services/oauth_service.dart';
class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: 
    Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            OauthService().login();
            // Navigator.push(context, MaterialPageRoute(builder: (context) => const ApiCallerScreen()));
          },
          child: const Text("Login Via Google"),
        ),
      ),
    ));
  }
}