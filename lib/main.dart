import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const String geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);

const String geminiModel = 'gemini-3.6-flash';

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
          seedColor: const Color(0xFF673AB7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F6FF),
      ),
      home: const TeacherHomePage(),
    );
  }
}

class ChatMessage {
  final bool isUser;
  final String text;
  final String? imagePath;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.imagePath,
  });
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _topicController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final ImagePicker _imagePicker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  final List<ChatMessage> _messages = [];

  bool studyMode = false;
  bool loading = false;
  bool listening = false;

  String selectedClass = 'कक्षा 5';
  String selectedSubject = 'गणित';

  XFile? selectedImage;

  final List<String> classes = [
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

  final List<String> subjects = [
    'गणित',
    'हिंदी',
    'अंग्रेजी',
    'विज्ञान',
    'सामाजिक विज्ञान',
    'इतिहास',
    'भूगोल',
    'कंप्यूटर',
    'सामान्य ज्ञान',
  ];

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _topicController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final ImagePicker _imagePicker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  final List<ChatMessage> _messages = [];

  bool studyMode = false;
  bool loading = false;
  bool listening = false;

  String selectedClass = 'कक्षा 5';
  String selectedSubject = 'गणित';

  XFile? selectedImage;

  final List<String> classes = [
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

  final List<String> subjects = [
    'गणित',
    'हिंदी',
    'अंग्रेजी',
    'विज्ञान',
    'सामाजिक विज्ञान',
    'इतिहास',
    'भूगोल',
    'कंप्यूटर',
    'सामान्य ज्ञान',
  ];

  @override
  void initState() {
    super.initState();

    _tts.setLanguage('hi-IN');
    _tts.setSpeechRate(0.48);
    _tts.setPitch(1.0);

    _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() {
              listening = false;
            });
          }
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            listening = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _topicController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  // ============================================================
  // CLASS-WISE TEACHING PROFILE
  // ============================================================

  String _classTeachingProfile() {
    switch (selectedClass) {
      case 'कक्षा 1':
      case 'कक्षा 2':
      case 'कक्षा 3':
        return '''
यह छोटा बच्चा है।
बहुत आसान भाषा इस्तेमाल करो।
छोटे वाक्यों में समझाओ।
गिनती, उदाहरण, कहानी और रोजमर्रा की चीजों का इस्तेमाल करो।
एक बार में बहुत ज्यादा जानकारी मत दो।
''';

      case 'कक्षा 4':
      case 'कक्षा 5':
        return '''
यह प्राथमिक स्तर का विद्यार्थी है।
आसान हिंदी/अंग्रेजी में concept समझाओ।
Step-by-step उदाहरण दो।
जरूरत पड़ने पर छोटी table या list का इस्तेमाल करो।
उत्तर के अंत में छोटा practice question दे सकते हो।
''';

      case 'कक्षा 6':
      case 'कक्षा 7':
      case 'कक्षा 8':
        return '''
यह middle-school विद्यार्थी है।
पहले concept समझाओ।
फिर example दो।
जरूरत होने पर formula, definition और step-by-step solution दो।
विद्यार्थी को reasoning समझाओ।
''';

      case 'कक्षा 9':
      case 'कक्षा 10':
        return '''
यह secondary-school विद्यार्थी है।
Concept को स्पष्ट और exam-oriented तरीके से समझाओ।
महत्वपूर्ण formula, definition और points बताओ।
गणित और विज्ञान में पूरा calculation/solution दिखाओ।
जहां उपयोगी हो वहां परीक्षा में उत्तर लिखने का तरीका भी बताओ।
''';

      case 'कक्षा 11':
      case 'कक्षा 12':
        return '''
यह senior-secondary विद्यार्थी है।
उत्तर academic और conceptually accurate होना चाहिए।
जहां जरूरी हो वहां technical terminology इस्तेमाल करो।
Numerical, derivation, formula और reasoning को step-by-step समझाओ।
Board/exam preparation के लिए महत्वपूर्ण points बताओ।
''';

      default:
        return '''
विद्यार्थी की कक्षा के अनुसार सरल और उचित स्तर पर समझाओ।
''';
    }
  }

  String _subjectTeachingProfile() {
    switch (selectedSubject) {
      case 'गणित':
        return '''
गणित में:
- calculation दोबारा check करो।
- formula पहले बताओ।
- values रखकर solution दिखाओ।
- final answer साफ लिखो।
- केवल answer नहीं, तरीका भी समझाओ।
''';

      case 'विज्ञान':
        return '''
विज्ञान में:
- पहले concept समझाओ।
- फिर सरल उदाहरण दो।
- महत्वपूर्ण definitions और कारण बताओ।
- जरूरत होने पर steps/process बताओ।
''';

      case 'अंग्रेजी':
        return '''
अंग्रेजी में:
- grammar को आसान उदाहरणों से समझाओ।
- नए शब्द का अर्थ बताओ।
- sentence बनाने का तरीका बताओ।
- विद्यार्थी की भाषा के अनुसार हिंदी में सहायता कर सकते हो।
''';

      case 'हिंदी':
        return '''
हिंदी में:
- शब्दों का सरल अर्थ बताओ।
- व्याकरण को उदाहरण से समझाओ।
- पाठ/कविता से जुड़े प्रश्नों का स्पष्ट उत्तर दो।
''';

      case 'इतिहास':
        return '''
इतिहास में:
- घटनाओं को क्रम से समझाओ।
- तारीख और महत्वपूर्ण व्यक्ति तभी बताओ जब जरूरी हो।
- कारण और परिणाम स्पष्ट करो।
''';

      case 'भूगोल':
        return '''
भूगोल में:
- स्थान, कारण और प्रक्रिया को सरल तरीके से समझाओ।
- जरूरत होने पर उदाहरण दो।
''';

      case 'सामाजिक विज्ञान':
        return '''
सामाजिक विज्ञान में:
- concept को सरल भाषा में समझाओ।
- महत्वपूर्ण points अलग-अलग बताओ।
- परीक्षा में लिखने योग्य उत्तर भी बताओ।
''';

      case 'कंप्यूटर':
        return '''
कंप्यूटर में:
- पहले concept समझाओ।
- फिर practical example दो।
- technical शब्दों का आसान अर्थ बताओ।
''';

      default:
        return '''
विषय के अनुसार सही और विद्यार्थी-अनुकूल तरीके से समझाओ।
''';
    }
  }

  String _buildTeacherInstruction() {
    final topic = _topicController.text.trim();

    return '''
आप "AI Personal Teacher" हैं।

आप एक वास्तविक school teacher की तरह विद्यार्थी को पढ़ाते हैं।

विद्यार्थी:
कक्षा: $selectedClass
विषय: $selectedSubject
Study Mode: ${studyMode ? 'ON' : 'OFF'}
${topic.isEmpty ? '' : 'वर्तमान अध्याय/Topic: $topic'}

कक्षा के अनुसार teaching:
${_classTeachingProfile()}

विषय के अनुसार teaching:
${_subjectTeachingProfile()}

सामान्य नियम:

1. विद्यार्थी जिस भाषा में सवाल पूछे, उसी भाषा में जवाब देने की कोशिश करो।

2. हिंदी में पूछने पर साफ और सरल हिंदी इस्तेमाल करो।

3. Roman Hindi में पूछने पर जरूरत के अनुसार हिंदी या Roman Hindi में समझा सकते हो।

4. विद्यार्थी को केवल final answer मत दो।
जरूरत के अनुसार तरीका भी समझाओ।

5. गणित में calculation बिल्कुल सही रखो।

6. अगर सवाल आसान है तो बहुत लंबा जवाब मत दो।

7. अगर विद्यार्थी "समझाओ", "क्यों", "कैसे" या "detail" पूछता है तो concept को ज्यादा विस्तार से समझाओ।

8. अगर विद्यार्थी का सवाल फोटो में है तो फोटो को ध्यान से पढ़ो और उसमें मौजूद सवाल का समाधान करो।

9. अगर सवाल अधूरा है तो अनुमान लगाने के बजाय जरूरी जानकारी पूछो।

10. गलत जानकारी को confidently मत बताओ।

11. Markdown के बहुत ज्यादा symbols मत इस्तेमाल करो।
** और ### जैसे symbols का अनावश्यक उपयोग मत करो।

12. Mobile screen के लिए छोटे paragraphs रखो।

13. जरूरी जगह पर:
Step 1:
Step 2:
Step 3:
जैसा format इस्तेमाल करो।

14. Study Mode ON होने पर:
- पहले concept समझाओ
- फिर example दो
- फिर छोटा practice question दो
- practice question का answer तुरंत मत बताओ
- विद्यार्थी के उत्तर का इंतजार करो

15. Study Mode OFF होने पर:
सीधा और उपयोगी उत्तर दो।

16. विद्यार्थी अगर "मुझे नहीं समझ आया" कहे तो उसी concept को और आसान भाषा में दोबारा समझाओ।

17. विद्यार्थी अगर परीक्षा की तैयारी पूछे तो महत्वपूर्ण points और exam-oriented guidance दो।

18. बच्चे को डराने या डांटने की भाषा इस्तेमाल मत करो।

आपका लक्ष्य है:
"विद्यार्थी को answer देना ही नहीं, बल्कि उसे समझाना और सीखने में मदद करना।"
''';
  }

  // ============================================================
  // MICROPHONE
  // ============================================================

  Future<void> _startListening() async {
    if (loading) return;

    if (listening) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          listening = false;
        });
      }

      return;
    }

    if (!_speech.isAvailable) {
      final available = await _speech.initialize();

      if (!available) {
        _showSnackBar(
          'Mic उपलब्ध नहीं है। Settings में Microphone permission check करें।',
        );
        return;
      }
    }

    setState(() {
      listening = true;
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _controller.text = result.recognizedWords;

          _controller.selection = TextSelection.fromPosition(
            TextPosition(
              offset: _controller.text.length,
            ),
          );
        });
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  // ============================================================
  // CAMERA / GALLERY
  // ============================================================

  Future<void> _pickImage() async {
    if (loading) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.camera_alt),
                  ),
                  title: const Text('Camera से फोटो लें'),
                  onTap: () {
                    Navigator.pop(context, 'camera');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_library),
                  ),
                  title: const Text('Gallery से फोटो चुनें'),
                  onTap: () {
                    Navigator.pop(context, 'gallery');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    try {
      XFile? image;

      if (choice == 'camera') {
        image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1800,
          maxHeight: 1800,
        );
      } else {
        image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1800,
          maxHeight: 1800,
        );
      }

      if (image != null && mounted) {
        setState(() {
          selectedImage = image;
        });
      }
    } catch (e) {
      _showSnackBar(
        'Camera/Gallery नहीं खुल पाई। Permission check करें।',
      );
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    if (loading) return;

    final question = _controller.text.trim();
    final image = selectedImage;

    if (question.isEmpty && image == null) {
      _showSnackBar(
        'पहले सवाल लिखें, बोलें या फोटो लें।',
      );
      return;
    }

    if (listening) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          listening = false;
        });
      }
    }

    final userText = question.isEmpty
        ? 'इस फोटो में दिए गए सवाल को हल करके समझाइए।'
        : question;

    setState(() {
      _messages.add(
        ChatMessage(
          isUser: true,
          text: userText,
          imagePath: image?.path,
        ),
      );

      _controller.clear();
      selectedImage = null;
      loading = true;
    });

    _scrollToBottom();

    try {
      final answer = await _askGemini(
        question: userText,
        imageFile: image,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: answer,
          ),
        );

        loading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: _friendlyError(e),
          ),
        );

        loading = false;
      });

      _scrollToBottom();
    }
  }

  // ============================================================
  // GEMINI API
  // ============================================================

  Future<String> _askGemini({
    required String question,
    XFile? imageFile,
  }) async {
    if (geminiApiKey.trim().isEmpty) {
      throw Exception('API_KEY_MISSING');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$geminiModel:generateContent',
    );

    final List<Map<String, dynamic>> history = [];

    for (final message in _messages) {
      if (message.isUser) {
        history.add({
          'role': 'user',
          'parts': [
            {
              'text': message.text,
            }
          ],
        });
      } else {
        history.add({
          'role': 'model',
          'parts': [
            {
              'text': message.text,
            }
          ],
        });
      }
    }

    if (history.isNotEmpty) {
      history.removeLast();
    }

    final List<Map<String, dynamic>> currentParts = [
      {
        'text': '''
${_buildTeacherInstruction()}

विद्यार्थी का सवाल:

$question
'''
      }
    ];

    if (imageFile != null) {
      final bytes = await File(
        imageFile.path,
      ).readAsBytes();

      currentParts.add({
        'inline_data': {
          'mime_type': _imageMimeType(
            imageFile.path,
          ),
          'data': base64Encode(bytes),
        },
      });
    }

    history.add({
      'role': 'user',
      'parts': currentParts,
    });

    final body = {
      'system_instruction': {
        'parts': [
          {
            'text': _buildTeacherInstruction(),
          }
        ],
      },
      'contents': history,
      'generationConfig': {
        'maxOutputTokens': 4096,
      },
    };

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': geminiApiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 60),
        );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      String details = '';

      try {
        final decoded = jsonDecode(
          response.body,
        );

        details =
            decoded['error']?['message']?.toString() ?? '';
      } catch (_) {
        details = response.body;
      }

      throw Exception(
        'API_${response.statusCode}: $details',
      );
    }

    final data = jsonDecode(
      response.body,
    );

    final candidates = data['candidates'];

    if (candidates == null ||
        candidates is! List ||
        candidates.isEmpty) {
      throw Exception('EMPTY_RESPONSE');
    }

    final content = candidates[0]['content'];

    if (content == null) {
      throw Exception('NO_CONTENT');
    }

    final responseParts = content['parts'];

    if (responseParts == null ||
        responseParts is! List) {
      throw Exception('NO_TEXT');
    }

    final buffer = StringBuffer();

    for (final part in responseParts) {
      if (part is Map &&
          part['text'] != null) {
        buffer.write(
          part['text'],
        );
      }
    }

    final answer = buffer.toString().trim();

    if (answer.isEmpty) {
      throw Exception('EMPTY_TEXT');
    }

    return _cleanAnswer(answer);
  }

  String _imageMimeType(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }

  String _cleanAnswer(String text) {
    return text
        .replaceAll('### ', '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .trim();
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('API_KEY_MISSING')) {
      return '''
❌ Gemini API Key नहीं मिली।

GitHub Actions में GEMINI_API_KEY secret check करें।
''';
    }

    if (message.contains('API_400')) {
      return '''
❌ Gemini request में समस्या हुई।

कृपया थोड़ी देर बाद फिर कोशिश करें।

Technical:
$message
''';
    }

    if (message.contains('API_401') ||
        message.contains('API_403')) {
      return '''
❌ Gemini API Key स्वीकार नहीं हुई।

GitHub Secrets में GEMINI_API_KEY check करें।
''';
    }

    if (message.contains('API_404')) {
      return '''
❌ Gemini model उपलब्ध नहीं है।

Model:
$geminiModel
''';
    }

    if (message.contains('API_429')) {
      return '''
⏳ Gemini पर अभी बहुत ज्यादा requests हैं।

कुछ देर बाद फिर कोशिश करें।
''';
    }

    if (message.contains('TimeoutException')) {
      return '''
🌐 Internet connection slow है।

Internet check करके फिर कोशिश करें।
''';
    }

    return '''
❌ अभी जवाब नहीं मिल पाया।

Internet और Gemini API connection check करें।
''';
  }

  // ============================================================
  // TEXT TO SPEECH
  // ============================================================

  Future<void> _speak(String text) async {
    await _tts.stop();

    final hindi = RegExp(
      r'[\u0900-\u097F]',
    );

    await _tts.setLanguage(
      hindi.hasMatch(text)
          ? 'hi-IN'
          : 'en-IN',
    );

    await _tts.setSpeechRate(0.48);
    await _tts.speak(text);
  }

  // ============================================================
  // CHAT MANAGEMENT
  // ============================================================

  void _clearChat() {
    if (_messages.isEmpty) return;

    setState(() {
      _messages.clear();
    });

    _showSnackBar(
      'Chat साफ कर दी गई।',
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnackBar(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9F6FF),
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8D7FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Color(0xFF673AB7),
            ),
          ),
        ),
        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'AI Personal Teacher',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'आपका digital teacher',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'नई Chat',
            onPressed:
                loading ? null : _clearChat,
            icon: const Icon(
              Icons.add_comment_outlined,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearChat();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Chat साफ करें',
                      ),
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
          _buildStudyPanel(),

          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller:
                        _scrollController,
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      20,
                    ),
                    itemCount:
                        _messages.length +
                            (loading ? 1 : 0),
                    itemBuilder:
                        (context, index) {
                      if (index ==
                          _messages.length) {
                        return _buildLoading();
                      }

                      return _buildMessage(
                        _messages[index],
                      );
                    },
                  ),
          ),

          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildStudyPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        5,
        14,
        5,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFE9D8FF),
              Color(0xFFF1E7FF),
            ],
          ),
          borderRadius:
              BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF673AB7),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Text(
                    'Study Mode',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: studyMode,
                  activeColor:
                      const Color(0xFF673AB7),
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
                  child: _dropdown(
                    label: 'कक्षा',
                    value: selectedClass,
                    items: classes,
                    onChanged:
                        loading
                            ? null
                            : (value) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                setState(() {
                                  selectedClass =
                                      value;
                                });
                              },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dropdown(
                    label: 'विषय',
                    value: selectedSubject,
                    items: subjects,
                    onChanged:
                        loading
                            ? null
                            : (value) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                setState(() {
                                  selectedSubject =
                                      value;
                                });
                              },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                hintText:
                    'अध्याय / Topic (वैकल्पिक)',
                prefixIcon: const Icon(
                  Icons.menu_book_outlined,
                  color: Color(0xFF673AB7),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(18),
                  borderSide:
                      BorderSide.none
