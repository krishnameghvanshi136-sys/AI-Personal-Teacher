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
  final TextEditingController questionController =
      TextEditingController();

  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  final ImagePicker imagePicker = ImagePicker();

  bool listening = false;
  bool loading = false;
  bool studyMode = true;
  bool speechAvailable = false;

  XFile? selectedImage;

  String selectedClass = 'सभी कक्षा';
  String selectedSubject = 'सामान्य';

  String answer =
      'नमस्ते! मैं आपका AI Personal Teacher हूँ।\n\n'
      '📚 Study Mode चालू है।\n'
      'आप सवाल लिखें, बोलें या फोटो भेजें।';

  static const String apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  // Stable Gemini model
  static const String model = 'gemini-2.5-flash-lite';

  @override
  void initState() {
    super.initState();
    setupSpeech();
    setupTts();
  }

  Future<void> setupSpeech() async {
    try {
      speechAvailable = await speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'notListening') {
            setState(() {
              listening = false;
            });
          }
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            listening = false;
          });
        },
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      speechAvailable = false;
    }
  }

  Future<void> setupTts() async {
    try {
      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    try {
      await tts.stop();

      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);

      await tts.speak(cleanText(text));
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  String cleanText(String text) {
    String result = text;

    // Markdown हटाएँ
    result = result.replaceAll('**', '');
    result = result.replaceAll('__', '');
    result = result.replaceAll('###', '');
    result = result.replaceAll('##', '');
    result = result.replaceAll('#', '');

    // Markdown bullets को साफ करें
    result = result.replaceAll(RegExp(r'^\s*[-*]\s*',
        multiLine: true), '• ');

    return result.trim();
  }

  Future<void> startListening() async {
    if (loading) return;

    if (!speechAvailable) {
      await setupSpeech();
    }

    if (!speechAvailable) {
      setState(() {
        answer =
            '🎤 Microphone उपलब्ध नहीं है।\n\n'
            'फोन की Settings → Apps → AI Personal Teacher → '
            'Permissions → Microphone को Allow करें।';
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
        partialResults: true,
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
      if (mounted) {
        setState(() {
          listening = false;
          answer =
              '🎤 Voice input में समस्या हुई।';
        });
      }
    }
  }

  Future<void> pickGalleryImage() async {
    if (loading) return;

    try {
      final XFile? image =
          await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;
        answer =
            '🖼️ फोटो चुन ली गई है।\n\n'
            'अब फोटो के बारे में सवाल लिखें या बोलें।';
      });
    } catch (e) {
      setState(() {
        answer = 'फोटो चुनने में समस्या हुई।';
      });
    }
  }

  Future<void> takePhoto() async {
    if (loading) return;

    try {
      final XFile? image =
          await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;
        answer =
            '📷 फोटो ले ली गई है।\n\n'
            'अब सवाल पूछें।';
      });
    } catch (e) {
      setState(() {
        answer =
            '📷 Camera खोलने में समस्या हुई।';
      });
    }
  }

  void showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: Colors.deepPurple,
                ),
                title: const Text('Camera से फोटो लें'),
                onTap: () {
                  Navigator.pop(context);
                  takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.deepPurple,
                ),
                title: const Text('Gallery से फोटो चुनें'),
                onTap: () {
                  Navigator.pop(context);
                  pickGalleryImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> askTeacher() async {
    if (loading) return;

    final question =
        questionController.text.trim();

    if (question.isEmpty &&
        selectedImage == null) {
      setState(() {
        answer =
            '✏️ कृपया पहले सवाल लिखें, बोलें या फोटो भेजें।';
      });
      return;
    }

    if (apiKey.trim().isEmpty) {
      setState(() {
        answer =
            '❌ Gemini API Key नहीं मिली।\n\n'
            'GitHub Actions में GEMINI_API_KEY Secret check करें।';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      loading = true;
      answer = '⏳ Teacher जवाब तैयार कर रहा है...';
    });

    try {
      final result = await askGemini(question);

      if (!mounted) return;

      final cleaned = cleanText(result);

      setState(() {
        answer = cleaned;
        loading = false;
      });

      await speak(cleaned);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        answer = '❌ समस्या\n\n${e.toString()}';
      });
    }
  }

  Future<String> askGemini(String question) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/'
      'models/$model:generateContent',
    );

    final List<Map<String, dynamic>> parts = [];

    if (selectedImage != null) {
      final bytes =
          await File(selectedImage!.path).readAsBytes();

      final base64Image =
          base64Encode(bytes);

      String mimeType = 'image/jpeg';

      final extension = selectedImage!
          .path
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

    final studyInstruction = studyMode
        ? '''
STUDY MODE ON है।

आप एक अच्छे school teacher की तरह पढ़ाएँ।

सिर्फ final answer न दें।

विद्यार्थी को:
1. सवाल समझाएँ
2. जरूरी concept समझाएँ
3. Step-by-step solution दें
4. जहाँ जरूरी हो example दें
5. अंत में छोटा final answer दें

गणित में calculation step-by-step दिखाएँ।

बहुत कठिन भाषा का इस्तेमाल न करें।
'''
        : '''
STUDY MODE OFF है।

सवाल का सीधा, सही और छोटा जवाब दें।
जरूरत होने पर थोड़ी explanation दें।
''';

    final prompt = '''
आप AI Personal Teacher हैं।

भाषा: आसान हिंदी।

कक्षा: $selectedClass
विषय: $selectedSubject

$studyInstruction

महत्वपूर्ण:
- Markdown bold के लिए ** का इस्तेमाल न करें।
- जवाब में **, __, ### जैसे Markdown symbols न लिखें।
- साफ और पढ़ने में आसान जवाब दें।
- विद्यार्थी से सम्मानपूर्वक बात करें।
- अगर फोटो में सवाल है तो उसे ध्यान से पढ़ें।
- अगर सवाल अस्पष्ट है तो पहले बताएं कि क्या समझ नहीं आया।

Student का सवाल:
$question
''';

    parts.add({
      'text': prompt,
    });

    final response = await http
        .post(
          uri,
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
        )
        .timeout(
          const Duration(seconds: 45),
        );

    debugPrint(
      'Gemini Status: ${response.statusCode}',
    );

    if (response.statusCode != 200) {
      String errorMessage =
          'Gemini API Error ${response.statusCode}';

      try {
        final errorData =
            jsonDecode(response.body);

        final apiError =
            errorData['error']?['message'];

        if (apiError != null) {
          errorMessage = apiError.toString();
        }
      } catch (_) {}

      throw Exception(errorMessage);
    }

    final data =
        jsonDecode(response.body);

    final candidates =
        data['candidates'];

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

    final result =
        buffer.toString().trim();

    if (result.isEmpty) {
      throw Exception(
        'Gemini ने खाली जवाब दिया।',
      );
    }

    return result;
  }

  void resetTeacher() {
    tts.stop();

    setState(() {
      questionController.clear();
      selectedImage = null;
      answer =
          'नमस्ते! मैं आपका AI Personal Teacher हूँ।\n\n'
          '📚 Study Mode चालू है।';
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
        actions: [
          IconButton(
            onPressed:
                loading ? null : resetTeacher,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // STUDY MODE BAR
            Container(
              margin: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                4,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.school,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Study Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Switch(
                    value: studyMode,
                    onChanged: loading
                        ? null
                        : (value) {
                            setState(() {
                              studyMode = value;
                            });
                          },
                  ),
                ],
              ),
            ),

            // CLASS + SUBJECT
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedClass,
                      decoration:
                          const InputDecoration(
                        labelText: 'कक्षा',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        'सभी कक्षा',
                        'कक्षा 1',
                        'कक्षा 2',
                        'कक्षा 3',
                        'कक्षा 4',
                        'कक्षा 5',
                        'कक्षा 6',
                        'कक्षा 7',
                        'कक्षा 8',
                        'कक्षा 9',
                        'कक्षा 10',
                        'कक्षा 11',
                        'कक्षा 12',
                      ].map((item) {
                        return DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        );
                      }).toList(),
                      onChanged: loading
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                selectedClass = value;
                              });
                            },
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedSubject,
                      decoration:
                          const InputDecoration(
                        labelText: 'विषय',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        'सामान्य',
                        'गणित',
                        'विज्ञान',
                        'हिंदी',
                        'अंग्रेजी',
                        'सामाजिक विज्ञान',
                        'इतिहास',
                        'भूगोल',
                        'कंप्यूटर',
                      ].map((item) {
                        return DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        );
                      }).toList(),
                      onChanged: loading
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                selectedSubject = value;
                              });
                            },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ANSWER
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.all(12),
                child: Card(
                  elevation: 3,
                  child: Padding(
                    padding:
                        const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.school,
                              size: 30,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Teacher का जवाब',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (selectedImage != null)
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(12),
                            child: Image.file(
                              File(
                                selectedImage!.path,
                              ),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),

                        if (selectedImage != null)
                          const SizedBox(height: 12),

                        if (loading)
                          const Padding(
                            padding:
                                EdgeInsets.only(
                              bottom: 12,
                            ),
                            child:
                                LinearProgressIndicator(),
                          ),

                        SelectableText(
                          answer,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // INPUT AREA
            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                8,
                6,
                8,
                8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .scaffoldBackgroundColor,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black12,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed:
                        loading
                            ? null
                            : showImageOptions,
                    icon: const Icon(
                      Icons.image,
                      size: 30,
                    ),
                    tooltip: 'Photo',
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
                              BorderRadius.circular(
                            25,
                          ),
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
                      color: Colors.deepPurple,
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
