import 'package:flutter/material.dart';
import '../components/badapple_video_player.dart';

class BadAppleScreen extends StatefulWidget {
  const BadAppleScreen({super.key});

  @override
  State<BadAppleScreen> createState() => _BadAppleScreenState();
}

class _BadAppleScreenState extends State<BadAppleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BadApple Video Player'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'BadApple ESP32 Codec Demo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),              // Video player with scaling for better visibility
              Transform.scale(
                scale: 4.0, // Scale up the video for better visibility
                child: const BadAppleVideoPlayer(
                  assetPath: 'assets/result.bin', // Path to your bin file
                  width: 120,
                  height: 75,
                  autoPlay: true,
                  loop: true,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'This video is rendered using a custom ESP32 codec\nwith delta compression and run-length encoding.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
