import 'package:flutter/material.dart';
import 'login.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(seconds: 3), () {
        Navigator.push(
          context,
          MaterialPageRoute(
            //builder: (context) => LoginPage(),
            builder: (context) => LoginPage(),
          )
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Revismar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        backgroundColor: Color.fromRGBO(2, 29, 38, 1.0),
      ),
      home: Stack(
        fit: StackFit.expand,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(color: Color.fromRGBO(2, 29, 38, 1.0)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    'images/caratula.jpg',
                    fit: BoxFit.fill,
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }
}
