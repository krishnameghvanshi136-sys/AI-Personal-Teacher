import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

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
  final TextEditingController questionController =
      TextEditingController();

  final ImagePicker picker = ImagePicker();
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();

  bool listening = false;
  bool teacherMode = true;
  XFile? selectedImage;

  String answer =
      'नमस्ते! मैं आपका AI Personal Teacher हूँ। '
      'आप मुझसे पढ़ाई से जुड़ा कोई भी सवाल पूछ सकते हैं।';

  @override
  void initState() {
    super.initState();
    tts.setLanguage("hi-IN");
    tts.setSpeechRate(0.45);
  }

  Future<void> pickPhoto() async {
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImage = image;
        answer =
            '📷 फोटो मिल गई। अब आप इस फोटो के बारे में अपना सवाल पूछ सकते हैं।';
      });

      await tts.speak(
        'फोटो मिल गई। अब आप इस फोटो के बारे में अपना सवाल पूछ सकते हैं।',
      );
    }
  }

  Future<void> takePhoto() async {
    final XFile? image =
        await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        selectedImage = image;
        answer =
            '📷 फोटो तैयार है। अब अपना सवाल पूछिए।';
      });

      await tts.speak(
        'फोटो तैयार है। अब अपना सवाल पूछिए।',
      );
    }
  }

  Future<void> startListening() async {
    if (listening) {
      await speech.stop();
      setState(() {
        listening = false;
      });
      return;
    }

    final available = await speech.initialize();

    if (!available) {
      setState(() {
        answer = 'माइक्रोफोन उपलब्ध नहीं है। कृपया microphone permission दें।';
      });
      return;
    }

    setState(() {
      listening = true;
    });

    await speech.listen(
      localeId: 'hi_IN',
      onResult: (result) {
        setState(() {
          questionController.text = result.recognizedWords;
        });
      },
    );
  }

  Future<void> askTeacher() async {
    final question = questionController.text.trim();

    if (question.isEmpty && selectedImage == null) {
      return;
    }

    String response;

    if (teacherMode) {
      response =
          '👨‍🏫 AI Teacher Mode\n\n'
          'आपका सवाल: ${question.isEmpty ? "फोटो से संबंधित सवाल" : question}\n\n'
          'मैं इसे आसान भाषा में समझाऊँगा। '
          'अभी यह ऐप AI से कनेक्ट करने के लिए तैयार है। '
          'अगले चरण में इसमें असली AI जवाब जोड़ा जाएगा।';
    } else {
      response =
          '🎯 Study Mode\n\n'
          'चलिए इस सवाल को step-by-step समझते हैं:\n\n'
          '1. सवाल को ध्यान से पढ़ें।\n'
          '2. दिए गए facts पहचानें।\n'
          '3. सही formula या concept चुनें।\n'
          '4. फिर answer निकालें।';
    }

    setState(() {
      answer = response;
    });

    await tts.speak(response);
  }

  void changeMode(bool teacher) {
    setState(() {
      teacherMode = teacher;
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

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // AI MODE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('🤖 AI Teacher'),
                      selected: teacherMode,
                      onSelected: (_) => changeMode(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('📚 Study Mode'),
                      selected: !teacherMode,
                      onSelected: (_) => changeMode(false),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ANSWER AREA
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (selectedImage != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '📷 Photo selected\n${selectedImage!.name}',
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        answer,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // INPUT
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Gallery',
                    onPressed: pickPhoto,
                    icon: const Icon(
                      Icons.photo_library,
                      size: 30,
                    ),
                  ),

                  IconButton(
                    tooltip: 'Camera',
                    onPressed: takePhoto,
                    icon: const Icon(
                      Icons.camera_alt,
                      size: 30,
                    ),
                  ),

                  Expanded(
                    child: TextField(
                      controller: questionController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: listening
                            ? 'सुन रहा हूँ...'
                            : 'अपना सवाल लिखें...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: startListening,
                    icon: Icon(
                      listening ? Icons.mic : Icons.mic_none,
                      size: 32,
                      color: listening ? Colors.red : null,
                    ),
                  ),

                  IconButton(
                    onPressed: askTeacher,
                    icon: const Icon(
                      Icons.send,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
