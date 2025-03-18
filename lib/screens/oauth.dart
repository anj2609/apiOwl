import 'package:flutter/material.dart';
import '../services/oauth_service.dart';
import "api_caller_screen.dart";

class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return SafeArea(
        child: Scaffold(
           backgroundColor: const Color(0xFF2F3136),
      body: Center(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(30),
          ),
          width: width * 0.7,
          height: 70,
          child: Row(
            
            children: [
              Image.asset("assets/icons/google.png"),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF2F3136),
                  textStyle:TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  )
                  
                ),
                onPressed: () async {
                  
                  if (await OauthService().login()) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ApiCallerScreen()));
                  }
                },
                child: const Text("Login Via Google"),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
