import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'preference_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController heightController = TextEditingController();

  String selectedBodySize = 'Medium';

  void saveProfile() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PreferenceScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFAF4FF), Color(0xFFE0F7FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(35),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 25,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.checkroom,
                        size: 60,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "Create Your Profile",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      "Enter your details to get personalized outfit recommendations.",
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // ✅ Full Name
                    TextFormField(
                      controller: nameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Full Name is required";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: Colors.deepPurple.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ Height (Numbers Only)
                    TextFormField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Height is required";
                        }

                        final height = int.tryParse(value);
                        if (height == null) {
                          return "Enter a valid number";
                        }

                        if (height < 50 || height > 250) {
                          return "Enter realistic height (50 - 250 cm)";
                        }

                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Height (cm)',
                        prefixIcon: const Icon(Icons.height),
                        filled: true,
                        fillColor: Colors.deepPurple.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ Body Size
                    DropdownButtonFormField<String>(
                      value: selectedBodySize,
                      items: ['Small', 'Medium', 'Large']
                          .map(
                            (size) => DropdownMenuItem(
                          value: size,
                          child: Text(size),
                        ),
                      )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedBodySize = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Body Size',
                        filled: true,
                        fillColor: Colors.deepPurple.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ✅ Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Save Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}