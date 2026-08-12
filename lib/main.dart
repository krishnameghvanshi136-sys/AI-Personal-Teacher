import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

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
  bool loading = false;

  XFile? selectedImage;

  String answer =
      'नमस्ते! मैं आपका AI Personal Teacher हूँ।\n\n'
      'आप मुझसे पढ़ाई, गणित, विज्ञान, सामान्य ज्ञान और किसी भी विषय '
      'से जुड़ा सवाल पूछ सकते हैं।';

  // API key GitHub में secret से build होगी.
  static const String apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  // Primary model.
  static const String primaryModel = 'gemini-3.6-flash';

  // Backup model.
  static const String backupModel = 'gemini-2.5-flash';

  @override
  void initState() {
    super.initState();

    tts.setLanguage('hi-IN');
    tts.setSpeechRate(0.45);
    tts.setPitch(1.0);
  }

  @override
  void dispose() {
    questionController.dispose();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  // ----------------------------------------------------------
  // GALLERY
  // ----------------------------------------------------------

  Future<void> pickPhoto() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;
        answer =
            '📷 फोटो मिल गई।\n\n'
            'अब अपना सवाल लिखें या microphone से बोलें।';
      });

      await tts.speak(
        'फोटो मिल गई। अब अपना सवाल पूछिए।',
      );
    } catch (e) {
      setState(() {
        answer = 'फोटो खोलने में समस्या हुई।';
      });
    }
  }

  // ----------------------------------------------------------
  // CAMERA
  // ----------------------------------------------------------

  Future<void> takePhoto() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;
        answer =
            '📷 फोटो तैयार है।\n\n'
            'अब बताइए इस फोटो के बारे में क्या जानना है?';
      });

      await tts.speak(
        'फोटो तैयार है। अब अपना सवाल पूछिए।',
      );
    } catch (e) {
      setState(() {
        answer = 'कैमरा खोलने में समस्या हुई।';
      });
    }
  }

  // ----------------------------------------------------------
  // SPEECH TO TEXT
  // ----------------------------------------------------------

  Future<void> startListening() async {
    if (loading) return;

    if (listening) {
      await speech.stop();

      setState(() {
        listening = false;
      });

      return;
    }

    try {
      final available = await speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                listening = false;
              });
            }
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              listening = false;
            });
          }
        },
      );

      if (!available) {
        setState(() {
          answer =
              '🎤 Microphone उपलब्ध नहीं है।\n\n'
              'कृपया microphone permission दें।';
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

  // ----------------------------------------------------------
  // GEMINI AI
  // ----------------------------------------------------------

  Future<String?> askGemini({
    required String question,
    XFile? image,
    required String model,
  }) async {
    if (apiKey.isEmpty) {
      return 'ERROR_API_KEY';
    }

    final List<Map<String, dynamic>> parts = [];

    String teacherInstruction;

    if (teacherMode) {
      teacherInstruction = '''
आप एक बहुत अच्छे भारतीय AI Personal Teacher हैं।

हमेशा:
- हिंदी या Hinglish में आसान भाषा में जवाब दें।
- बच्चे को समझाने जैसा स्पष्ट जवाब दें।
- केवल final answer नहीं, जरूरत पड़ने पर step-by-step समझाएं।
- गणित में calculation साफ दिखाएं।
- विज्ञान में concept आसान उदाहरण से समझाएं।
- अगर सवाल गलत समझ आया हो तो clarification मांगें।
- फोटो में सवाल है तो फोटो देखकर सवाल हल करें।
- अनावश्यक लंबा जवाब न दें।
- महत्वपूर्ण formulas को साफ लिखें।
''';
    } else {
      teacherInstruction = '''
आप Study Mode में AI Teacher हैं।

सवाल को:
1. Concept
2. Given information
3. Step-by-step solution
4. Final answer

के तरीके से समझाएं।

जवाब हिंदी/Hinglish में आसान भाषा में दें।
''';
    }

    String prompt;

    if (question.isEmpty && image != null) {
      prompt = '''
$teacherInstruction

इस फोटो को ध्यान से देखकर बताइए कि इसमें क्या है।
अगर यह पढ़ाई का सवाल है तो उसे हल करके समझाइए।
''';
    } else {
      prompt = '''
$teacherInstruction

विद्यार्थी का सवाल:
$question

अब शिक्षक की तरह जवाब दें।
''';
    }

    parts.add({
      'text': prompt,
    });

    // IMAGE AI को भेजना
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      String mimeType = 'image/jpeg';

      final lower = image.path.toLowerCase();

      if (lower.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lower.endsWith('.webp')) {
        mimeType = 'image/webp';
      } else if (lower.endsWith('.heic')) {
        mimeType = 'image/heic';
      }

      parts.add({
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Image,
        },
      });
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$model:generateContent',
    );

    try {
      final response = await http.post(
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
            'maxOutputTokens': 1200,
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Gemini error ${response.statusCode}: ${response.body}',
        );

        return 'ERROR_${response.statusCode}';
      }

      final data = jsonDecode(response.body);

      final candidates = data['candidates'];

      if (candidates == null || candidates.isEmpty) {
        return 'AI ने कोई जवाब नहीं दिया।';
      }

      final content = candidates[0]['content'];

      if (content == null) {
        return 'AI का जवाब प्राप्त नहीं हुआ।';
      }

      final responseParts = content['parts'];

      if (responseParts == null || responseParts.isEmpty) {
        return 'AI का जवाब खाली है।';
      }

      final buffer = StringBuffer();

      for (final part in responseParts) {
        if (part['text'] != null) {
          buffer.write(part['text']);
        }
      }

      final result = buffer.toString().trim();

      if (result.isEmpty) {
        return 'AI ने कोई text जवाब नहीं दिया।';
      }

      return result;
    } catch (e) {
      debugPrint('Gemini exception: $e');
      return 'ERROR_NETWORK';
    }
  }

  // ----------------------------------------------------------
  // ASK TEACHER
  // ----------------------------------------------------------

  Future<void> askTeacher() async {
    if (loading) return;

    final question = questionController.text.trim();

    if (question.isEmpty && selectedImage == null) {
      setState(() {
        answer =
            '✍️ पहले अपना सवाल लिखें, बोलें या फोटो लगाएं।';
      });
      return;
    }

    // Keyboard हटाएं
    FocusScope.of(context).unfocus();

    if (listening) {
      await speech.stop();

      setState(() {
        listening = false;
      });
    }

    if (apiKey.isEmpty) {
      setState(() {
        answer =
            '⚠️ Gemini API Key सेट नहीं है.\n\n'
            'GitHub Actions में GEMINI_API_KEY secret जोड़ना जरूरी है।';
      });

      return;
    }

    setState(() {
      loading = true;
      answer = '🤖 AI Teacher सोच रहा है...\n\nकृपया थोड़ा इंतजार करें।';
    });

    try {
      String? response = await askGemini(
        question: question,
        image: selectedImage,
        model: primaryModel,
      );

      // Primary model fail हो तो backup model try करें।
      if (response != null &&
          (response.startsWith('ERROR_'))) {
        response = await askGemini(
          question: question,
          image: selectedImage,
          model: backupModel,
        );
      }

      if (!mounted) return;

      String finalAnswer;

      if (response == null) {
        finalAnswer = 'AI से जवाब नहीं मिला।';
      } else if (response == 'ERROR_API_KEY') {
        finalAnswer =
            '⚠️ Gemini API Key नहीं मिली।\n\n'
            'GitHub Actions secret GEMINI_API_KEY चेक करें।';
      } else if (response == 'ERROR_NETWORK') {
        finalAnswer =
            '🌐 Internet या Gemini server से connection नहीं हो पाया।';
      } else if (response.startsWith('ERROR_')) {
        finalAnswer =
            '⚠️ Gemini API में समस्या है।\n\n'
            'Error: $response';
      } else {
        finalAnswer = response;
      }

      setState(() {
        answer = finalAnswer;
        loading = false;
      });

      // AI answer को बोलना
      if (!finalAnswer.startsWith('⚠️') &&
          !finalAnswer.startsWith('🌐')) {
        await tts.stop();
        await tts.speak(finalAnswer);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        answer =
            '⚠️ AI से जवाब लेने में समस्या हुई।\n\n$e';
      });
    }
  }

  // ----------------------------------------------------------
  // CLEAR PHOTO
  // ----------------------------------------------------------

  void clearPhoto() {
    setState(() {
      selectedImage = null;
    });
  }

  // ----------------------------------------------------------
  // MODE
  // ----------------------------------------------------------

  void changeMode(bool teacher) {
    setState(() {
      teacherMode = teacher;
    });
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

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
            const SizedBox(height: 8),

            // MODE BUTTONS
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text(
                        '🤖 AI Teacher',
                      ),
                      selected: teacherMode,
                      onSelected: loading
                          ? null
                          : (_) => changeMode(true),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: ChoiceChip(
                      label: const Text(
                        '📚 Study Mode',
                      ),
                      selected: !teacherMode,
                      onSelected: loading
                          ? null
                          : (_) => changeMode(false),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ANSWER
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (selectedImage != null)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Image.file(
                            File(selectedImage!.path),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),

                          ListTile(
                            leading: const Icon(
                              Icons.image,
                            ),
                            title: Text(
                              selectedImage!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              onPressed:
                                  loading ? null : clearPhoto,
                              icon: const Icon(
                                Icons.close,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          if (loading)
                            const Padding(
                              padding:
                                  EdgeInsets.only(bottom: 12),
                              child:
                                  LinearProgressIndicator(),
                            ),

                          Text(
                            teacherMode
                                ? '👨‍🏫 AI Teacher'
                                : '📚 Study Mode',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            answer,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // INPUT BAR
            Container(
              padding: const EdgeInsets.fromLTRB(
                8,
                5,
                8,
                8,
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
                      size: 29,
                    ),
                  ),

                  IconButton(
                    tooltip: 'Camera',
                    onPressed:
                        loading ? null : takePhoto,
                    icon: const Icon(
                      Icons.camera_alt,
                      size: 29,
                    ),
                  ),

                  Expanded(
                    child: TextField(
                      controller: questionController,
                      enabled: !loading,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction:
                          TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: listening
                            ? '🎤 सुन रहा हूँ...'
                            : 'अपना सवाल लिखें...',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Voice',
                    onPressed:
                        loading ? null : startListening,
                    icon: Icon(
                      listening
                          ? Icons.mic
                          : Icons.mic_none,
                      size: 32,
                      color:
                          listening ? Colors.red : null,
                    ),
                  ),

                  IconButton(
                    tooltip: 'Ask AI',
                    onPressed:
                        loading ? null : askTeacher,
                    icon: loading
                        ? const SizedBox(
                            width: 27,
                            height: 27,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(
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
