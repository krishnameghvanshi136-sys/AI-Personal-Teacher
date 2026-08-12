import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';

const String geminiApiKey =
    String.fromEnvironment('GEMINI_API_KEY');

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
  State<TeacherHomePage> createState() =>
      _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TextEditingController controller =
      TextEditingController();

  final stt.SpeechToText speech =
      stt.SpeechToText();

  final FlutterTts tts =
      FlutterTts();

  final ImagePicker picker =
      ImagePicker();

  bool listening = false;
  bool loading = false;
  bool teacherMode = true;

  XFile? selectedImage;

  String answer =
      'नमस्ते! 👋\n\n'
      'मैं आपका AI Personal Teacher हूँ।\n\n'
      'अपना सवाल लिखकर Send दबाइए।';

  @override
  void initState() {
    super.initState();

    tts.setLanguage('hi-IN');
    tts.setSpeechRate(0.45);
    tts.setPitch(1.0);
  }

  // ==============================
  // GEMINI AI
  // ==============================

  Future<String> askGemini(String question) async {
    if (geminiApiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY नहीं मिली।\n'
        'GitHub Actions में secret सही नाम से जोड़ें।',
      );
    }

    final List<Map<String, dynamic>> parts = [];

    parts.add({
      'text': '''
आप एक बहुत अच्छे AI Personal Teacher हैं।

यूज़र के सवाल का जवाब आसान हिंदी/Hinglish में दें।
अगर सवाल पढ़ाई से जुड़ा है तो step-by-step समझाएँ।
गणित में calculation साफ दिखाएँ।
अगर बच्चा सवाल पूछ रहा है तो बहुत आसान भाषा इस्तेमाल करें।
जवाब में अनावश्यक बातें न करें।

यूज़र का सवाल:
$question
'''
    });

    if (selectedImage != null) {
      final bytes =
          await File(selectedImage!.path).readAsBytes();

      final base64Image =
          base64Encode(bytes);

      final extension =
          selectedImage!.path
              .split('.')
              .last
              .toLowerCase();

      String mimeType = 'image/jpeg';

      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }

      parts.add({
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Image,
        }
      });
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/'
      'v1beta/models/gemini-3.6-flash:generateContent',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': geminiApiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': parts,
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1200,
        },
      }),
    );

    if (response.statusCode != 200) {
      String message = 'Gemini API Error';

      try {
        final data =
            jsonDecode(response.body);

        message =
            data['error']?['message'] ??
                message;
      } catch (_) {}

      throw Exception(
        '$message\n\nHTTP ${response.statusCode}',
      );
    }

    final data =
        jsonDecode(response.body);

    final candidates =
        data['candidates'];

    if (candidates == null ||
        candidates.isEmpty) {
      throw Exception(
        'Gemini ने कोई जवाब नहीं दिया।',
      );
    }

    final content =
        candidates[0]['content'];

    final responseParts =
        content['parts'];

    if (responseParts == null ||
        responseParts.isEmpty) {
      throw Exception(
        'AI response खाली मिला।',
      );
    }

    final buffer =
        StringBuffer();

    for (final part in responseParts) {
      if (part['text'] != null) {
        buffer.write(part['text']);
      }
    }

    final result =
        buffer.toString().trim();

    if (result.isEmpty) {
      throw Exception(
        'AI ने खाली जवाब दिया।',
      );
    }

    return result;
  }

  // ==============================
  // SEND QUESTION
  // ==============================

  Future<void> askTeacher() async {
    final question =
        controller.text.trim();

    if (question.isEmpty &&
        selectedImage == null) {
      return;
    }

    if (loading) return;

    setState(() {
      loading = true;
      answer =
          '🤖 AI सोच रहा है...\n\nकृपया थोड़ा इंतजार करें।';
    });

    try {
      final result =
          await askGemini(
        question.isEmpty
            ? 'इस फोटो को देखकर समझाइए कि इसमें क्या है।'
            : question,
      );

      if (!mounted) return;

      setState(() {
        answer = result;
        loading = false;
      });

      await tts.stop();
      await tts.speak(result);
    } catch (e) {
      if (!mounted) return;

      final error =
          e.toString()
              .replaceFirst('Exception: ', '');

      setState(() {
        answer =
            '❌ AI से जवाब नहीं मिला।\n\n$error';
        loading = false;
      });
    }
  }

  // ==============================
  // MICROPHONE
  // ==============================

  Future<void> startListening() async {
    if (listening) {
      await speech.stop();

      if (mounted) {
        setState(() {
          listening = false;
        });
      }

      return;
    }

    final available =
        await speech.initialize(
      onStatus: (status) {
        if (status == 'done' &&
            mounted) {
          setState(() {
            listening = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            listening = false;
            answer =
                '🎤 Microphone error:\n${error.errorMsg}';
          });
        }
      },
    );

    if (!available) {
      setState(() {
        answer =
            '🎤 Microphone उपलब्ध नहीं है।\n\n'
            'Microphone permission दें।';
      });
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
          controller.text =
              result.recognizedWords;

          controller.selection =
              TextSelection.fromPosition(
            TextPosition(
              offset: controller.text.length,
            ),
          );
        });
      },
    );
  }

  // ==============================
  // GALLERY
  // ==============================

  Future<void> pickPhoto() async {
    try {
      final image =
          await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;
        answer =
            '📷 फोटो select हो गई है।\n\n'
            'अब सवाल लिखकर Send दबाएँ।';
      });
    } catch (e) {
      setState(() {
        answer =
            '❌ फोटो select नहीं हो सकी।\n\n$e';
      });
    }
  }

  // ==============================
  // CAMERA
  // ==============================

  Future<void> takePhoto() async {
    try {
      final image =
          await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;
        answer =
            '📸 फोटो तैयार है।\n\n'
            'अब अपना सवाल पूछिए।';
      });
    } catch (e) {
      setState(() {
        answer =
            '❌ Camera नहीं खुल सका।\n\n$e';
      });
    }
  }

  // ==============================
  // BUILD
  // ==============================

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

            // MODE BUTTONS
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text(
                        '🤖 AI Teacher',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      selected: teacherMode,
                      onSelected: (_) {
                        setState(() {
                          teacherMode = true;
                        });
                      },
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ChoiceChip(
                      label: const Text(
                        '📚 Study Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      selected: !teacherMode,
                      onSelected: (_) {
                        setState(() {
                          teacherMode = false;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ANSWER
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.all(16),
                children: [
                  if (selectedImage != null)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.image,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedImage!.name,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedImage =
                                      null;
                                });
                              },
                              icon: const Icon(
                                Icons.close,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  Card(
                    elevation: 4,
                    child: Padding(
                      padding:
                          const EdgeInsets.all(18),
                      child: loading
                          ? const Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 15),
                                Text(
                                  'AI जवाब तैयार कर रहा है...',
                                  style: TextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            )
                          : SelectableText(
                              answer,
                              style:
                                  const TextStyle(
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
              padding:
                  const EdgeInsets.fromLTRB(
                8,
                4,
                8,
                10,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
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
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction:
                          TextInputAction.newline,
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
                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Voice',
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
                    tooltip: 'Send',
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
