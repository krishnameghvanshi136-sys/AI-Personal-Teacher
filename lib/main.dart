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
  // ============================================================
  // GEMINI CONFIGURATION
  // ============================================================

  static const String apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  static const String model = 'gemini-2.5-flash';

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController questionController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  // ============================================================
  // SERVICES
  // ============================================================

  final stt.SpeechToText speech = stt.SpeechToText();

  final FlutterTts tts = FlutterTts();

  final ImagePicker imagePicker = ImagePicker();

  // ============================================================
  // STATE
  // ============================================================

  bool listening = false;
  bool loading = false;
  bool speechAvailable = false;
  bool ttsAvailable = true;

  XFile? selectedImage;

  String answer =
      'नमस्ते! 🙏\nमैं आपका AI Personal Teacher हूँ।\n\n'
      'आप अपना सवाल लिख सकते हैं या 🎤 माइक्रोफोन दबाकर बोल सकते हैं।';

  String statusMessage = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    setupSpeech();
    setupTts();
  }

  // ============================================================
  // SPEECH TO TEXT SETUP
  // ============================================================

  Future<void> setupSpeech() async {
    try {
      final available = await speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'done' || status == 'notListening') {
            setState(() {
              listening = false;
            });
          }
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            listening = false;
            statusMessage = '🎤 Voice Error: ${error.errorMsg}';
          });
        },
      );

      if (!mounted) return;

      setState(() {
        speechAvailable = available;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        speechAvailable = false;
        statusMessage = '🎤 Voice setup error: $e';
      });
    }
  }

  // ============================================================
  // TEXT TO SPEECH SETUP
  // ============================================================

  Future<void> setupTts() async {
    try {
      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);

      ttsAvailable = true;
    } catch (e) {
      ttsAvailable = false;

      if (mounted) {
        setState(() {
          statusMessage = '🔊 TTS Error: $e';
        });
      }
    }
  }

  // ============================================================
  // SPEAK
  // ============================================================

  Future<void> speak(String text) async {
    if (!ttsAvailable) return;

    try {
      await tts.stop();

      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);

      await tts.speak(text);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = '🔊 Voice output error: $e';
      });
    }
  }

  // ============================================================
  // START / STOP LISTENING
  // ============================================================

  Future<void> startListening() async {
    if (loading) return;

    if (!speechAvailable) {
      await setupSpeech();
    }

    if (!speechAvailable) {
      if (!mounted) return;

      setState(() {
        statusMessage =
            '🎤 Microphone/Voice उपलब्ध नहीं है। '
            'फोन में Microphone permission check करें।';
      });

      return;
    }

    if (listening) {
      await stopListening();
      return;
    }

    try {
      await tts.stop();

      setState(() {
        listening = true;
        statusMessage = '🎤 सुन रहा हूँ...';
      });

      await speech.listen(
        localeId: 'hi_IN',
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        onResult: (result) {
          if (!mounted) return;

          final text = result.recognizedWords;

          setState(() {
            questionController.text = text;

            questionController.selection =
                TextSelection.fromPosition(
              TextPosition(
                offset: questionController.text.length,
              ),
            );
          });

          if (result.finalResult) {
            setState(() {
              listening = false;
              statusMessage = '✅ Voice input मिल गया';
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        listening = false;
        statusMessage = '🎤 Voice input error: $e';
      });
    }
  }

  Future<void> stopListening() async {
    try {
      await speech.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      listening = false;
      statusMessage = '';
    });
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> pickImage() async {
    if (loading) return;

    try {
      final image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        statusMessage = '🖼️ Image selected';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = '🖼️ Image error: $e';
      });
    }
  }

  void removeImage() {
    setState(() {
      selectedImage = null;
      statusMessage = '';
    });
  }

  // ============================================================
  // MIME TYPE
  // ============================================================

  String getMimeType(String path) {
    final extension =
        path.split('.').last.toLowerCase();

    switch (extension) {
      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  // ============================================================
  // ASK GEMINI
  // ============================================================

  Future<String> askGemini(String question) async {
    // ----------------------------------------------------------
    // API KEY CHECK
    // ----------------------------------------------------------

    if (apiKey.trim().isEmpty) {
      throw Exception(
        'GEMINI_API_KEY खाली है.\n\n'
        'GitHub Actions में Repository Secret '
        '`GEMINI_API_KEY` check करें और APK दोबारा build करें.',
      );
    }

    // ----------------------------------------------------------
    // URL
    // ----------------------------------------------------------

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$model:generateContent',
    );

    // ----------------------------------------------------------
    // PROMPT
    // ----------------------------------------------------------

    final prompt = '''
आप AI Personal Teacher हैं।

आपका काम student को आसान और साफ हिंदी में समझाना है।

नियम:

1. हमेशा आसान हिंदी में जवाब दें।
2. जरूरत होने पर English शब्दों का इस्तेमाल कर सकते हैं।
3. गणित के सवाल में step-by-step calculation समझाएं।
4. पढ़ाई के सवाल में teacher की तरह समझाएं।
5. अगर सवाल का जवाब उदाहरण से समझाया जा सकता है तो उदाहरण दें।
6. जवाब साफ और उपयोगी रखें।
7. अगर image दी गई है तो image को देखकर सवाल का जवाब दें।
8. गलत जानकारी न दें।
9. अगर सवाल स्पष्ट नहीं है तो clarification मांगें।

Student का सवाल:

$question
''';

    // ----------------------------------------------------------
    // CONTENT PARTS
    // ----------------------------------------------------------

    final List<Map<String, dynamic>> parts = [];

    // ----------------------------------------------------------
    // IMAGE
    // ----------------------------------------------------------

    if (selectedImage != null) {
      final bytes =
          await File(selectedImage!.path).readAsBytes();

      final base64Image = base64Encode(bytes);

      final mimeType =
          getMimeType(selectedImage!.path);

      parts.add({
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Image,
        },
      });
    }

    // ----------------------------------------------------------
    // TEXT
    // ----------------------------------------------------------

    parts.add({
      'text': prompt,
    });

    // ----------------------------------------------------------
    // REQUEST
    // ----------------------------------------------------------

    final requestBody = {
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
    };

    try {
      debugPrint('================================');
      debugPrint('GEMINI REQUEST START');
      debugPrint('MODEL: $model');
      debugPrint('QUESTION: $question');
      debugPrint('================================');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey.trim(),
            },
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 30),
          );

      // --------------------------------------------------------
      // DEBUG
      // --------------------------------------------------------

      debugPrint(
        'GEMINI STATUS: ${response.statusCode}',
      );

      debugPrint(
        'GEMINI RESPONSE: ${response.body}',
      );

      // --------------------------------------------------------
      // ERROR
      // --------------------------------------------------------

      if (response.statusCode != 200) {
        String errorMessage =
            'Gemini API Error ${response.statusCode}';

        try {
          final errorData =
              jsonDecode(response.body);

          final apiError =
              errorData['error'];

          if (apiError != null) {
            final message =
                apiError['message'];

            final status =
                apiError['status'];

            if (message != null) {
              errorMessage +=
                  '\n\n$message';
            }

            if (status != null) {
              errorMessage +=
                  '\nStatus: $status';
            }
          }
        } catch (_) {
          errorMessage +=
              '\n\n${response.body}';
        }

        throw Exception(errorMessage);
      }

      // --------------------------------------------------------
      // JSON
      // --------------------------------------------------------

      final data =
          jsonDecode(response.body);

      final candidates =
          data['candidates'];

      if (candidates == null ||
          candidates is! List ||
          candidates.isEmpty) {
        throw Exception(
          'Gemini ने कोई जवाब नहीं दिया.',
        );
      }

      final firstCandidate =
          candidates[0];

      final content =
          firstCandidate['content'];

      if (content == null) {
        throw Exception(
          'Gemini response में content नहीं मिला.',
        );
      }

      final responseParts =
          content['parts'];

      if (responseParts == null ||
          responseParts is! List ||
          responseParts.isEmpty) {
        throw Exception(
          'Gemini response में text नहीं मिला.',
        );
      }

      final buffer =
          StringBuffer();

      for (final part in responseParts) {
        if (part is Map &&
            part['text'] != null) {
          buffer.write(
            part['text'].toString(),
          );
        }
      }

      final result =
          buffer.toString().trim();

      if (result.isEmpty) {
        throw Exception(
          'Gemini ने खाली जवाब दिया.',
        );
      }

      debugPrint(
        'GEMINI SUCCESS',
      );

      return result;
    } on SocketException {
      throw Exception(
        'Internet connection नहीं है.\n'
        'कृपया mobile data/Wi-Fi check करें.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error:\n$e',
      );
    } catch (e) {
      debugPrint(
        'GEMINI FINAL ERROR: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // ASK TEACHER
  // ============================================================

  Future<void> askTeacher() async {
    if (loading) return;

    final question =
        questionController.text.trim();

    if (question.isEmpty &&
        selectedImage == null) {
      setState(() {
        answer =
            '✍️ पहले अपना सवाल लिखें या 🎤 बोलें।';
        statusMessage = '';
      });

      await speak(
        'पहले अपना सवाल लिखें या बोलें।',
      );

      return;
    }

    if (listening) {
      await stopListening();
    }

    await tts.stop();

    setState(() {
      loading = true;
      statusMessage =
          '🌐 Gemini से जवाब लिया जा रहा है...';
    });

    try {
      final result =
          await askGemini(question);

      if (!mounted) return;

      setState(() {
        answer = result;
        loading = false;
        statusMessage =
            '✅ जवाब मिल गया';
      });

      await speak(result);

      scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      final errorText =
          e.toString().replaceFirst(
                'Exception: ',
                '',
              );

      setState(() {
        answer =
            '❌ समस्या\n\n$errorText';
        loading = false;
        statusMessage =
            '⚠️ API request failed';
      });
    }
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void scrollToBottom() {
    Future.delayed(
      const Duration(milliseconds: 200),
      () {
        if (!scrollController.hasClients) return;

        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration:
              const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
    );
  }

  // ============================================================
  // CLEAR
  // ============================================================

  Future<void> clearAll() async {
    await tts.stop();

    setState(() {
      questionController.clear();
      selectedImage = null;

      answer =
          'नमस्ते! 🙏\nमैं आपका AI Personal Teacher हूँ।';

      statusMessage = '';
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    questionController.dispose();
    scrollController.dispose();
    speech.stop();
    tts.stop();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

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
        actions: [
          IconButton(
            tooltip: 'Clear',
            onPressed:
                loading ? null : clearAll,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [

            // --------------------------------------------------
            // ANSWER AREA
            // --------------------------------------------------

            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [

                    Card(
                      elevation: 3,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            Row(
                              children: const [
                                Icon(
                                  Icons.school,
                                  color:
                                      Colors.deepPurple,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Teacher का जवाब',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 15,
                            ),

                            SelectableText(
                              answer,
                              style:
                                  const TextStyle(
                                fontSize: 17,
                                height: 1.5,
                              ),
                            ),

                            if (loading) ...[
                              const SizedBox(
                                height: 20,
                              ),
                              const LinearProgressIndicator(),
                            ],

                            if (statusMessage
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 12,
                              ),
                              Text(
                                statusMessage,
                                style:
                                    TextStyle(
                                  fontSize: 13,
                                  color:
                                      Colors.grey[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ------------------------------------------------
                    // SELECTED IMAGE
                    // ------------------------------------------------

                    if (selectedImage != null)
                      Card(
                        margin:
                            const EdgeInsets.only(
                          top: 12,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(8),
                          child: Column(
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
                                  height: 220,
                                  width:
                                      double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),

                              TextButton.icon(
                                onPressed:
                                    loading
                                        ? null
                                        : removeImage,
                                icon:
                                    const Icon(
                                  Icons.delete,
                                ),
                                label:
                                    const Text(
                                  'Image हटाएँ',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // --------------------------------------------------
            // INPUT AREA
            // --------------------------------------------------

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Theme.of(context)
                        .colorScheme
                        .surface,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    color:
                        Colors.black12,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [

                  // ----------------------------------------------
                  // IMAGE BUTTON
                  // ----------------------------------------------

                  IconButton(
                    tooltip: 'Image',
                    onPressed:
                        loading
                            ? null
                            : pickImage,
                    icon: const Icon(
                      Icons.image,
                      size: 30,
                    ),
                  ),

                  // ----------------------------------------------
                  // TEXT FIELD
                  // ----------------------------------------------

                  Expanded(
                    child: TextField(
                      controller:
                          questionController,
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

                  // ----------------------------------------------
                  // MICROPHONE
                  // ----------------------------------------------

                  IconButton(
                    tooltip: listening
                        ? 'Stop'
                        : 'Voice',
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

                  // ----------------------------------------------
                  // SEND
                  // ----------------------------------------------

                  IconButton(
                    tooltip: 'Ask',
                    onPressed:
                        loading
                            ? null
                            : askTeacher,
                    icon: const Icon(
                      Icons.send,
                      size: 30,
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
