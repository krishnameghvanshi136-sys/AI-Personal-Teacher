import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AIPersonalTeacherApp());
}

class AIPersonalTeacherApp extends StatelessWidget {
  const AIPersonalTeacherApp({super.key});

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
        scaffoldBackgroundColor: const Color(0xFFF9F7FF),
      ),
      home: const TeacherHomePage(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? imageBytes;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBytes,
  });
}

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  // ============================================================
  // GEMINI
  // ============================================================

  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String modelName = 'gemini-2.5-flash';

  GenerativeModel? _model;
  ChatSession? _chat;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _textController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final stt.SpeechToText _speech =
      stt.SpeechToText();

  final FlutterTts _tts =
      FlutterTts();

  final ImagePicker _imagePicker =
      ImagePicker();

  // ============================================================
  // STATE
  // ============================================================

  bool _loading = false;
  bool _listening = false;
  bool _speechAvailable = false;
  bool _studyMode = true;

  String _selectedClass = 'कक्षा 5';
  String _selectedSubject = 'गणित';
  String _selectedTopic = '';

  Uint8List? _selectedImage;

  final List<ChatMessage> _messages = [];

  // ============================================================
  // CLASSES
  // ============================================================

  final List<String> _classes = const [
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

  // ============================================================
  // SUBJECTS
  // ============================================================

  final List<String> _subjects = const [
    'गणित',
    'विज्ञान',
    'हिंदी',
    'अंग्रेजी',
    'सामाजिक विज्ञान',
    'इतिहास',
    'भूगोल',
    'कंप्यूटर',
    'सामान्य ज्ञान',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializeGemini();
    _initializeSpeech();
    _initializeTts();
  }

  // ============================================================
  // GEMINI
  // ============================================================

  void _initializeGemini() {
    if (apiKey.trim().isEmpty) {
      return;
    }

    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(
        '''
आप "AI Personal Teacher" हैं।

आपका मुख्य काम विद्यार्थी को उसकी चुनी हुई कक्षा,
विषय और अध्याय के स्तर के अनुसार पढ़ाना है।

==================================================
सबसे महत्वपूर्ण नियम
==================================================

विद्यार्थी की चुनी हुई जानकारी:

कक्षा: $_selectedClass
विषय: $_selectedSubject
Topic: ${_selectedTopic.trim().isEmpty ? 'कोई विशेष Topic नहीं' : _selectedTopic}

इस जानकारी को हर उत्तर में ध्यान में रखें।

विद्यार्थी को उसी कक्षा के विद्यार्थी की तरह समझाएँ।

उदाहरण:

कक्षा 3 है तो कक्षा 3 के स्तर का उत्तर दें।

कक्षा 8 है तो कक्षा 8 के स्तर का उत्तर दें।

कक्षा 10 है तो कक्षा 10 के स्तर का उत्तर दें।

कक्षा 12 है तो कक्षा 12 के स्तर का उत्तर दें।

==================================================
LANGUAGE
==================================================

विद्यार्थी जिस भाषा में सवाल पूछता है,
उसी भाषा में जवाब दें।

Hindi में सवाल:
आसान Hindi में जवाब दें।

Hinglish में सवाल:
आसान Hindi/Hinglish में जवाब दें।

English में सवाल:
English में जवाब दें।

==================================================
CLASS-WISE TEACHING
==================================================

कक्षा 1 से 3:

बहुत आसान भाषा रखें।
छोटे वाक्य रखें।
बच्चों के रोजमर्रा के उदाहरण दें।

कक्षा 4 से 5:

सरल explanation दें।
छोटे step दें।
उदाहरण जरूर दें जब जरूरत हो।

कक्षा 6 से 8:

Concept को स्पष्ट तरीके से समझाएँ।
जरूरत के अनुसार formula और examples दें।

कक्षा 9 से 10:

School examination level का explanation दें।
Definition, formula, steps और examples जरूरत के अनुसार दें।

कक्षा 11 से 12:

Concept को अधिक स्पष्ट और academic तरीके से समझाएँ।
जरूरत होने पर detailed explanation दें।
लेकिन विद्यार्थी के सवाल से ज्यादा लंबा उत्तर न दें।

==================================================
SUBJECT-WISE TEACHING
==================================================

गणित:

Calculation step-by-step दिखाएँ।

उदाहरण:

25 × 4 = 100

250 ÷ 25 = 10

Formula और final answer साफ रखें।

विज्ञान:

पहले concept समझाएँ।
फिर आसान उदाहरण दें।
जरूरत हो तो कारण और परिणाम बताएं।

हिंदी:

व्याकरण, पाठ, शब्दार्थ और प्रश्नों को कक्षा के अनुसार समझाएँ।

अंग्रेजी:

Grammar और English concepts को आसान तरीके से समझाएँ।
जरूरत होने पर Hindi में meaning दें।

इतिहास:

तथ्य सही रखें।
घटनाओं को आसान क्रम में समझाएँ।

भूगोल:

स्थान, कारण और उदाहरणों के साथ समझाएँ।

सामाजिक विज्ञान:

Civics, History और Geography के सवालों को विद्यार्थी की कक्षा के अनुसार समझाएँ।

कंप्यूटर:

Technical शब्दों को आसान भाषा में समझाएँ।

सामान्य ज्ञान:

सीधा और सही उत्तर दें।

==================================================
STUDY MODE
==================================================

Study Mode ON है।

अगर विद्यार्थी "समझाओ
