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

// अपनी अभी वाली working Gemini model यहां रखो।
const String geminiModel = 'gemini-2.5-flash';

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
        scaffoldBackgroundColor:
            const Color(0xFFF9F6FF),
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

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() =>
      _TeacherHomePageState();
}

class _TeacherHomePageState
    extends State<TeacherHomePage> {
  final TextEditingController _controller =
      TextEditingController();

  final TextEditingController _topicController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final ImagePicker _imagePicker =
      ImagePicker();

  final stt.SpeechToText _speech =
      stt.SpeechToText();

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
        if (status == 'done' ||
            status == 'notListening') {
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

  // =========================================================
  // CLASS-WISE AI TEACHING
  // =========================================================

  String _classProfile() {
    switch (selectedClass) {
      case 'कक्षा 1':
      case 'कक्षा 2':
      case 'कक्षा 3':
        return '''
विद्यार्थी छोटा बच्चा है।
बहुत आसान भाषा में समझाओ।
छोटे वाक्य इस्तेमाल करो।
रोजमर्रा के उदाहरण और छोटी कहानी का उपयोग करो।
एक बार में बहुत ज्यादा जानकारी मत दो।
''';

      case 'कक्षा 4':
      case 'कक्षा 5':
        return '''
विद्यार्थी प्राथमिक स्तर का है।
सरल भाषा में concept समझाओ।
Step-by-step उदाहरण दो।
जरूरत हो तो छोटा practice question दो।
''';

      case 'कक्षा 6':
      case 'कक्षा 7':
      case 'कक्षा 8':
        return '''
विद्यार्थी middle school में है।
पहले concept समझाओ।
फिर example दो।
Formula, definition और reasoning समझाओ।
''';

      case 'कक्षा 9':
      case 'कक्षा 10':
        return '''
विद्यार्थी secondary level पर है।
Concept के साथ exam-oriented explanation दो।
Formula, definition और important points बताओ।
गणित और विज्ञान में पूरा solution दिखाओ।
''';

      case 'कक्षा 11':
      case 'कक्षा 12':
        return '''
विद्यार्थी senior secondary level पर है।
Academic और accurate explanation दो।
Technical terminology जरूरत के अनुसार इस्तेमाल करो।
Numerical, derivation और reasoning step-by-step समझाओ।
Board exam के लिए महत्वपूर्ण points बताओ।
''';

      default:
        return 'विद्यार्थी की कक्षा के अनुसार समझाओ।';
    }
  }

  String _subjectProfile() {
    switch (selectedSubject) {
      case 'गणित':
        return '''
गणित में calculation दोबारा check करो।
पहले formula बताओ।
फिर values रखो।
Step-by-step solution दो।
अंत में final answer साफ लिखो।
''';

      case 'विज्ञान':
        return '''
विज्ञान में पहले concept समझाओ।
फिर आसान example दो।
Definition, कारण और process समझाओ।
''';

      case 'अंग्रेजी':
        return '''
English में grammar और vocabulary को आसान examples से समझाओ।
जरूरत होने पर हिंदी में अर्थ बताओ।
Sentence बनाने का तरीका समझाओ।
''';

      case 'हिंदी':
        return '''
हिंदी में शब्दों का अर्थ और grammar उदाहरण के साथ समझाओ।
पाठ और कविता के प्रश्नों के स्पष्ट उत्तर दो।
''';

      case 'इतिहास':
        return '''
इतिहास में घटनाओं को क्रम से समझाओ।
कारण और परिणाम स्पष्ट करो।
महत्वपूर्ण तारीख और व्यक्ति जरूरत के अनुसार बताओ।
''';

      case 'भूगोल':
        return '''
भूगोल में स्थान, कारण और प्रक्रिया को सरल उदाहरणों से समझाओ।
''';

      case 'सामाजिक विज्ञान':
        return '''
Social Science में concept और important points सरल भाषा में समझाओ।
Exam में लिखने योग्य points भी बताओ।
''';

      case 'कंप्यूटर':
        return '''
Computer में पहले concept समझाओ।
फिर practical example दो।
Technical शब्दों का आसान अर्थ बताओ।
''';

      default:
        return 'विषय के अनुसार विद्यार्थी को समझाओ।';
    }
  }

  String _teacherPrompt() {
    final topic = _topicController.text.trim();

    return '''
आप "AI Personal Teacher" हैं।

आप एक वास्तविक school teacher की तरह विद्यार्थी को पढ़ाते हैं।

विद्यार्थी की जानकारी:

कक्षा: $selectedClass
विषय: $selectedSubject
Study Mode: ${studyMode ? 'ON' : 'OFF'}

${topic.isNotEmpty ? 'अध्याय/Topic: $topic' : ''}

कक्षा के अनुसार teaching:
${_classProfile()}

विषय के अनुसार teaching:
${_subjectProfile()}

नियम:

1. विद्यार्थी जिस भाषा में सवाल पूछे उसी भाषा में जवाब दो।

2. Roman Hindi में सवाल हो तो जरूरत के अनुसार आसान हिंदी या Roman Hindi में समझाओ।

3. सिर्फ answer मत दो। जरूरत के अनुसार तरीका भी समझाओ।

4. गणित में calculation बिल्कुल सही रखो।

5. विद्यार्थी "क्यों", "कैसे", "समझाओ" या "detail" पूछे तो विस्तार से समझाओ।

6. फोटो में सवाल हो तो फोटो को पढ़कर सवाल हल करो।

7. सवाल अधूरा हो तो जरूरी जानकारी पूछो।

8. गलत जानकारी confidently मत बताओ।

9. Mobile screen के लिए छोटे paragraphs रखो।

10. अनावश्यक Markdown symbols का उपयोग मत करो।

11. Study Mode ON होने पर:
पहले concept समझाओ।
फिर example दो।
फिर practice question दो।
Practice question का answer तुरंत मत बताओ।

12. Study Mode OFF होने पर सीधा उपयोगी उत्तर दो।

13. विद्यार्थी "समझ नहीं आया" कहे तो उसी concept को और आसान तरीके से समझाओ।

14. परीक्षा की तैयारी पूछने पर exam-oriented answer दो।

15. बच्चे को डांटने या डराने की भाषा मत इस्तेमाल करो।

लक्ष्य:
विद्यार्थी को सिर्फ answer देना नहीं बल्कि उसे समझाना और सिखाना।
''';
  }

  // =========================================================
  // SEND
  // =========================================================

  Future<void> _sendMessage() async {
    if (loading) return;

    final question =
        _controller.text.trim();

    final image = selectedImage;

    if (question.isEmpty &&
        image == null) {
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
            text: _errorMessage(e),
          ),
        );

        loading = false;
      });

      _scrollToBottom();
    }
  }

  // =========================================================
  // GEMINI
  // =========================================================

  Future<String> _askGemini({
    required String question,
    XFile? imageFile,
  }) async {
    if (geminiApiKey.isEmpty) {
      throw Exception('API_KEY_MISSING');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/'
      'v1beta/models/$geminiModel:generateContent',
    );

    final contents =
        <Map<String, dynamic>>[];

    for (final message in _messages) {
      contents.add({
        'role': message.isUser
            ? 'user'
            : 'model',
        'parts': [
          {
            'text': message.text,
          }
        ],
      });
    }

    if (contents.isNotEmpty) {
      contents.removeLast();
    }

    final currentParts =
        <Map<String, dynamic>>[
      {
        'text': '''
${_teacherPrompt()}

विद्यार्थी का वर्तमान सवाल:

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
          'mime_type':
              _getMimeType(imageFile.path),
          'data': base64Encode(bytes),
        },
      });
    }

    contents.add({
      'role': 'user',
      'parts': currentParts,
    });

    final body = {
      'system_instruction': {
        'parts': [
          {
            'text': _teacherPrompt(),
          }
        ],
      },
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': 4096,
      },
    };

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type':
                'application/json',
            'x-goog-api-key':
                geminiApiKey,
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
        final data =
            jsonDecode(response.body);

        details = data['error']
                    ?['message']
                    ?.toString() ??
            '';
      } catch (_) {}

      throw Exception(
        'API_${response.statusCode}: $details',
      );
    }

    final data =
        jsonDecode(response.body);

    final candidates =
        data['candidates'];

    if (candidates == null ||
        candidates is! List ||
        candidates.isEmpty) {
      throw Exception('EMPTY_RESPONSE');
    }

    final parts =
        candidates[0]['content']?['parts'];

    if (parts == null ||
        parts is! List) {
      throw Exception('NO_TEXT');
    }

    final result =
        StringBuffer();

    for (final part in parts) {
      if (part is Map &&
          part['text'] != null) {
        result.write(
          part['text'],
        );
      }
    }

    final answer =
        result.toString().trim();

    if (answer.isEmpty) {
      throw Exception('EMPTY_TEXT');
    }

    return answer
        .replaceAll('### ', '')
        .replaceAll('**', '')
        .trim();
  }

  String _getMimeType(String path) {
    final p = path.toLowerCase();

    if (p.endsWith('.png')) {
      return 'image/png';
    }

    if (p.endsWith('.webp')) {
      return 'image/webp';
    }

    if (p.endsWith('.heic')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }

  // =========================================================
  // MICROPHONE
  // =========================================================

  Future<void> _startListening() async {
    if (loading) return;

    if (listening) {
      await _speech.stop();

      setState(() {
        listening = false;
      });

      return;
    }

    final available =
        await _speech.initialize();

    if (!available) {
      _showSnackBar(
        'Mic उपलब्ध नहीं है। Phone Settings में Microphone permission दें।',
      );
      return;
    }

    setState(() {
      listening = true;
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _controller.text =
              result.recognizedWords;

          _controller.selection =
              TextSelection.fromPosition(
            TextPosition(
              offset:
                  _controller.text.length,
            ),
          );
        });
      },
      listenOptions:
          stt.SpeechListenOptions(
        partialResults: true,
        listenMode:
            stt.ListenMode.dictation,
      ),
    );
  }

  // =========================================================
  // IMAGE
  // =========================================================

  Future<void> _pickImage() async {
    if (loading) return;

    final choice =
        await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'सवाल की फोटो',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                ),
                title: const Text(
                  'Camera से फोटो लें',
                ),
                onTap: () =>
                    Navigator.pop(
                  context,
                  'camera',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                ),
                title: const Text(
                  'Gallery से फोटो चुनें',
                ),
                onTap: () =>
                    Navigator.pop(
                  context,
                  'gallery',
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        );
      },
    );

    if (choice == null) return;

    try {
      final image =
          await _imagePicker.pickImage(
        source: choice == 'camera'
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (image != null &&
          mounted) {
        setState(() {
          selectedImage = image;
        });
      }
    } catch (_) {
      _showSnackBar(
        'Photo नहीं खुल पाई। Permission check करें।',
      );
    }
  }

  // =========================================================
  // TEXT TO SPEECH
  // =========================================================

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

  // =========================================================
  // UI HELPERS
  // =========================================================

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!_scrollController
          .hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController
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

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  String _errorMessage(Object e) {
    final text = e.toString();

    if (text.contains(
      'API_KEY_MISSING',
    )) {
      return '''
❌ Gemini API Key नहीं मिली।

GitHub में GEMINI_API_KEY secret check करें।
''';
    }

    if (text.contains('API_401') ||
        text.contains('API_403')) {
      return '''
❌ Gemini API Key सही नहीं है या अनुमति नहीं मिली।

GitHub Secrets में GEMINI_API_KEY check करें।
''';
    }

    if (text.contains('API_404')) {
      return '''
❌ Gemini model उपलब्ध नहीं है।

अभी इस्तेमाल हो रहा model:
$geminiModel
''';
    }

    if (text.contains('API_429')) {
      return '''
⏳ Gemini पर अभी ज्यादा requests हैं।

थोड़ी देर बाद फिर कोशिश करें।
''';
    }

    if (text.contains('Timeout')) {
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

  // =========================================================
  // MAIN UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF9F6FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            const Color(0xFFF9F6FF),
        surfaceTintColor:
            Colors.transparent,
        leading: Padding(
          padding:
              const EdgeInsets.all(8),
          child: Container(
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFE8D7FF),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              color:
                  Color(0xFF673AB7),
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
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            Text(
              'आपका digital teacher',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
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
                        const EdgeInsets.all(
                      14,
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

  // =========================================================
  // STUDY PANEL
  // =========================================================

  Widget _buildStudyPanel() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        4,
        14,
        5,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              Color(0xFFE9D8FF),
              Color(0xFFF1E7FF),
            ],
          ),
          borderRadius:
              BorderRadius.circular(
            28,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      17,
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color:
                        Color(0xFF673AB7),
                    size: 32,
                  ),
                ),
                const SizedBox(
                  width: 13,
                ),
                const Expanded(
                  child: Text(
                    'Study Mode',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: studyMode,
                  activeColor:
                      const Color(
                    0xFF673AB7,
                  ),
                  onChanged: loading
                      ? null
                      : (value) {
                          setState(() {
                            studyMode =
                                value;
                          });
                        },
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'कक्षा',
                    selectedClass,
                    classes,
                    (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        selectedClass =
                            value;
                      });
                    },
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: _buildDropdown(
                    'विषय',
                    selectedSubject,
                    subjects,
                    (value) {
                      if (value == null) {
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
              controller:
                  _topicController,
              decoration:
                  InputDecoration(
                hintText:
                    'अध्याय / Topic (वैकल्पिक)',
                prefixIcon:
                    const Icon(
                  Icons.menu_book_outlined,
                  color:
                      Color(0xFF673AB7),
                ),
                filled: true,
                fillColor:
                    Colors.white,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return InputDecorator(
      decoration:
          InputDecoration(
        labelText: label,
        filled: true,
        fillColor:
            Colors.white,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),
      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value: value,
          isExpanded: true,
          items:
              items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            );
          }).toList(),
          onChanged: loading
              ? null
              : onChanged,
        ),
      ),
    );
  }

  // =========================================================
  // WELCOME
  // =========================================================

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(
            height: 20,
          ),

          Container(
            width: 88,
            height: 88,
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFE5D1FF),
              borderRadius:
                  BorderRadius.circular(
                28,
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 52,
              color:
                  Color(0xFF673AB7),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          const Text(
            'नमस्ते विद्यार्थी! 👋',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 27,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'अपनी कक्षा और विषय चुनें और सवाल पूछें।',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color:
                  Colors.black54,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          _suggestion(
            '📚',
            'मुझे यह chapter समझाओ',
          ),

          _suggestion(
            '🧮',
            'एक गणित का सवाल हल करो',
          ),

          _suggestion(
            '📷',
            'फोटो में दिए सवाल को हल करो',
          ),
        ],
      ),
    );
  }

  Widget _suggestion(
    String icon,
    String text,
  ) {
    return GestureDetector(
      onTap: loading
          ? null
          : () {
              setState(() {
                _controller.text =
                    text;
              });
            },
      child: Container(
        width:
            double.infinity,
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 14,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: Row(
          children: [
            Text(
              icon,
              style:
                  const TextStyle(
                fontSize: 23,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Text(
                text,
                style:
                    const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CHAT MESSAGE
  // =========================================================

  Widget _buildMessage(
    ChatMessage message,
  ) {
    if (message.isUser) {
      return Align(
        alignment:
            Alignment.centerRight,
        child: Container(
          constraints:
              const BoxConstraints(
            maxWidth: 370,
          ),
          margin:
              const EdgeInsets.only(
            bottom: 14,
            left: 35,
          ),
          padding:
              const EdgeInsets.all(16),
          decoration:
              const BoxDecoration(
            color:
                Color(0xFFE3CFFF),
            borderRadius:
                BorderRadius.only(
              topLeft:
                  Radius.circular(22),
              topRight:
                  Radius.circular(22),
              bottomLeft:
                  Radius.circular(22),
              bottomRight:
                  Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor:
                        Color(0xFF673AB7),
                    child: Icon(
                      Icons.person,
                      color:
                          Colors.white,
                    ),
                  ),
                  SizedBox(
                    width: 9,
                  ),
                  Text(
                    'आप',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),

              if (message.imagePath !=
                  null) ...[
                const SizedBox(
                  height: 12,
                ),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  child:
                      Image.file(
                    File(
                      message.imagePath!,
                    ),
                    height: 180,
                    width:
                        double.infinity,
                    fit:
                        BoxFit.cover,
                  ),
                ),
              ],

              const SizedBox(
                height: 10,
              ),

              Text(
                message.text,
                style:
                    const TextStyle(
                  fontSize: 17,
                  height: 1.45,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 380,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 14,
          right: 18,
        ),
        padding:
            const EdgeInsets.all(17),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset:
                  const Offset(0, 3),
              color: Colors.black
                  .withOpacity(
                0.06,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFE9D9FF,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: const Icon(
                    Icons.school,
                    color:
                        Color(0xFF673AB7),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                const Text(
                  'Teacher',
                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 13,
            ),

            SelectableText(
              message.text,
              style:
                  const TextStyle(
                fontSize: 17,
                height: 1.55,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            Align(
              alignment:
                  Alignment.centerRight,
              child: IconButton(
                onPressed: () {
                  _speak(
                    message.text,
                  );
                },
                icon:
                    const Icon(
                  Icons.volume_up_rounded,
                  color:
                      Color(0xFF673AB7),
                  size: 29,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 14,
          right: 80,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),
        child: const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2.5,
                color:
                    Color(0xFF673AB7),
              ),
            ),
            SizedBox(
              width: 12,
            ),
            Text(
              'Teacher सोच रहा है...',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // INPUT
  // =========================================================

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          8,
          7,
          8,
          8,
        ),
        color:
            Colors.white,
        child: Column(
          children: [
            if (selectedImage !=
                null)
              Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 8,
                ),
                padding:
                    const EdgeInsets.all(
                  8,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF0E7FF,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                      child:
                          Image.file(
                        File(
                          selectedImage!
                              .path,
                        ),
                        width: 60,
                        height: 60,
                        fit:
                            BoxFit.cover,
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    const Expanded(
                      child: Text(
                        'फोटो तैयार है। सवाल भेजें।',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.w600,
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

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed:
                      loading
                          ? null
                          : _pickImage,
                  icon:
                      const Icon(
                    Icons.add_a_photo_outlined,
                    size: 29,
                    color:
                        Color(0xFF673AB7),
                  ),
                ),

                Expanded(
                  child: Container(
                    constraints:
                        const BoxConstraints(
                      minHeight: 52,
                      maxHeight: 130,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFF3ECFF,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        27,
                      ),
                    ),
                    child:
                        TextField(
                      controller:
                          _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'अपना सवाल लिखें...',
                        border:
                            InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ),

                IconButton(
                  onPressed:
                      loading
                          ? null
                          : _startListening,
                  icon: Icon(
                    listening
                        ? Icons.mic
                        : Icons
                            .mic_none_rounded,
                    size: 31,
                    color: listening
                        ? Colors.red
                        : const Color(
                            0xFF673AB7,
                          ),
                  ),
                ),

                IconButton(
                  onPressed:
                      loading
                          ? null
                          : _sendMessage,
                  icon:
                      const Icon(
                    Icons.send_rounded,
                    size: 34,
                    color:
                        Color(0xFF673AB7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
