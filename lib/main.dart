import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  bool loading = false;
  bool teacherMode = true;

  XFile? selectedImage;

  String answer =
      'नमस्ते! मैं आपका AI Personal Teacher हूँ।\n\n'
      'आप मुझसे कोई भी सवाल पूछ सकते हैं।';

  // API key GitHub Actions से dart-define के द्वारा आएगी।
  static const String apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  // Stable Gemini model.
  static const String model = 'gemini-2.5-flash';

  @override
  void initState() {
    super.initState();

    _setupTts();
  }

  Future<void> _setupTts() async {
    await tts.setLanguage('hi-IN');
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    try {
      await tts.stop();
      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  Future<void> pickPhoto() async {
    try {
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      setState(() {
        selectedImage = image;
        answer =
            '📷 फोटो मिल गई है।\n\nअब फोटो के बारे में सवाल पूछिए।';
      });

      await speak(
        'फोटो मिल गई है। अब फोटो के बारे में सवाल पूछिए।',
      );
    } catch (e) {
      setState(() {
        answer = 'फोटो चुनने में समस्या हुई।';
      });

      await speak('फोटो चुनने में समस्या हुई।');
    }
  }

  Future<void> takePhoto() async {
    try {
      final XFile? image =
          await picker.pickImage(source: ImageSource.camera);

      if (image == null) return;

      setState(() {
        selectedImage = image;
        answer =
            '📷 फोटो तैयार है।\n\nअब फोटो के बारे में सवाल पूछिए।';
      });

      await speak(
        'फोटो तैयार है। अब फोटो के बारे में सवाल पूछिए।',
      );
    } catch (e) {
      setState(() {
        answer = 'कैमरा खोलने में समस्या हुई।';
      });

      await speak('कैमरा खोलने में समस्या हुई।');
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

    try {
      final available = await speech.initialize(
        onError: (error) {
          if (mounted) {
            setState(() {
              listening = false;
              answer = '🎤 आवाज़ पहचानने में समस्या हुई।';
            });
          }
        },
      );

      if (!available) {
        setState(() {
          answer =
              '🎤 Microphone उपलब्ध नहीं है। कृपया microphone permission दें।';
        });

        await speak(
          'Microphone उपलब्ध नहीं है। कृपया microphone permission दें।',
        );

        return;
      }

      setState(() {
        listening = true;
      });

      await speech.listen(
        localeId: 'hi_IN',
        listenMode: stt.ListenMode.dictation,
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            questionController.text = result.recognizedWords;
            questionController.selection =
                TextSelection.fromPosition(
              TextPosition(
                offset: questionController.text.length,
              ),
            );
          });
        },
      );
    } catch (e) {
      setState(() {
        listening = false;
        answer = '🎤 Voice input में समस्या हुई।';
      });
    }
  }

  Future<String> askGemini(String question) async {
    if (apiKey.trim().isEmpty) {
      throw Exception(
        'GEMINI_API_KEY उपलब्ध नहीं है। GitHub Actions Secret check करें।',
      );
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$model:generateContent',
    );

    String prompt =
        '''
आप AI Personal Teacher हैं।

हमेशा आसान और साफ हिंदी में जवाब दें।
अगर सवाल गणित का है तो calculation step-by-step समझाएं।
अगर सवाल पढ़ाई का है तो student को teacher की तरह समझाएं।
अगर सवाल बहुत छोटा है तो छोटा और सीधा जवाब दें।
जरूरत होने पर उदाहरण दें।

Student का सवाल:
$question
''';

    final List<Map<String, dynamic>> parts = [];

    if (selectedImage != null) {
      final bytes =
          await File(selectedImage!.path).readAsBytes();

      final base64Image = base64Encode(bytes);

      String mimeType = 'image/jpeg';

      final extension =
          selectedImage!.path.split('.').last.toLowerCase();

      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }

      parts.add({
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Image,
        },
      });
    }

    parts.add({
      'text': prompt,
    });

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': parts,
              }
            ],
            'generationConfig': {
              'temperature': 0.4,
              'maxOutputTokens': 1000,
            },
          }),
        )
        .timeout(const Duration(seconds: 40));

    debugPrint('Gemini Status: ${response.statusCode}');
    debugPrint('Gemini Response: ${response.body}');

    if (response.statusCode != 200) {
      String errorMessage =
          'Gemini API Error: ${response.statusCode}';

      try {
        final errorData = jsonDecode(response.body);

        final apiError =
            errorData['error']?['message'];

        if (apiError != null) {
          errorMessage = apiError.toString();
        }
      } catch (_) {}

      throw Exception(errorMessage);
    }

    final data = jsonDecode(response.body);

    final candidates = data['candidates'];

    if (candidates == null ||
        candidates is! List ||
        candidates.isEmpty) {
      throw Exception(
        'Gemini ने कोई जवाब नहीं दिया।',
      );
    }

    final content =
        candidates[0]['content'];

    final responseParts =
        content?['parts'];

    if (responseParts == null ||
        responseParts is! List ||
        responseParts.isEmpty) {
      throw Exception(
        'Gemini response खाली है।',
      );
    }

    final buffer = StringBuffer();

    for (final part in responseParts) {
      final text = part['text'];

      if (text != null) {
        buffer.write(text);
      }
    }

    final result = buffer.toString().trim();

    if (result.isEmpty) {
      throw Exception(
        'Gemini ने खाली जवाब दिया।',
      );
    }

    return result;
  }

  Future<void> askTeacher() async {
    if (loading) return;

    final question =
        questionController.text.trim();

    if (question.isEmpty &&
        selectedImage == null) {
      setState(() {
        answer =
            '✍️ पहले अपना सवाल लिखिए या फोटो भेजिए।';
      });

      await speak(
        'पहले अपना सवाल लिखिए या फोटो भेजिए।',
      );

      return;
    }

    setState(() {
      loading = true;
      answer = '🤖 AI Teacher सोच रहा है...';
    });

    try {
      final finalQuestion = question.isEmpty
          ? 'इस फोटो को देखकर विद्यार्थी को आसान हिंदी में समझाइए।'
          : question;

      final response =
          await askGemini(finalQuestion);

      if (!mounted) return;

      setState(() {
        answer = response;
        loading = false;
      });

      // Gemini response के बाद आवाज़।
      await speak(response);

      // सफल जवाब के बाद input clear करें।
      if (mounted) {
        setState(() {
          questionController.clear();
          selectedImage = null;
        });
      }
    } on SocketException {
      if (!mounted) return;

      setState(() {
        loading = false;
        answer =
            '❌ Internet connection नहीं है।\n\n'
            'कृपया internet check करके दोबारा कोशिश करें।';
      });

      await speak(
        'Internet connection नहीं है। कृपया internet check करके दोबारा कोशिश करें।',
      );
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString();

      setState(() {
        loading = false;
        answer =
            '❌ AI से जवाब नहीं मिला।\n\n'
            '$errorText';
      });

      await speak(
        'AI से जवाब नहीं मिला। कृपया दोबारा कोशिश करें।',
      );
    }
  }

  void changeMode(bool teacher) {
    setState(() {
      teacherMode = teacher;
    });
  }

  @override
  void dispose() {
    questionController.dispose();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Personal Teacher',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text(
                        '🤖 AI Teacher',
                      ),
                      selected: teacherMode,
                      onSelected: (_) =>
                          changeMode(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text(
                        '📚 Study Mode',
                      ),
                      selected: !teacherMode,
                      onSelected: (_) =>
                          changeMode(false),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (selectedImage != null)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(8),
                        child: Text(
                          '📷 Photo selected\n'
                          '${selectedImage!.name}',
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  Card(
                    elevation: 3,
                    child: Padding(
                      padding:
                          const EdgeInsets.all(18),
                      child: loading
                          ? const Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 15),
                                Text(
                                  '🤖 AI Teacher जवाब तैयार कर रहा है...',
                                  style: TextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            )
                          : Text(
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

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Gallery',
                    onPressed:
                        loading ? null : pickPhoto,
                    icon: const Icon(
                      Icons.photo_library,
                      size: 30,
                    ),
                  ),

                  IconButton(
                    tooltip: 'Camera',
                    onPressed:
                        loading ? null : takePhoto,
                    icon: const Icon(
                      Icons.camera_alt,
                      size: 30,
                    ),
                  ),

                  Expanded(
                    child: TextField(
                      controller:
                          questionController,
                      minLines: 1,
                      maxLines: 4,
                      decoration:
                          InputDecoration(
                        hintText: listening
                            ? '🎤 सुन रहा हूँ...'
                            : 'अपना सवाल लिखें...',
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed:
                        loading
                            ? null
                            : startListening,
                    icon: Icon(
                      listening
                          ? Icons.mic
                          : Icons.mic_none,
                      size: 32,
                      color: listening
                          ? Colors.red
                          : null,
                    ),
                  ),

                  IconButton(
                    onPressed:
                        loading
                            ? null
                            : askTeacher,
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
