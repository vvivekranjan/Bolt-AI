import 'package:ai_chat_bot/chat_screen.dart';
import 'package:flutter/material.dart';

class OnBoarding extends StatelessWidget {
  const OnBoarding({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("images/ai_image.jpg"),
                fit: BoxFit.cover
              )
            ),
          ),
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black87,
              boxShadow: [
                BoxShadow(
                  offset: Offset.zero,
                  blurRadius: 40,
                  spreadRadius: 40,
                )
              ]
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Welcome To Bolt AI',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.4
                        ),
                      ),
                      SizedBox(height: 20,),
                      Text(
                        'Your intelligent Conversational Partner. Explore the\npower of AI to answer your questions, assist with tasks,\nand make your life easier.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  OnBoardingButton(),
                ],
              ),
            ),
          )
        ]
      )
    );
  }
}

class OnBoardingButton extends StatefulWidget {
  const OnBoardingButton({super.key});

  @override
  State<OnBoardingButton> createState() => _OnBoardingButtonState();
}

class _OnBoardingButtonState extends State<OnBoardingButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatScreen())
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          color: Colors.grey.shade900,
        ),
        child: ClipRRect(
          borderRadius: BorderRadiusGeometry.circular(40),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color.fromARGB(255, 255, 234, 0),
                        Color(0xFFFF0000),
                        
                        // const Color.fromARGB(255, 0, 140, 255),
                        // const Color.fromARGB(255, 217, 0, 255),
                      ]
                    ),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_right,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right,
                  size: 28,
                  color: Colors.white,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}