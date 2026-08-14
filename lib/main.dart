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
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F5FF),
      ),
      home: const TeacherHomePage(),
    );
  }
}

// ------------------------------------------------------------
// CHAT MESSAGE
// ------------------------------------------------------------

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

// ------------------------------------------------------------
// HOME PAGE
// ------------------------------------------------------------

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  // ----------------------------------------------------------
  // API
  // ----------------------------------------------------------

  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // Current recommended model.
  static const String primaryModel = 'gemini-3.5-flash';

  // Lower-cost fallback.
  static const String fallbackModel = 'gemini-3.1-flash-lite';

  // ----------------------------------------------------------
  // CONTROLLERS
  // ----------------------------------------------------------

  final TextEditingController questionController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final ImagePicker imagePicker = ImagePicker();

  final stt.SpeechToText speech = stt.SpeechToText();

  final FlutterTts tts = FlutterTts();

  // ----------------------------------------------------------
  // STATE
  // ----------------------------------------------------------

  final List<ChatMessage> messages = [];

  bool studyMode = false;
  bool listening = false;
  bool loading = false;
  bool speaking = false;

  bool speechAvailable = false;

  String selectedClass = 'कक्षा 5';
  String selectedSubject = 'गणित';

  XFile? selectedImage;

  // ----------------------------------------------------------
  // CLASS OPTIONS
  // ----------------------------------------------------------

  final List<String> classes = const [
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
  ];

  final List<String> subjects = const [
    'गणित',
    'विज्ञान',
    'अंग्रेजी',
    'हिंदी',
    'सामाजिक विज्ञान',
    'भौतिक विज्ञान',
    'रसायन विज्ञान',
    'जीव विज्ञान',
    'कंप्यूटर',
    'सामान्य ज्ञान',
  ];

  // ----------------------------------------------------------
  // INIT
  // ----------------------------------------------------------

  @override
  void initState() {
    super.initState();

    setupTts();
    setupSpeech();
  }

  Future<void> setupTts() async {
    try {
      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);

      tts.setStartHandler(() {
        if (!mounted) return;

        setState(() {
          speaking = true;
        });
      });

      tts.setCompletionHandler(() {
        if (!mounted) return;

        setState(() {
          speaking = false;
        });
      });

      tts.setCancelHandler(() {
        if (!mounted) return;

        setState(() {
          speaking = false;
        });
      });

      tts.setErrorHandler((message) {
        if (!mounted) return;

        setState(() {
          speaking = false;
        });
      });
    } catch (_) {}
  }

  Future<void> setupSpeech() async {
    try {
      speechAvailable = await speech.initialize(
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
          });
        },
      );
    } catch (_) {
      speechAvailable = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ----------------------------------------------------------
  // DISPOSE
  // ----------------------------------------------------------

  @override
  void dispose() {
    questionController.dispose();
    scrollController.dispose();
    speech.stop();
    tts.stop();

    super.dispose();
  }

  // ----------------------------------------------------------
  // VOICE INPUT
  // ----------------------------------------------------------

  Future<void> startListening() async {
    if (loading) return;

    if (!speechAvailable) {
      speechAvailable = await speech.initialize();

      if (!speechAvailable) {
        showMessage(
          '🎤 Microphone उपलब्ध नहीं है।\n\n'
          'फोन की Settings → App Permissions → Microphone को Allow करें।',
        );
        return;
      }
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

          final text = result.recognizedWords;

          if (text.isNotEmpty) {
            setState(() {
              questionController.text = text;

              questionController.selection =
                  TextSelection.fromPosition(
                TextPosition(
                  offset: questionController.text.length,
                ),
              );
            });
          }
        },
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        listening = false;
      });

      showMessage(
        '🎤 Voice input में समस्या हुई।\n'
        'Microphone permission check करें।',
      );
    }
  }

  // ----------------------------------------------------------
  // IMAGE PICKER
  // ----------------------------------------------------------

  Future<void> pickImage() async {
    if (loading) return;

    try {
      final XFile? image = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      showMessage(
        '📷 Camera नहीं खुल पाई।\n\n'
        'Settings → Apps → AI Personal Teacher → Permissions '
        'में Camera Allow करें।',
      );
    }
  }

  // ----------------------------------------------------------
  // GALLERY PICKER
  // ----------------------------------------------------------

  Future<void> pickFromGallery() async {
    if (loading) return;

    try {
      final XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        selectedImage = image;
      });
    } catch (_) {
      showMessage(
        '📷 Photo select नहीं हो पाई।',
      );
    }
  }

  // ----------------------------------------------------------
  // IMAGE MENU
  // ----------------------------------------------------------

  void showImageOptions() {
    if (loading) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'सवाल की फोटो',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    size: 30,
                  ),
                  title: const Text(
                    'Camera से फोटो लें',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    pickImage();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    size: 30,
                  ),
                  title: const Text(
                    'Gallery से फोटो चुनें',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    pickFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------
  // SEND QUESTION
  // ----------------------------------------------------------

  Future<void> askTeacher() async {
    if (loading) return;

    final question = questionController.text.trim();

    if (question.isEmpty && selectedImage == null) {
      showMessage(
        'पहले अपना सवाल लिखें, बोलें या फोटो भेजें।',
      );
      return;
    }

    if (apiKey.trim().isEmpty) {
      showMessage(
        'Gemini API Key उपलब्ध नहीं है।\n\n'
        'GitHub → Settings → Secrets and variables → Actions '
        'में GEMINI_API_KEY check करें।',
      );
      return;
    }

    // Stop voice if active.
    if (listening) {
      await speech.stop();

      if (mounted) {
        setState(() {
          listening = false;
        });
      }
    }

    final XFile? imageToSend = selectedImage;

    // Add user message immediately.
    setState(() {
      messages.add(
        ChatMessage(
          text: question.isEmpty
              ? '📷 फोटो में दिया गया सवाल'
              : question,
          isUser: true,
        ),
      );

      questionController.clear();
      selectedImage = null;
      loading = true;
    });

    await scrollToBottom();

    try {
      final answer = await askGemini(
        question: question.isEmpty
            ? 'इस फोटो में दिए गए सवाल को पढ़कर हल करो।'
            : question,
        image: imageToSend,
      );

      if (!mounted) return;

      setState(() {
        messages.add(
          ChatMessage(
            text: cleanAnswer(answer),
            isUser: false,
          ),
        );

        loading = false;
      });

      await scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add(
          ChatMessage(
            text: makeFriendlyError(e),
            isUser: false,
          ),
        );

        loading = false;
      });

      await scrollToBottom();
    }
  }

  // ----------------------------------------------------------
  // GEMINI API
  // ----------------------------------------------------------

  Future<String> askGemini({
    required String question,
    XFile? image,
  }) async {
    // Try primary model first.
    try {
      return await callGemini(
        model: primaryModel,
        question: question,
        image: image,
      );
    } catch (e) {
      final error = e.toString().toLowerCase();

      // If model not found / unavailable, try fallback.
      if (error.contains('404') ||
          error.contains('not_found') ||
          error.contains('not found') ||
          error.contains('unavailable')) {
        return await callGemini(
          model: fallbackModel,
          question: question,
          image: image,
        );
      }

      rethrow;
    }
  }

  // ----------------------------------------------------------
  // GEMINI REQUEST
  // ----------------------------------------------------------

  Future<String> callGemini({
    required String model,
    required String question,
    XFile? image,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$model:generateContent',
    );

    final List<Map<String, dynamic>> contents = [];

    // --------------------------------------------------------
    // Previous conversation
    // --------------------------------------------------------

    for (final message in messages) {
      if (message.isUser) {
        contents.add({
          'role': 'user',
          'parts': [
            {
              'text': message.text,
            }
          ],
        });
      } else {
        contents.add({
          'role': 'model',
          'parts': [
            {
              'text': message.text,
            }
          ],
        });
      }
    }

    // --------------------------------------------------------
    // Current user request
    // --------------------------------------------------------

    final List<Map<String, dynamic>> currentParts = [];

    if (image != null) {
      final bytes = await File(image.path).readAsBytes();

      final base64Image = base64Encode(bytes);

      String mimeType = 'image/jpeg';

      final path = image.path.toLowerCase();

      if (path.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (path.endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      currentParts.add({
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Image,
        },
      });
    }

    currentParts.add({
      'text': buildTeacherPrompt(question),
    });

    contents.add({
      'role': 'user',
      'parts': currentParts,
    });

    // --------------------------------------------------------
    // API BODY
    // --------------------------------------------------------

    final body = {
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': 2048,
      },
    };

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey.trim(),
          },
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 60),
        );

    debugPrint(
      'Gemini HTTP Status: ${response.statusCode}',
    );

    debugPrint(
      'Gemini Response: ${response.body}',
    );

    // --------------------------------------------------------
    // ERROR
    // --------------------------------------------------------

    if (response.statusCode != 200) {
      String message = 'Gemini API Error ${response.statusCode}';

      try {
        final errorData = jsonDecode(response.body);

        final apiError = errorData['error'];

        if (apiError is Map) {
          final apiMessage = apiError['message'];

          if (apiMessage != null) {
            message = apiMessage.toString();
          }
        }
      } catch (_) {}

      throw Exception(
        'Gemini API Error ${response.statusCode}: $message',
      );
    }

    // --------------------------------------------------------
    // RESPONSE
    // --------------------------------------------------------

    final Map<String, dynamic> data =
        jsonDecode(response.body);

    final candidates = data['candidates'];

    if (candidates == null ||
        candidates is! List ||
        candidates.isEmpty) {
      throw Exception(
        'Gemini ने कोई जवाब नहीं दिया।',
      );
    }

    final firstCandidate = candidates.first;

    if (firstCandidate is! Map) {
      throw Exception(
        'Gemini response format सही नहीं है।',
      );
    }

    final content = firstCandidate['content'];

    if (content is! Map) {
      throw Exception(
        'Gemini response खाली है।',
      );
    }

    final responseParts = content['parts'];

    if (responseParts == null ||
        responseParts is! List ||
        responseParts.isEmpty) {
      throw Exception(
        'Gemini response में text नहीं मिला।',
      );
    }

    final StringBuffer buffer = StringBuffer();

    for (final part in responseParts) {
      if (part is Map) {
        final text = part['text'];

        if (text != null) {
          buffer.write(text.toString());
        }
      }
    }

    final result = buffer.toString().trim();

    if (result.isEmpty) {
      throw Exception(
        'AI ने खाली जवाब दिया।',
      );
    }

    return result;
  }

  // ----------------------------------------------------------
  // TEACHER PROMPT
  // ----------------------------------------------------------

  String buildTeacherPrompt(String question) {
    final modeInstruction = studyMode
        ? '''
STUDY MODE ON है।

Student को सिर्फ answer मत दो।
Teacher की तरह पढ़ाओ।

पहले concept समझाओ।
फिर आसान example दो।
फिर जरूरत हो तो step-by-step solution दो।
अंत में एक छोटा practice question दो।

Student की class और subject को ध्यान में रखो।
'''
        : '''
Normal chat mode में जवाब दो।

Student के सवाल का सीधा और आसान जवाब दो।
अगर सवाल पढ़ाई से जुड़ा है तो teacher की तरह समझाओ।
जरूरत होने पर example दो।
''';

    return '''
आप "AI Personal Teacher" हैं।

आपका काम एक friendly Indian school teacher की तरह student को पढ़ाना है।

Student की जानकारी:

कक्षा: $selectedClass
विषय: $selectedSubject

$modeInstruction

महत्वपूर्ण नियम:

1. जवाब मुख्य रूप से सरल हिंदी में दो।
2. अगर student English में सवाल पूछता है तो जरूरत के अनुसार English में भी समझा सकते हो।
3. बहुत कठिन भाषा का इस्तेमाल मत करो।
4. Student की class से ऊपर का अनावश्यक कठिन concept मत लाओ।
5. Maths में calculation बिल्कुल सही करो।
6. Maths में step-by-step समझाओ।
7. Science में पहले concept, फिर example समझाओ।
8. English सीखने वाले student को pronunciation और simple meaning भी समझा सकते हो।
9. अगर photo भेजी गई है तो photo को ध्यान से पढ़कर सवाल हल करो।
10. अगर photo में सवाल साफ नहीं है तो student को बताओ कि कौन सा हिस्सा साफ नहीं है।
11. गलत answer मिलने पर politely correction करो।
12. केवल answer देकर छोड़ना नहीं है जब explanation जरूरी हो।
13. जवाब में markdown के double asterisk ** का इस्तेमाल मत करो।
14. अनावश्यक बहुत लंबे paragraphs मत बनाओ।
15. छोटे headings और numbered steps इस्तेमाल कर सकते हो।
16. Student को confuse करने वाली technical language से बचो।
17. अंत में जरूरत हो तो "अब तुम यह सवाल हल करो:" देकर छोटा practice question दो।
18. यदि student सामान्य बातचीत करे तो सामान्य friendly जवाब दो।
19. किसी भी सवाल का जवाब ईमानदारी से दो। जानकारी न हो तो ऐसा बताओ।
20. Student को डांटना या शर्मिंदा नहीं करना है।

Student का सवाल:

$question
''';
  }

  // ----------------------------------------------------------
  // CLEAN ANSWER
  // ----------------------------------------------------------

  String cleanAnswer(String text) {
    String result = text;

    // Remove markdown bold markers.
    result = result.replaceAll('**', '');

    // Remove markdown heading markers.
    result = result.replaceAll(
      RegExp(r'^#{1,6}\s*', multiLine: true),
      '',
    );

    // Remove unwanted markdown bullets.
    result = result.replaceAll(
      RegExp(r'^\*\s+', multiLine: true),
      '• ',
    );

    return result.trim();
  }

  // ----------------------------------------------------------
  // FRIENDLY ERROR
  // ----------------------------------------------------------

  String makeFriendlyError(Object error) {
    final message = error.toString();

    final lower = message.toLowerCase();

    if (lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('api key') ||
        lower.contains('permission')) {
      return '''
❌ Gemini API Key में समस्या है।

GitHub में check करें:

Settings
→ Secrets and variables
→ Actions
→ GEMINI_API_KEY

API key सही Secret में होनी चाहिए।
''';
    }

    if (lower.contains('429') ||
        lower.contains('quota') ||
        lower.contains('too many')) {
      return '''
⏳ अभी Gemini API पर ज्यादा requests हैं या quota पूरा हो गया है।

कुछ समय बाद फिर कोशिश करें।
''';
    }

    if (lower.contains('404') ||
        lower.contains('not_found') ||
        lower.contains('not found')) {
      return '''
❌ Gemini model उपलब्ध नहीं मिला।

App ने दूसरा available model भी try किया, लेकिन request सफल नहीं हुई।

Internet और Gemini API key check करें।
''';
    }

    if (lower.contains('timeout') ||
        lower.contains('timed out')) {
      return '''
🌐 Internet connection बहुत slow है।

Internet check करके फिर सवाल भेजें।
''';
    }

    if (lower.contains('socket') ||
        lower.contains('connection')) {
      return '''
🌐 Internet connection में समस्या है।

Mobile data/Wi-Fi check करके फिर कोशिश करें।
''';
    }

    return '''
❌ अभी जवाब नहीं मिल पाया।

Internet connection और Gemini API key check करें।
फिर दोबारा कोशिश करें।
''';
  }

  // ----------------------------------------------------------
  // TEXT TO SPEECH
  // ----------------------------------------------------------

  Future<void> speak(String text) async {
    try {
      if (speaking) {
        await tts.stop();

        if (mounted) {
          setState(() {
            speaking = false;
          });
        }

        return;
      }

      String speechText = text;

      // Remove emojis and excessive formatting for TTS.
      speechText = speechText.replaceAll(
        RegExp(r'[^\u0000-\uFFFF]'),
        ' ',
      );

      await tts.setLanguage(
        detectSpeechLanguage(speechText),
      );

      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);

      await tts.speak(speechText);
    } catch (_) {
      if (mounted) {
        setState(() {
          speaking = false;
        });
      }
    }
  }

  String detectSpeechLanguage(String text) {
    final hasHindi = RegExp(
      r'[\u0900-\u097F]',
    ).hasMatch(text);

    if (hasHindi) {
      return 'hi-IN';
    }

    return 'en-IN';
  }

  // ----------------------------------------------------------
  // SCROLL
  // ----------------------------------------------------------

  Future<void> scrollToBottom() async {
    await Future.delayed(
      const Duration(milliseconds: 100),
    );

    if (!scrollController.hasClients) return;

    await scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ----------------------------------------------------------
  // CLEAR CHAT
  // ----------------------------------------------------------

  void clearChat() {
    if (loading) return;

    if (messages.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Chat साफ करें?',
          ),
          content: const Text(
            'सभी सवाल और जवाब हट जाएंगे।',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'नहीं',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);

                setState(() {
                  messages.clear();
                });
              },
              child: const Text(
                'साफ करें',
              ),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------
  // MESSAGE
  // ----------------------------------------------------------

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9F5FF),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: Color(0xFFE7D9FF),
              child: Icon(
                Icons.school,
                color: Colors.deepPurple,
                size: 26,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Personal Teacher',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'आपका digital teacher',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New Chat',
            onPressed: loading ? null : clearChat,
            icon: const Icon(
              Icons.add_comment_outlined,
              size: 29,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                clearChat();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 10),
                      Text('Chat साफ करें'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // --------------------------------------------------
          // STUDY SETTINGS
          // --------------------------------------------------

          buildStudyPanel(),

          // --------------------------------------------------
          // CHAT
          // --------------------------------------------------

          Expanded(
            child: messages.isEmpty
                ? buildWelcome()
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      16,
                    ),
                    itemCount:
                        messages.length + (loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= messages.length) {
                        return buildLoadingBubble();
                      }

                      return buildMessageBubble(
                        messages[index],
                      );
                    },
                  ),
          ),

          // --------------------------------------------------
          // INPUT
          // --------------------------------------------------

          buildInputArea(),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // STUDY PANEL
  // ----------------------------------------------------------

  Widget buildStudyPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E6FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.deepPurple,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Study Mode',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: studyMode,
                activeColor: Colors.deepPurple,
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

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: buildDropdown(
                  label: 'कक्षा',
                  value: selectedClass,
                  items: classes,
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
              const SizedBox(width: 12),
              Expanded(
                child: buildDropdown(
                  label: 'विषय',
                  value: selectedSubject,
                  items: subjects,
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
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // DROPDOWN
  // ----------------------------------------------------------

  Widget buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // ----------------------------------------------------------
  // WELCOME
  // ----------------------------------------------------------

  Widget buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE7D9FF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.school,
                color: Colors.deepPurple,
                size: 58,
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'नमस्ते! 👋',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'मैं आपका AI Personal Teacher हूँ।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              studyMode
                  ? '$selectedClass • $selectedSubject\n'
                    'Study Mode चालू है।'
                  : 'अपना सवाल लिखें, बोलें या फोटो भेजें।',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 26),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                buildSuggestion(
                  '12 + 26 = ?',
                ),
                buildSuggestion(
                  'भारत की राजधानी क्या है?',
                ),
                buildSuggestion(
                  'English बोलना सीखना है',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSuggestion(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: loading
          ? null
          : () {
              questionController.text = text;

              questionController.selection =
                  TextSelection.fromPosition(
                TextPosition(
                  offset: questionController.text.length,
                ),
              );
            },
    );
  }

  // ----------------------------------------------------------
  // MESSAGE BUBBLE
  // ----------------------------------------------------------

  Widget buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.88,
        ),
        margin: EdgeInsets.only(
          top: 6,
          bottom: 6,
          left: isUser ? 55 : 0,
          right: isUser ? 0 : 35,
        ),
        padding: const EdgeInsets.fromLTRB(
          16,
          14,
          14,
          12,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFFE5D4FF)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(
              isUser ? 22 : 6,
            ),
            bottomRight: Radius.circular(
              isUser ? 6 : 22,
            ),
          ),
          border: Border.all(
            color: isUser
                ? const Color(0xFFD7BFFF)
                : const Color(0xFFEAEAEA),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: isUser
                      ? Colors.deepPurple
                      : const Color(0xFFE7D9FF),
                  child: Icon(
                    isUser
                        ? Icons.person
                        : Icons.school,
                    size: 20,
                    color: isUser
                        ? Colors.white
                        : Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  isUser ? 'आप' : 'Teacher',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            SelectableText(
              message.text,
              style: const TextStyle(
                fontSize: 17,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),

            if (!isUser)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'सुनें',
                  onPressed: () {
                    speak(message.text);
                  },
                  icon: Icon(
                    speaking
                        ? Icons.stop_circle_outlined
                        : Icons.volume_up,
                    color: Colors.deepPurple,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // LOADING BUBBLE
  // ----------------------------------------------------------

  Widget buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          left: 0,
          right: 60,
          top: 8,
          bottom: 8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFEAEAEA),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFE7D9FF),
              child: Icon(
                Icons.school,
                color: Colors.deepPurple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              studyMode
                  ? 'Teacher समझा रहा है...'
                  : 'Teacher जवाब दे रहा है...',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // INPUT AREA
  // ----------------------------------------------------------

  Widget buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          10,
          8,
          10,
          8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, -2),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedImage != null)
              buildSelectedImage(),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                // Camera / gallery
                IconButton(
                  tooltip: 'Photo',
                  onPressed:
                      loading ? null : showImageOptions,
                  icon: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 30,
                  ),
                ),

                // Text field
                Expanded(
                  child: TextField(
                    controller: questionController,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction:
                        TextInputAction.newline,
                    enabled: !loading,
                    decoration: InputDecoration(
                      hintText: listening
                          ? '🎤 सुन रहा हूँ...'
                          : 'अपना सवाल लिखें...',
                      filled: true,
                      fillColor:
                          const Color(0xFFF7F1FF),
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!loading) {
                        askTeacher();
                      }
                    },
                  ),
                ),

                // Mic
                IconButton(
                  tooltip: 'Voice',
                  onPressed:
                      loading ? null : startListening,
                  icon: Icon(
                    listening
                        ? Icons.mic
                        : Icons.mic_none,
                    size: 31,
                    color: listening
                        ? Colors.red
                        : Colors.deepPurple,
                  ),
                ),

                // Send
                IconButton(
                  tooltip: 'Send',
                  onPressed:
                      loading ? null : askTeacher,
                  icon: Icon(
                    Icons.send,
                    size: 34,
                    color: loading
                        ? Colors.grey
                        : Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // SELECTED IMAGE PREVIEW
  // ----------------------------------------------------------

  Widget buildSelectedImage() {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: 8,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(14),
            child: Image.file(
              File(selectedImage!.path),
              width: 90,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              'यह फोटो सवाल के साथ भेजी जाएगी।',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          IconButton(
            onPressed: loading
                ? null
                : () {
                    setState(() {
                      selectedImage = null;
                    });
                  },
            icon: const Icon(
              Icons.close,
            ),
          ),
        ],
      ),
    );
  }
}
