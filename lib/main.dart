import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
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

  const ChatMessage({
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
  // GEMINI CONFIG
  // ============================================================

  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String modelName = 'gemini-2.5-flash';

  static const String geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$modelName:generateContent';

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

    _initializeSpeech();
    _initializeTts();
  }

  // ============================================================
  // TEACHER INSTRUCTION
  // ============================================================

  String _teacherInstruction() {
    return '''
आप "AI Personal Teacher" हैं।

आपका काम विद्यार्थी को उसकी चुनी हुई कक्षा,
विषय और Topic के अनुसार पढ़ाना है।

विद्यार्थी की जानकारी:

कक्षा: $_selectedClass
विषय: $_selectedSubject
Topic: ${_selectedTopic.trim().isEmpty ? 'कोई विशेष Topic नहीं चुना गया' : _selectedTopic}
Study Mode: ${_studyMode ? 'ON' : 'OFF'}

==================================================
CLASS LEVEL
==================================================

कक्षा 1 से 3:
बहुत आसान भाषा।
छोटे वाक्य।
रोजमर्रा के उदाहरण।

कक्षा 4 से 5:
सरल explanation।
छोटे steps।
जरूरत होने पर example।

कक्षा 6 से 8:
Concept स्पष्ट करें।
जरूरत के अनुसार formula और examples दें।

कक्षा 9 से 10:
School examination level का उत्तर दें।
Definition, formula, steps और examples जरूरत के अनुसार दें।

कक्षा 11 से 12:
Academic level पर स्पष्ट explanation दें।
जरूरत होने पर detailed explanation दें।

==================================================
LANGUAGE
==================================================

विद्यार्थी जिस भाषा में पूछे उसी भाषा में जवाब दें।

Hindi:
आसान Hindi।

Hinglish:
आसान Hindi/Hinglish।

English:
English।

==================================================
SUBJECT
==================================================

गणित:
Calculation step-by-step करें।

विज्ञान:
Concept, कारण और उदाहरण समझाएँ।

हिंदी:
व्याकरण, पाठ, शब्दार्थ और प्रश्न कक्षा के अनुसार समझाएँ।

अंग्रेजी:
Grammar और meaning आसान तरीके से समझाएँ।

इतिहास:
घटनाएँ और तथ्य सही क्रम में समझाएँ।

भूगोल:
स्थान, कारण और उदाहरण समझाएँ।

सामाजिक विज्ञान:
History, Geography और Civics को कक्षा के अनुसार समझाएँ।

कंप्यूटर:
Technical शब्दों को आसान भाषा में समझाएँ।

सामान्य ज्ञान:
सीधा और सही उत्तर दें।

==================================================
STUDY MODE
==================================================

अगर विद्यार्थी "समझाओ", "कैसे", "क्यों",
"पूरा समझाओ" आदि पूछता है:

1. Concept समझाएँ।
2. Step-by-step समझाएँ।
3. Example दें।
4. जरूरत हो तो छोटा अभ्यास दें।

लेकिन हर उत्तर के अंत में जबरदस्ती नया सवाल न पूछें।

अगर विद्यार्थी factual question पूछता है,
तो सीधे उसका उत्तर दें।

==================================================
IMPORTANT
==================================================

विद्यार्थी के सवाल का पहले सीधा उत्तर दें।

बिना जरूरत:
- नया सवाल न पूछें।
- Challenge न दें।
- Motivational speech न दें।
- लंबा introduction न दें।

==================================================
WRONG ANSWER
==================================================

अगर विद्यार्थी गलत answer देता है:

"कोई बात नहीं, इसे एक बार सही तरीके से समझते हैं।"

फिर सही तरीका समझाएँ।

==================================================
IMAGE
==================================================

अगर image भेजी गई है:

Image को ध्यान से देखकर question पढ़ें।

Homework है तो हल करें।

Maths है तो calculation दिखाएँ।

Image साफ नहीं है तो बताएं कि image साफ दिखाई नहीं दे रही है।

==================================================
FORMATTING
==================================================

Markdown formatting का उपयोग न करें।

इनका उपयोग न करें:

**
***
###
##
$
$$

LaTeX का उपयोग न करें।

Maths में सामान्य symbols इस्तेमाल करें:

+
−
×
÷
=
≥
≤

उदाहरण:

2500 ÷ 25 = 100

उत्तर: 100

==================================================
FINAL RULE
==================================================

हर उत्तर:
सही,
स्पष्ट,
कक्षा के अनुसार,
विषय के अनुसार,
सरल
और विद्यार्थी के लिए उपयोगी होना चाहिए।
''';
  }

  // ============================================================
  // CONTEXT
  // ============================================================

  String _teacherContext() {
    return '''
वर्तमान विद्यार्थी:

कक्षा: $_selectedClass
विषय: $_selectedSubject
Topic: ${_selectedTopic.trim().isEmpty ? 'कोई विशेष Topic नहीं' : _selectedTopic}
Study Mode: ${_studyMode ? 'ON' : 'OFF'}
''';
  }

  // ============================================================
  // GEMINI REQUEST
  // ============================================================

  Future<String> _askGemini({
    required String question,
    Uint8List? imageBytes,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('API_KEY_MISSING');
    }

    final List<Map<String, dynamic>> parts = [];

    parts.add({
      'text': '''
${_teacherInstruction()}

${_teacherContext()}

विद्यार्थी का सवाल:

$question

अब विद्यार्थी के सवाल का सीधा और उपयोगी उत्तर दें।
''',
    });

    if (imageBytes != null) {
      parts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Encode(imageBytes),
        },
      });
    }

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        }
      ],
    };

    final response = await http
        .post(
          Uri.parse(geminiUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 60),
        );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final candidates =
          data['candidates'] as List<dynamic>?;

      if (candidates == null ||
          candidates.isEmpty) {
        throw Exception('EMPTY_RESPONSE');
      }

      final candidate =
          candidates.first as Map<String, dynamic>;

      final content =
          candidate['content'] as Map<String, dynamic>?;

      final responseParts =
          content?['parts'] as List<dynamic>?;

      if (responseParts == null ||
          responseParts.isEmpty) {
        throw Exception('EMPTY_RESPONSE');
      }

      final buffer = StringBuffer();

      for (final part in responseParts) {
        if (part is Map<String, dynamic>) {
          final text = part['text'];

          if (text is String) {
            buffer.write(text);
          }
        }
      }

      final answer = buffer.toString().trim();

      if (answer.isEmpty) {
        throw Exception('EMPTY_RESPONSE');
      }

      return _cleanAnswer(answer);
    }

    if (response.statusCode == 400) {
      throw Exception('BAD_REQUEST');
    }

    if (response.statusCode == 401 ||
        response.statusCode == 403) {
      throw Exception('INVALID_API_KEY');
    }

    if (response.statusCode == 404) {
      throw Exception('MODEL_NOT_FOUND');
    }

    if (response.statusCode == 429) {
      throw Exception('RATE_LIMIT');
    }

    if (response.statusCode >= 500) {
      throw Exception('SERVER_ERROR');
    }

    throw Exception(
      'HTTP_${response.statusCode}',
    );
  }

  // ============================================================
  // CLEAN ANSWER
  // ============================================================

  String _cleanAnswer(String text) {
    String answer = text.trim();

    answer = answer.replaceAll('###', '');
    answer = answer.replaceAll('##', '');
    answer = answer.replaceAll('#', '');

    answer = answer.replaceAll('***', '');
    answer = answer.replaceAll('**', '');
    answer = answer.replaceAll('__', '');

    answer = answer.replaceAll(r'\div', '÷');
    answer = answer.replaceAll(r'\times', '×');
    answer = answer.replaceAll(r'\cdot', '×');
    answer = answer.replaceAll(r'\pm', '±');
    answer = answer.replaceAll(r'\geq', '≥');
    answer = answer.replaceAll(r'\leq', '≤');

    answer = answer.replaceAll(r'\(', '');
    answer = answer.replaceAll(r'\)', '');
    answer = answer.replaceAll(r'\[', '');
    answer = answer.replaceAll(r'\]', '');

    answer = answer.replaceAll(r'\frac', '');

    answer = answer.replaceAll(
      RegExp(r'\n{3,}'),
      '\n\n',
    );

    return answer.trim();
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('API_KEY_MISSING')) {
      return '''
Gemini API key सेट नहीं है।

GitHub Secrets में GEMINI_API_KEY डालें।
''';
    }

    if (message.contains('INVALID_API_KEY')) {
      return '''
Gemini API key गलत है या valid नहीं है।

GitHub Secret GEMINI_API_KEY check करें।
''';
    }

    if (message.contains('MODEL_NOT_FOUND')) {
      return '''
Gemini model उपलब्ध नहीं है।

Model:
$modelName
''';
    }

    if (message.contains('RATE_LIMIT')) {
      return '''
Gemini API की request limit पूरी हो गई है।

कुछ समय बाद दोबारा कोशिश करें।
''';
    }

    if (message.contains('BAD_REQUEST')) {
      return '''
Gemini request में समस्या है।

कृपया सवाल दोबारा भेजें।
''';
    }

    if (message.contains('SERVER_ERROR')) {
      return '''
Gemini server से अभी response नहीं मिला।

कुछ समय बाद दोबारा कोशिश करें।
''';
    }

    if (message.contains('TimeoutException') ||
        message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('Network')) {
      return '''
Internet connection की समस्या है।

Internet ON करके दोबारा कोशिश करें।
''';
    }

    return '''
जवाब नहीं मिल पाया।

Internet connection और Gemini API key check करें।
''';
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final question =
        _textController.text.trim();

    if (question.isEmpty &&
        _selectedImage == null) {
      return;
    }

    if (_loading) {
      return;
    }

    final finalQuestion = question.isEmpty
        ? 'इस image में दिए गए सवाल को पढ़कर आसान भाषा में हल करें।'
        : question;

    final imageForMessage =
        _selectedImage;

    setState(() {
      _messages.add(
        ChatMessage(
          text: finalQuestion,
          isUser: true,
          imageBytes: imageForMessage,
        ),
      );

      _textController.clear();
      _selectedImage = null;
      _loading = true;
    });

    _scrollToBottom();

    try {
      final answer = await _askGemini(
        question: finalQuestion,
        imageBytes: imageForMessage,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: answer,
            isUser: false,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: _friendlyError(e),
            isUser: false,
          ),
        );
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _scrollToBottom();
    }
  }

  // ============================================================
  // SPEECH INITIALIZE
  // ============================================================

  Future<void> _initializeSpeech() async {
    try {
      final available =
          await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'notListening') {
            setState(() {
              _listening = false;
            });
          }
        },
        onError: (_) {
          if (!mounted) return;

          setState(() {
            _listening = false;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _speechAvailable = available;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _speechAvailable = false;
      });
    }
  }

  // ============================================================
  // TTS
  // ============================================================

  Future<void> _initializeTts() async {
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();

      final isHindi =
          RegExp(r'[\u0900-\u097F]')
              .hasMatch(text);

      if (isHindi) {
        await _tts.setLanguage('hi-IN');
      } else {
        await _tts.setLanguage('en-IN');
      }

      await _tts.speak(text);
    } catch (_) {
      _showMessage(
        'Voice playback उपलब्ध नहीं है।',
      );
    }
  }

  // ============================================================
  // VOICE INPUT
  // ============================================================

  Future<void> _toggleListening() async {
    if (_loading) return;

    if (!_speechAvailable) {
      _showMessage(
        'Microphone उपलब्ध नहीं है। Phone Settings में Microphone permission check करें।',
      );
      return;
    }

    if (_listening) {
      await _speech.stop();

      if (!mounted) return;

      setState(() {
        _listening = false;
      });

      return;
    }

    try {
      final locales =
          await _speech.locales();

      String? localeId;

      for (final locale in locales) {
        final id =
            locale.localeId.toLowerCase();

        if (id == 'hi_in' ||
            id == 'hi-in') {
          localeId =
              locale.localeId;
          break;
        }
      }

      localeId ??= 'en_IN';

      setState(() {
        _listening = true;
      });

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _textController.text =
                result.recognizedWords;

            _textController.selection =
                TextSelection.fromPosition(
              TextPosition(
                offset:
                    _textController.text.length,
              ),
            );
          });

          if (result.finalResult) {
            setState(() {
              _listening = false;
            });
          }
        },
        listenOptions:
            stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          localeId: localeId,
          listenMode:
              stt.ListenMode.dictation,
          autoPunctuation: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _listening = false;
      });

      _showMessage(
        'Voice input शुरू नहीं हो पाया। Microphone permission check करें।',
      );
    }
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    if (_loading) return;

    try {
      final image =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) return;

      final bytes =
          await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImage = bytes;
      });
    } catch (_) {
      _showMessage(
        'Image select नहीं हो पाई।',
      );
    }
  }

  // ============================================================
  // NEW CHAT
  // ============================================================

  void _newChat() {
    setState(() {
      _messages.clear();
      _selectedTopic = '';
      _selectedImage = null;
      _textController.clear();
    });
  }

  // ============================================================
  // RESTART CHAT
  // ============================================================

  void _restartChatOnly() {
    if (_messages.isNotEmpty) {
      setState(() {
        _messages.clear();
      });
    }
  }

  // ============================================================
  // TOPIC
  // ============================================================

  Future<void> _editTopic() async {
    final controller =
        TextEditingController(
      text: _selectedTopic,
    );

    final result =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'अध्याय / Topic',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              hintText:
                  'जैसे: भिन्न, प्रकाश, grammar...',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('रद्द'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              child:
                  const Text('सेट करें'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    setState(() {
      _selectedTopic = result;
    });

    _restartChatOnly();
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _dropdownBox({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child:
          DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration:
            InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(20),
            borderSide:
                BorderSide.none,
          ),
        ),
        items: items
            .map(
              (item) =>
                  DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ============================================================
  // STUDY PANEL
  // ============================================================

  Widget _buildStudyPanel() {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFFE9D8FF),
            Color(0xFFF2E8FF),
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
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child:
                    const Icon(
                  Icons.menu_book_rounded,
                  color:
                      Color(0xFF673AB7),
                  size: 30,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              const Expanded(
                child: Text(
                  'Study Mode',
                  style:
                      TextStyle(
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: _studyMode,
                onChanged: (value) {
                  setState(() {
                    _studyMode =
                        value;
                  });

                  _restartChatOnly();
                },
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          Row(
            children: [
              _dropdownBox(
                label: 'कक्षा',
                value:
                    _selectedClass,
                items: _classes,
                onChanged:
                    (value) {
                  if (value ==
                      null) {
                    return;
                  }

                  setState(() {
                    _selectedClass =
                        value;
                  });

                  _restartChatOnly();
                },
              ),
              const SizedBox(
                width: 12,
              ),
              _dropdownBox(
                label: 'विषय',
                value:
                    _selectedSubject,
                items: _subjects,
                onChanged:
                    (value) {
                  if (value ==
                      null) {
                    return;
                  }

                  setState(() {
                    _selectedSubject =
                        value;
                  });

                  _restartChatOnly();
                },
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          InkWell(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            onTap:
                _editTopic,
            child: Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 18,
                vertical: 17,
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
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .menu_book_outlined,
                    color:
                        Color(0xFF673AB7),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Text(
                      _selectedTopic
                              .isEmpty
                          ? 'अध्याय / Topic (वैकल्पिक)'
                          : _selectedTopic,
                      style:
                          TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight
                                .w600,
                        color: _selectedTopic
                                .isEmpty
                            ? Colors
                                .grey
                                .shade700
                            : Colors
                                .black87,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons
                        .edit_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  Widget _buildMessage(
    ChatMessage message,
  ) {
    final isUser =
        message.isUser;

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(
          maxWidth:
              MediaQuery.of(context)
                      .size
                      .width *
                  0.88,
        ),
        margin:
            const EdgeInsets
                .symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        padding:
            const EdgeInsets.all(
          16,
        ),
        decoration:
            BoxDecoration(
          color: isUser
              ? const Color(
                  0xFFE3CCFF,
                )
              : Colors.white,
          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius.circular(
              22,
            ),
            topRight:
                const Radius.circular(
              22,
            ),
            bottomLeft:
                Radius.circular(
              isUser ? 22 : 5,
            ),
            bottomRight:
                Radius.circular(
              isUser ? 5 : 22,
            ),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset:
                  const Offset(0, 4),
              color:
                  Colors.black
                      .withValues(
                alpha: 0.06,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor:
                      isUser
                          ? const Color(
                              0xFF673AB7,
                            )
                          : const Color(
                              0xFFE9D8FF,
                            ),
                  child: Icon(
                    isUser
                        ? Icons.person
                        : Icons
                            .school_rounded,
                    color: isUser
                        ? Colors.white
                        : const Color(
                            0xFF673AB7,
                          ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  isUser
                      ? 'आप'
                      : 'Teacher',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            if (message
                    .imageBytes !=
                null) ...[
              const SizedBox(
                height: 12,
              ),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                child:
                    Image.memory(
                  message
                      .imageBytes!,
                  width:
                      double.infinity,
                  fit:
                      BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(
              height: 12,
            ),
            SelectableText(
              message.text,
              style:
                  const TextStyle(
                fontSize: 18,
                height: 1.5,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(
                height: 8,
              ),
              Align(
                alignment:
                    Alignment
                        .centerRight,
                child:
                    IconButton(
                  onPressed:
                      () => _speak(
                    message.text,
                  ),
                  icon:
                      const Icon(
                    Icons
                        .volume_up_rounded,
                    color:
                        Color(0xFF673AB7),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFE9D8FF,
                ),
                borderRadius:
                    BorderRadius.circular(
                  28,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .school_rounded,
                size: 52,
                color:
                    Color(0xFF673AB7),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'नमस्ते! 👋',
              style:
                  TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'मैं आपका digital teacher हूँ।\n'
              'कक्षा और विषय चुनकर सवाल पूछिए।',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 17,
                height: 1.5,
                color: Colors
                    .grey
                    .shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets
                .fromLTRB(
          12,
          8,
          12,
          10,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset:
                  const Offset(0, -4),
              color:
                  Colors.black
                      .withValues(
                alpha: 0.06,
              ),
            ),
          ],
        ),
        child: Column(
          children: [
            if (_selectedImage !=
                null)
              Container(
                margin:
                    const EdgeInsets
                        .only(
                  bottom: 8,
                ),
                height: 80,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                      child:
                          Image.memory(
                        _selectedImage!,
                        width: 80,
                        height: 80,
                        fit:
                            BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -5,
                      top: -5,
                      child:
                          IconButton(
                        onPressed:
                            () {
                          setState(
                            () {
                              _selectedImage =
                                  null;
                            },
                          );
                        },
                        style:
                            IconButton
                                .styleFrom(
                          backgroundColor:
                              Colors
                                  .white,
                        ),
                        icon:
                            const Icon(
                          Icons.close,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .end,
              children: [
                IconButton(
                  onPressed:
                      _loading
                          ? null
                          : _pickImage,
                  icon:
                      const Icon(
                    Icons
                        .add_a_photo_outlined,
                    size: 30,
                    color:
                        Color(0xFF673AB7),
                  ),
                ),
                Expanded(
                  child:
                      TextField(
                    controller:
                        _textController,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction:
                        TextInputAction
                            .newline,
                    decoration:
                        InputDecoration(
                      hintText:
                          _listening
                              ? '🎤 सुन रहा हूँ...'
                              : 'अपना सवाल लिखें...',
                      filled: true,
                      fillColor:
                          const Color(
                        0xFFF2EDFA,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          25,
                        ),
                        borderSide:
                            BorderSide
                                .none,
                      ),
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 4,
                ),
                IconButton(
                  onPressed:
                      _loading
                          ? null
                          : _toggleListening,
                  icon: Icon(
                    _listening
                        ? Icons
                            .stop_circle_rounded
                        : Icons
                            .mic_rounded,
                    size: 31,
                    color:
                        _listening
                            ? Colors.red
                            : const Color(
                                0xFF673AB7,
                              ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _loading
                          ? null
                          : _sendMessage,
                  icon: Icon(
                    Icons
                        .send_rounded,
                    size: 34,
                    color:
                        _loading
                            ? Colors.grey
                            : const Color(
                                0xFF673AB7,
                              ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding:
            const EdgeInsets
                .fromLTRB(
          16,
          8,
          10,
          8,
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFE9D8FF,
                ),
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child:
                  const Icon(
                Icons.school_rounded,
                size: 32,
                color:
                    Color(0xFF673AB7),
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    'AI Personal Teacher',
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      fontSize: 23,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  Text(
                    'आपका class-wise digital teacher',
                    style:
                        TextStyle(
                      fontSize: 14,
                      color:
                          Colors.grey,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed:
                  _newChat,
              icon:
                  const Icon(
                Icons
                    .add_comment_outlined,
                size: 30,
              ),
            ),
            PopupMenuButton<String>(
              onSelected:
                  (value) {
                if (value ==
                    'clear') {
                  _newChat();
                }
              },
              itemBuilder:
                  (context) =>
                      const [
                PopupMenuItem(
                  value: 'clear',
                  child:
                      Text(
                    'नई Chat',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!_scrollController
            .hasClients) {
          return;
        }

        _scrollController
            .animateTo(
          _scrollController
              .position
              .maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 300,
          ),
          curve:
              Curves.easeOut,
        );
      },
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(
    String text,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(text),
        behavior:
            SnackBarBehavior
                .floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildStudyPanel(),
          Expanded(
            child:
                _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller:
                            _scrollController,
                        padding:
                            const EdgeInsets
                                .only(
                          top: 8,
                          bottom: 20,
                        ),
                        itemCount:
                            _messages.length +
                                (_loading
                                    ? 1
                                    : 0),
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          if (index ==
                              _messages
                                  .length) {
                            return
                                _buildLoadingBubble();
                          }

                          return
                              _buildMessage(
                            _messages[
                                index],
                          );
                        },
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingBubble() {
    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        margin:
            const EdgeInsets
                .symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        padding:
            const EdgeInsets.all(
          18,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            22,
          ),
        ),
        child:
            const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(
              width: 12,
            ),
            Text(
              'Teacher सोच रहा है...',
              style:
                  TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
