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
  State<TeacherHomePage> createState() =>
      _TeacherHomePageState();
}

class _TeacherHomePageState
    extends State<TeacherHomePage> {

  // GitHub Actions Secret से API key आएगी
  static const String apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  // Current stable Gemini model
  static const String model = 'gemini-3.6-flash';

  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  final TextEditingController questionController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final stt.SpeechToText speech =
      stt.SpeechToText();

  final FlutterTts tts =
      FlutterTts();

  final ImagePicker imagePicker =
      ImagePicker();

  bool listening = false;
  bool loading = false;
  bool speechAvailable = false;

  XFile? selectedImage;

  String answer =
      'नमस्ते! मैं आपका AI Personal Teacher हूँ।\n'
      'सवाल लिखें, बोलें या फोटो भेजें।';

  @override
  void initState() {
    super.initState();

    setupTts();
    setupSpeech();
  }

  // =========================
  // TEXT TO SPEECH
  // =========================

  Future<void> setupTts() async {
    try {
      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(0.45);
      await tts.setPitch(1.0);
      await tts.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    try {
      await tts.stop();

      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(0.45);
      await tts.setPitch(1.0);
      await tts.setVolume(1.0);

      await tts.speak(text);
    } catch (_) {}
  }

  // =========================
  // SPEECH TO TEXT
  // =========================

  Future<void> setupSpeech() async {
    try {
      speechAvailable = await speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'done' ||
              status == 'notListening') {
            setState(() {
              listening = false;
            });
          }
        },
        onError: (_) {
          if (!mounted) return;

          setState(() {
            listening = false;
          });
        },
      );

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      speechAvailable = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> startListening() async {
    if (loading) return;

    if (!speechAvailable) {
      await setupSpeech();
    }

    if (!speechAvailable) {
      setState(() {
        answer =
            '🎤 Voice input उपलब्ध नहीं है।\n'
            'Microphone permission Allow करें।';
      });

      return;
    }

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
      setState(() {
        listening = true;
      });

      await speech.listen(
        localeId: 'hi_IN',
        listenMode: stt.ListenMode.dictation,
        listenFor:
            const Duration(seconds: 60),
        pauseFor:
            const Duration(seconds: 4),

        onResult: (result) {
          if (!mounted) return;

          setState(() {
            questionController.text =
                result.recognizedWords;

            questionController.selection =
                TextSelection.fromPosition(
              TextPosition(
                offset:
                    questionController.text.length,
              ),
            );

            if (result.finalResult) {
              listening = false;
            }
          });
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        listening = false;

        answer =
            '🎤 Voice input में समस्या हुई।\n$e';
      });
    }
  }

  // =========================
  // IMAGE PICKER
  // =========================

  Future<void> pickImage() async {
    if (loading) return;

    try {
      final XFile? image =
          await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;

        answer =
            '🖼️ फोटो चुनी गई है।\n'
            'अब सवाल लिखकर Send दबाएँ।';
      });
    } catch (e) {
      setState(() {
        answer =
            'फोटो चुनने में समस्या हुई:\n$e';
      });
    }
  }

  // =========================
  // GEMINI API
  // =========================

  Future<String> askGemini(
      String question) async {

    if (apiKey.trim().isEmpty) {
      throw Exception(
        'GEMINI_API_KEY उपलब्ध नहीं है।\n\n'
        'GitHub में जाएँ:\n'
        'Settings → Secrets and variables → Actions\n\n'
        'और GEMINI_API_KEY Secret जाँचें।',
      );
    }

    final Uri uri = Uri.parse(
      '$baseUrl/models/$model:generateContent',
    );

    final List<Map<String, dynamic>> parts =
        [];

    // =========================
    // IMAGE
    // =========================

    if (selectedImage != null) {
      final bytes = await File(
        selectedImage!.path,
      ).readAsBytes();

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
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Image,
        },
      });
    }

    // =========================
    // PROMPT
    // =========================

    final String prompt = '''
आप AI Personal Teacher हैं।

हमेशा आसान और साफ हिंदी में जवाब दें।

अगर सवाल गणित का है तो
calculation को step-by-step समझाएँ।

अगर सवाल पढ़ाई का है तो
teacher की तरह समझाएँ।

जरूरत होने पर उदाहरण दें।

अगर फोटो भेजी गई है तो
फोटो को ध्यान से देखकर जवाब दें।

छोटे सवाल का छोटा और सीधा जवाब दें।

अनावश्यक भूमिका न लिखें।

Student का सवाल:

$question
''';

    parts.add({
      'text': prompt,
    });

    // =========================
    // REQUEST BODY
    // =========================

    final Map<String, dynamic> body = {
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        }
      ],

      // Gemini 3.x में
      // temperature/top_p/top_k नहीं भेजना है
      'generationConfig': {
        'maxOutputTokens': 2048,
      },
    };

    late http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type':
                  'application/json',

              'x-goog-api-key':
                  apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 60),
          );
    } on SocketException {
      throw Exception(
        'Internet connection नहीं मिल रहा।\n'
        'Internet चालू करके फिर कोशिश करें।',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error:\n$e',
      );
    } catch (e) {
      throw Exception(
        'API connection error:\n$e',
      );
    }

    debugPrint(
      'Gemini HTTP Status: '
      '${response.statusCode}',
    );

    debugPrint(
      'Gemini Response: '
      '${response.body}',
    );

    // =========================
    // API ERROR
    // =========================

    if (response.statusCode != 200) {
      String message =
          'Gemini API Error '
          '${response.statusCode}';

      try {
        final dynamic errorData =
            jsonDecode(response.body);

        final dynamic error =
            errorData['error'];

        if (error is Map &&
            error['message'] != null) {
          message =
              error['message'].toString();
        }
      } catch (_) {}

      throw Exception(message);
    }

    // =========================
    // RESPONSE
    // =========================

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

    if (content is! Map) {
      throw Exception(
        'Gemini response format सही नहीं है।',
      );
    }

    final dynamic responseParts =
        content['parts'];

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

      if (part is Map &&
          part['text'] != null) {
        buffer.write(
          part['text'].toString(),
        );
      }
    }

    final String result =
        buffer.toString().trim();

    if (result.isEmpty) {
      throw Exception(
        'Gemini ने text answer नहीं दिया।',
      );
    }

    return result;
  }

  // =========================
  // ASK TEACHER
  // =========================

  Future<void> askTeacher() async {
    if (loading) return;

    final String question =
        questionController.text.trim();

    if (question.isEmpty &&
        selectedImage == null) {
      setState(() {
        answer =
            '✏️ पहले सवाल लिखें, बोलें '
            'या फोटो भेजें।';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    if (listening) {
      await speech.stop();

      setState(() {
        listening = false;
      });
    }

    final String displayQuestion =
        question.isEmpty
            ? 'इस फोटो को समझाकर बताइए।'
            : question;

    setState(() {
      loading = true;

      answer =
          '⏳ जवाब तैयार हो रहा है...';
    });

    try {
      final String result =
          await askGemini(
        displayQuestion,
      );

      if (!mounted) return;

      setState(() {
        answer = result;

        loading = false;

        questionController.clear();

        selectedImage = null;
      });

      // AI answer को बोलना
      await speak(result);

      scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      String error =
          e.toString();

      if (error.startsWith(
          'Exception: ')) {
        error =
            error.substring(11);
      }

      setState(() {
        loading = false;

        answer =
            '❌ समस्या\n\n$error';
      });

      scrollToBottom();
    }
  }

  // =========================
  // CLEAR
  // =========================

  void clearChat() {
    tts.stop();

    setState(() {
      answer =
          'नमस्ते! मैं आपका AI Personal Teacher हूँ।\n'
          'सवाल लिखें, बोलें या फोटो भेजें।';

      questionController.clear();

      selectedImage = null;
    });
  }

  // =========================
  // SCROLL
  // =========================

  void scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {

      if (!scrollController.hasClients) {
        return;
      }

      scrollController.animateTo(
        scrollController
            .position
            .maxScrollExtent,

        duration:
            const Duration(
          milliseconds: 300,
        ),

        curve: Curves.easeOut,
      );
    });
  }

  // =========================
  // DISPOSE
  // =========================

  @override
  void dispose() {
    questionController.dispose();

    scrollController.dispose();

    speech.stop();

    tts.stop();

    super.dispose();
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(

      // =========================
      // APP BAR
      // =========================

      appBar: AppBar(
        title: const Text(
          'AI Personal Teacher',

          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        centerTitle: true,

        actions: [
          IconButton(
            onPressed:
                loading
                    ? null
                    : clearChat,

            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      // =========================
      // BODY
      // =========================

      body: SafeArea(
        child: Column(
          children: [

            // =====================
            // ANSWER AREA
            // =====================

            Expanded(
              child: ListView(
                controller:
                    scrollController,

                padding:
                    const EdgeInsets.all(
                  16,
                ),

                children: [

                  // =================
                  // SELECTED IMAGE
                  // =================

                  if (selectedImage != null)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          10,
                        ),

                        child: Row(
                          children: [

                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),

                              child: Image.file(
                                File(
                                  selectedImage!
                                      .path,
                                ),

                                width: 70,
                                height: 70,

                                fit: BoxFit.cover,
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            const Expanded(
                              child: Text(
                                'फोटो तैयार है',

                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),

                            IconButton(
                              onPressed:
                                  loading
                                      ? null
                                      : () {
                                          setState(
                                            () {
                                              selectedImage =
                                                  null;
                                            },
                                          );
                                        },

                              icon:
                                  const Icon(
                                Icons.close,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // =================
                  // ANSWER CARD
                  // =================

                  Card(
                    elevation: 2,

                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        18,
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          Row(
                            children: [

                              Icon(
                                Icons.school,

                                color:
                                    Theme.of(
                                  context,
                                )
                                        .colorScheme
                                        .primary,

                                size: 30,
                              ),

                              const SizedBox(
                                width: 10,
                              ),

                              const Text(
                                'Teacher का जवाब',

                                style:
                                    TextStyle(
                                  fontSize: 22,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          SelectableText(
                            answer,

                            style:
                                const TextStyle(
                              fontSize: 17,
                              height: 1.55,
                            ),
                          ),

                          if (loading) ...[
                            const SizedBox(
                              height: 18,
                            ),

                            const LinearProgressIndicator(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // =========================
            // BOTTOM INPUT
            // =========================

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                8,
                8,
                8,
                10,
              ),

              decoration:
                  BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface,

                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    offset:
                        Offset(0, -2),
                  ),
                ],
              ),

              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,

                children: [

                  // PHOTO BUTTON
                  IconButton(
                    onPressed:
                        loading
                            ? null
                            : pickImage,

                    icon: const Icon(
                      Icons.image,
                      size: 30,
                    ),
                  ),

                  // TEXT FIELD
                  Expanded(
                    child: TextField(
                      controller:
                          questionController,

                      minLines: 1,
                      maxLines: 4,

                      decoration:
                          InputDecoration(
                        hintText:
                            listening
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

                  // VOICE BUTTON
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

                      color:
                          listening
                              ? Colors.red
                              : null,
                    ),
                  ),

                  // SEND BUTTON
                  IconButton(
                    onPressed:
                        loading
                            ? null
                            : askTeacher,

                    icon: Icon(
                      Icons.send,

                      size: 32,

                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .primary,
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
