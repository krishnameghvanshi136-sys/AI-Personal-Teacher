import 'package:flutter/material.dart';

void main() {
  runApp(const AIPersonalTeacher());
}

class AIPersonalTeacher extends StatelessWidget {
  const AIPersonalTeacher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Personal Teacher',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const TeacherHomePage(),
    );
  }
}

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];

  void _askTeacher() {
    final question = _controller.text.trim();

    if (question.isEmpty) return;

    setState(() {
      _messages.add("आप: $question");
      _messages.add(
        "AI Teacher: आपका सवाल समझ गया। मैं आपकी पढ़ाई में मदद करने के लिए तैयार हूँ।",
      );
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Personal Teacher',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school,
                          size: 80,
                          color: Colors.deepPurple,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'नमस्ते! मैं आपका AI Personal Teacher हूँ।',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'अपना सवाल नीचे लिखें।',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _messages[index],
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'अपना सवाल लिखें...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                      ),
                      onSubmitted: (_) => _askTeacher(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _askTeacher,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
