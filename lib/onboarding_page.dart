import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class OnboardingPage extends StatefulWidget {
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Widget> _pages = [
    _IntroPage(),
    _StudyAreaPage(),
    _HowToUsePage(),
  ];

  Future<void> _nextOrFinish() async {
    if (_currentIndex < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // MARK TOUR AS SEEN
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenTour', true);

      // GO TO MAIN PAGE
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.blue.shade600,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentIndex = i),
              children: _pages,
            ),
            // dot indicators
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _currentIndex == i ? Colors.white : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
            // Next / Understood button
            Positioned(
              bottom: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: _nextOrFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text(isLast ? "Understood" : "Next"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _IntroPage() {
  return Container(
    color: Colors.blue.shade600,
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            "Welcome to TurinGo!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Text(
            "A university project for urban trip planning in Turin. "
            "This version covers only a specific study area; future updates will expand to all Piedmont.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, height: 1.4),
          ),
        ],
      ),
    ),
  );
}

Widget _StudyAreaPage() {
  return Container(
    color: Colors.blue.shade600,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Center(
      child: LayoutBuilder(builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth * 0.9).clamp(0.0, 500.0);
        final imageHeight = cardWidth * 3 / 4;
        return Container(
          width: cardWidth,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              "This is the study area.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Route planning is available only inside this zone.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/study_area_highlighted.jpg',
                width: cardWidth - 32,
                height: imageHeight,
                fit: BoxFit.contain,
              ),
            ),
          ]),
        );
      }),
    ),
  );
}

Widget _HowToUsePage() {
  return Container(
    color: Colors.blue.shade600,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text(
          "How to use it",
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _instructionRow(Icons.location_pin, "Tap the map to drop pins"),
        const SizedBox(height: 20),
        _instructionRow(Icons.directions, "Tap 'Direction' to calculate a route"),
        const SizedBox(height: 20),
        _instructionRow(Icons.save, "Save trips (Depart at/Arrive by)"),
        const SizedBox(height: 20),
        _instructionRow(Icons.bookmark, "View saved routes under 'Saved'"),
        const SizedBox(height: 20),
        _instructionRow(Icons.notifications_active, "Notifications for trip changes"),
        const SizedBox(height: 20),
        _instructionRow(Icons.settings, "Trip alerts appear in Settings"),
      ]),
    ),
  );
}

Widget _instructionRow(IconData icon, String text) {
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: Colors.white, size: 28),
    const SizedBox(width: 12),
    Expanded(
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.4)),
    ),
  ]);
}
