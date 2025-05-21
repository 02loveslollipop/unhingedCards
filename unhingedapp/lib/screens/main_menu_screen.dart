import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import google_fonts

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Define colors based on the minimalist theme
    // const Color backgroundColor = Colors.white; // Theme is now dark from main.dart
    // const Color foregroundColor = Colors.black; // Theme is now dark from main.dart
    const Color buttonTextColor = Colors.black; // Text on white buttons
    const Color buttonBackgroundColor = Colors.white; // White buttons

    final String disclaimerText = '''
Cards Against Humanity is free to use under the Creative Commons BY-NC-SA 2.0 License (http://creativecommons.org/licenses/by-nc-sa/2.0/).
This project, "Unhinged Cards", is a derivative work offered under the same license. 
It is not for sale, does not generate profit, and is in no way affiliated with Cards Against Humanity LLC.
Please comply with the Laws of Man and Nature. Do not use this game for nefarious purposes such as libel, slander, diarrhea,
copyright infringement, harassment, or death.
To comply with the previous license, the source code and assets of this project are available at: (add repo link here).
''';

    return Scaffold(
      // backgroundColor: backgroundColor, // Handled by global theme
      appBar: AppBar(
        title: Text(
          'Unhinged Cards',
          // style: TextStyle(color: foregroundColor), // Handled by global theme
          style: GoogleFonts.montserrat(
            // Using Montserrat for AppBar title too for consistency
            fontWeight: FontWeight.bold,
          ),
        ),
        // backgroundColor: backgroundColor, // Handled by global theme
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0), // Fixed this line
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Replace RichText with a Column for vertical arrangement
              Column(
                crossAxisAlignment: CrossAxisAlignment.center, // Center children horizontally
                children: [
                  Text(
                    'Unhinged',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      // color: foregroundColor, // Handled by global theme
                    ),
                  ),
                  const SizedBox(height: 8.0), // Vertical spacing (0.5rem equivalent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0), // Adjusted padding for the box
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      'Cards',
                      style: GoogleFonts.montserrat(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.black, // Black text for "Cards"
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48), // Increased spacing
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBackgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  textStyle: GoogleFonts.montserrat(
                    // Use Montserrat for button text
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: () {
                  // TODO: Implement Create Room navigation/logic
                  print('Create Room button pressed');
                },
                child: const Text(
                  'Create Room',
                  style: TextStyle(color: buttonTextColor),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBackgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  textStyle: GoogleFonts.montserrat(
                    // Use Montserrat for button text
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: () {
                  // TODO: Implement Join Room navigation/logic
                  print('Join Room button pressed');
                },
                child: const Text(
                  'Join Room',
                  style: TextStyle(color: buttonTextColor),
                ),
              ),
              const SizedBox(height: 48), // Increased spacing
              Text(
                disclaimerText,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  // Use Montserrat for disclaimer
                  fontSize: 10,
                  // color: foregroundColor.withOpacity(0.7), // Slightly dimmer text
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
