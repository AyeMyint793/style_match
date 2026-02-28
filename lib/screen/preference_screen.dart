import 'package:flutter/material.dart';
import 'home_screen.dart';

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({Key? key}) : super(key: key);

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {

  List<String> styles = ["Casual", "Formal", "Loose", "Party"];
  List<String> selectedStyles = [];

  void toggleStyle(String style) {
    setState(() {
      if (selectedStyles.contains(style)) {
        selectedStyles.remove(style);
      } else {
        selectedStyles.add(style);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Your Style"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: styles.map((style) {
                final isSelected = selectedStyles.contains(style);
                return ChoiceChip(
                  label: Text(style),
                  selected: isSelected,
                  onSelected: (_) => toggleStyle(style),
                );
              }).toList(),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  ),
                );
              },
              child: const Text("Save Preferences"),
            ),

            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "You can update preferences anytime in Settings.",
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                Future.delayed(const Duration(seconds: 2), () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                  );
                });
              },
              child: const Text("Skip for now"),
            ),
          ],
        ),
      ),
    );
  }
}