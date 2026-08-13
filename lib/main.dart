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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
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
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String model = 'gemini-2.5-flash';

  final TextEditingController questionController =
      TextEditingController();

  final stt.SpeechToText speech = stt.SpeechToText();

  final FlutterTts tts = FlutterTts();

  final ImagePicker imagePicker = ImagePicker();

  bool listening = false;
  bool loading = false;

  XFile? selectedImage;

  String answer =
      '👩‍🏫 नमस्ते! मैं AI Personal Teacher हूँ।\n\n'
      'अपना सवाल लिखें या 🎤 से बोलकर पूछें।';

  @override
  void initState() {
    super.initState();
    setupTts();
  }

  @override
  void dispose() {
    questionController.dispose();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  Future<void> setupTts() async {
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
      await tts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  Future<void> startListening() async {
    if (loading) return;

    if (listening) {
      await speech.stop();

      if (mounted) {
        setState(() {
          listening = false;
        });
      }

      return;
    }

    try {
      final bool available = await speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'done' ||
              status == 'notListening') {
            setState(() {
              listening = false;
            });
          }
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            listening = false;
            answer =
                '🎤 Voice input में समस्या हुई।\n$error';
          });
        },
      );

      if (!available) {
        if (mounted) {
          setState(() {
            answer =
                '🎤 Speech recognition उपलब्ध नहीं है।\n'
                'Microphone permission check करें।';
          });
        }

        return;
      }

      if (mounted) {
        setState(() {
          listening = true;
        });
      }

      await speech.listen(
        localeId: 'hi_IN',
        listenMode: stt.ListenMode.dictation,
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            questionController.text =
                result.recognizedWords;

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
      if (!mounted) return;

      setState(() {
        listening = false;
        answer =
            '🎤 Voice input में समस्या हुई:\n$e';
      });
    }
  }

  Future<void> pickImage({
    bool camera = false,
  }) async {
    if (loading) return;

    try {
      final XFile? image =
          await imagePicker.pickImage(
        source: camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        answer =
            '🖼️ फोटो चुन ली गई है।\n'
            'अब अपना सवाल भेजें।';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        answer =
            '🖼️ फोटो खोलने में समस्या हुई:\n$e';
      });
    }
  }

  Future<void> askTeacher() async {
    final String question =
        questionController.text.trim();

    if (question.isEmpty &&
        selectedImage == null) {
      setState(() {
        answer =
            '✍️ पहले सवाल लिखें या 🎤 से बोलें।';
      });

      return;
    }

    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      final String result =
          await askGemini(question);

      if (!mounted) return;

      setState(() {
        answer = result;
        loading = false;
        questionController.clear();
        selectedImage = null;
      });

      await speak(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        answer =
            '❌ Gemini Error:\n\n$e';
      });
    }
  }

  Future<String> askGemini(
    String question,
  ) async {
    if (apiKey.trim().isEmpty) {
      throw Exception(
        'GEMINI_API_KEY खाली है।\n\n'
        'GitHub Actions → Secrets में '
        'GEMINI_API_KEY check करें और नया APK build करें।',
      );
    }

    final Uri url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$model:generateContent',
    );

    final String prompt = '''
आप AI Personal Teacher हैं।

हमेशा आसान और साफ हिंदी में जवाब दें।

अगर सवाल गणित का है तो calculation
step-by-step समझाएँ।

अगर सवाल पढ़ाई का है तो student को
teacher की तरह समझाएँ।

सवाल छोटा हो तो जवाब छोटा रखें।

जरूरत हो तो उदाहरण दें।

Student का सवाल:

$question
''';

    final List<Map<String, dynamic>> parts = [];

    if (selectedImage != null) {
      final File imageFile =
          File(selectedImage!.path);

      final List<int> bytes =
          await imageFile.readAsBytes();

      final String base64Image =
          base64Encode(bytes);

      String mimeType = 'image/jpeg';

      final String extension =
          selectedImage!.path
              .split('.')
              .last
              .toLowerCase();

      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }

      parts.add({
        'inlineData': {
          'mimeType': mimeType,
          'data': base64Image,
        },
      });
    }

    parts.add({
      'text': prompt,
    });

    http.Response response;

    try {
      response = await http
          .post(
            url,
            headers: {
              'Content-Type':
                  'application/json',
              'x-goog-api-key':
                  apiKey.trim(),
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': parts,
                },
              ],
              'generationConfig': {
                'temperature': 0.4,
                'maxOutputTokens': 1000,
              },
            }),
          )
          .timeout(
            const Duration(seconds: 45),
          );
    } catch (e) {
      throw Exception(
        'Google Gemini से connection नहीं हो पाया।\n\n'
        'Internet/API connection check करें।\n\n'
        'Technical error:\n$e',
      );
    }

    debugPrint(
      'Gemini Status: ${response.statusCode}',
    );

    debugPrint(
      'Gemini Response: ${response.body}',
    );

    if (response.statusCode != 200) {
      String errorMessage =
          'Gemini API Error '
          '(${response.statusCode})';

      try {
        final dynamic errorData =
            jsonDecode(response.body);

        final dynamic apiError =
            errorData['error']?['message'];

        if (apiError != null) {
          errorMessage =
              '$errorMessage\n$apiError';
        }
      } catch (_) {
        if (response.body.trim().isNotEmpty) {
          errorMessage =
              '$errorMessage\n${response.body}';
        }
      }

      throw Exception(errorMessage);
    }

    final dynamic data =
        jsonDecode(response.body);

    final dynamic candidates =
        data['candidates'];

    if (candidates is! List ||
        candidates.isEmpty) {
      throw Exception(
        'Gemini ने कोई जवाब नहीं दिया।',
      );
    }

    final dynamic content =
        candidates[0]['content'];

    final dynamic responseParts =
        content?['parts'];

    if (responseParts is! List ||
        responseParts.isEmpty) {
      throw Exception(
        'Gemini response खाली है।',
      );
    }

    final StringBuffer buffer =
        StringBuffer();

    for (final dynamic part
        in responseParts) {
      final dynamic text =
          part['text'];

      if (text is String &&
          text.isNotEmpty) {
        buffer.write(text);
      }
    }

    final String result =
        buffer.toString().trim();

    if (result.isEmpty) {
      throw Exception(
        'Gemini ने text response नहीं दिया।',
      );
    }

    return result;
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
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '👩‍🏫 AI Teacher',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        if (selectedImage != null)
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            child: Image.file(
                              File(
                                selectedImage!.path,
                              ),
                              height: 180,
                              width:
                                  double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),

                        const SizedBox(
                          height: 12,
                        ),

                        SelectableText(
                          answer,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.5,
                          ),
                        ),

                        if (loading) ...[
                          const SizedBox(
                            height: 18,
                          ),
                          const LinearProgressIndicator(),
                          const SizedBox(
                            height: 8,
                          ),
                          const Text(
                            '🤔 जवाब तैयार हो रहा है...',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                8,
                8,
                8,
                10,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Gallery',
                    onPressed: loading
                        ? null
                        : () => pickImage(),
                    icon: const Icon(
                      Icons.photo_library,
                      size: 28,
                    ),
                  ),

                  IconButton(
                    tooltip: 'Camera',
                    onPressed: loading
                        ? null
                        : () => pickImage(
                              camera: true,
                            ),
                    icon: const Icon(
                      Icons.camera_alt,
                      size: 28,
                    ),
                  ),

                  Expanded(
                    child: TextField(
                      controller:
                          questionController,
                      enabled: !loading,
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
                              BorderRadius.circular(
                            25,
                          ),
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Voice',
                    onPressed: loading
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
                    tooltip: 'Ask',
                    onPressed: loading
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
