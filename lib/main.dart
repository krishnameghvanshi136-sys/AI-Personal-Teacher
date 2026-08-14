import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
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
        fontFamily: 'sans',
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
  );

  // Current stable Gemini model.
  // If your API key does not have access, we will check that
  // separately after the Flutter build is working.
  static const String modelName = 'gemini-3.5-flash';

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
  bool _studyMode = false;

  String _selectedClass = 'कक्षा 5';
  String _selectedSubject = 'गणित';

  String _selectedTopic = '';

  Uint8List? _selectedImage;

  final List<ChatMessage> _messages = [];

  // ============================================================
  // CLASS LIST
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

  void _initializeGemini() {
    if (apiKey.trim().isEmpty) {
      return;
    }

    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(
        '''
आप "AI Personal Teacher" नाम के एक डिजिटल शिक्षक हैं।

आपका काम विद्यार्थी को उसकी कक्षा और विषय के अनुसार पढ़ाना है।

नियम:

1. विद्यार्थी की भाषा को समझें।
2. अगर विद्यार्थी हिंदी में पूछे तो हिंदी में उत्तर दें।
3. अगर विद्यार्थी Hinglish में पूछे तो आसान Hinglish/Hindi में उत्तर दें।
4. अगर विद्यार्थी English में पूछे तो English में उत्तर दें।
5. बहुत कठिन भाषा का उपयोग न करें।
6. पहले सीधा उत्तर दें।
7. जरूरत होने पर step-by-step explanation दें।
8. गणित में calculation साफ तरीके से दिखाएँ।
9. विज्ञान में उदाहरण देकर समझाएँ।
10. इतिहास और सामाजिक विज्ञान में तथ्य स्पष्ट रखें।
11. विद्यार्थी की कक्षा के स्तर से ज्यादा कठिन उत्तर न दें।
12. विद्यार्थी अगर "समझाओ" कहे तो शिक्षक की तरह धीरे-धीरे समझाएँ।
13. विद्यार्थी अगर अभ्यास प्रश्न माँगे तो प्रश्न दें और जरूरत पड़ने पर उत्तर बाद में दें।
14. विद्यार्थी अगर परीक्षा की तैयारी करे तो महत्वपूर्ण points और संभावित प्रश्न दें।
15. विद्यार्थी अगर सिर्फ सामान्य सवाल पूछे तो भी मदद करें।
16. गलत उत्तर मिलने पर विनम्रता से सही उत्तर समझाएँ।
17. कभी भी यह न कहें कि आप सिर्फ AI हैं और इसलिए मदद नहीं कर सकते।
18. उत्तर अनावश्यक रूप से बहुत लंबा न करें।
19. हर उत्तर विद्यार्थी के लिए उपयोगी और पढ़ने में आसान होना चाहिए।
        ''',
      ),
    );

    _chat = _model!.startChat();
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'notListening') {
            setState(() {
              _listening = false;
            });
          }
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            _listening = false;
          });

          _showMessage(
            'Mic में समस्या हुई। Microphone permission check करें।',
          );
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

  Future<void> _initializeTts() async {
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  // ============================================================
  // STUDY PROMPT
  // ============================================================

  String _teacherContext() {
    final topic = _selectedTopic.trim();

    return '''
विद्यार्थी की जानकारी:

कक्षा: $_selectedClass
विषय: $_selectedSubject
अध्याय/Topic: ${topic.isEmpty ? 'कोई विशेष topic नहीं चुना गया' : topic}

अगर Study Mode ON है:
- विद्यार्थी को शिक्षक की तरह पढ़ाएँ।
- पहले concept समझाएँ।
- फिर छोटा उदाहरण दें।
- अंत में अभ्यास प्रश्न दें।
- जरूरत हो तो विद्यार्थी से एक छोटा सवाल पूछें।

अगर Study Mode OFF है:
- सामान्य chat teacher की तरह उत्तर दें।

उत्तर विद्यार्थी की कक्षा के स्तर के अनुसार रखें।
''';
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final question = _textController.text.trim();

    if (question.isEmpty && _selectedImage == null) {
      return;
    }

    if (_loading) {
      return;
    }

    if (_model == null || _chat == null) {
      _showMessage(
        'Gemini API key उपलब्ध नहीं है।',
      );
      return;
    }

    final String finalQuestion = question.isEmpty
        ? 'इस image को देखकर विद्यार्थी को आसान भाषा में समझाइए।'
        : question;

    final imageForMessage = _selectedImage;

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
      final promptText = '''
${_teacherContext()}

विद्यार्थी का सवाल:

$finalQuestion
''';

      GenerateContentResponse response;

      if (imageForMessage != null) {
        response = await _chat!.sendMessage(
          Content.multi([
            TextPart(promptText),
            DataPart(
              'image/jpeg',
              imageForMessage,
            ),
          ]),
        );
      } else {
        response = await _chat!.sendMessage(
          Content.text(promptText),
        );
      }

      final answer = response.text?.trim();

      if (!mounted) return;

      if (answer == null || answer.isEmpty) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'अभी जवाब नहीं मिल पाया। कृपया दोबारा कोशिश करें।',
              isUser: false,
            ),
          );
        });
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              text: answer,
              isUser: false,
            ),
          );
        });
      }
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
  // ERROR
  // ============================================================

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('InvalidApiKey') ||
        message.contains('API key')) {
      return '''
❌ Gemini API key में समस्या है।

API key check करें और फिर दोबारा कोशिश करें।
''';
    }

    if (message.contains('404') ||
        message.contains('not found') ||
        message.contains('NOT_FOUND')) {
      return '''
❌ Gemini model उपलब्ध नहीं है।

अभी इस्तेमाल हो रहा model:
$modelName

API key के लिए उपलब्ध model बाद में check करेंगे।
''';
    }

    if (message.contains('429') ||
        message.contains('RESOURCE_EXHAUSTED')) {
      return '''
⚠️ Gemini API की request limit पूरी हो गई है।

थोड़ी देर बाद दोबारा कोशिश करें।
''';
    }

    if (message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('Network')) {
      return '''
❌ Internet connection की समस्या है।

Internet ON करके दोबारा कोशिश करें।
''';
    }

    return '''
❌ जवाब नहीं मिल पाया।

Internet connection और Gemini API key check करें।

Error:
$message
''';
  }

  // ============================================================
  // VOICE INPUT
  // ============================================================

  Future<void> _toggleListening() async {
    if (_loading) return;

    if (!_speechAvailable) {
      _showMessage(
        'Mic उपलब्ध नहीं है। Phone Settings में Microphone permission check करें।',
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
      final locales = await _speech.locales();

      String? localeId;

      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();

        if (id == 'hi_in' || id == 'hi-in') {
          localeId = locale.localeId;
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
            _textController.text = result.recognizedWords;
            _textController.selection =
                TextSelection.fromPosition(
              TextPosition(
                offset: _textController.text.length,
              ),
            );
          });

          if (result.finalResult) {
            setState(() {
              _listening = false;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          localeId: localeId,
          listenMode: stt.ListenMode.dictation,
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
  // IMAGE PICKER
  // ============================================================

  Future<void> _pickImage() async {
    if (_loading) return;

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

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
  // TEXT TO SPEECH
  // ============================================================

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();

      final isHindi =
          RegExp(r'[\u0900-\u097F]').hasMatch(text);

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
  // NEW CHAT
  // ============================================================

  void _newChat() {
    setState(() {
      _messages.clear();
      _selectedTopic = '';
      _selectedImage = null;
    });

    if (_model != null) {
      _chat = _model!.startChat();
    }
  }

  // ============================================================
  // TOPIC
  // ============================================================

  Future<void> _editTopic() async {
    final controller =
        TextEditingController(text: _selectedTopic);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('अध्याय / Topic'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'जैसे: भिन्न, प्रकाश, grammar...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('रद्द'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              child: const Text('सेट करें'),
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
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE9D8FF),
            Color(0xFFF2E8FF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF673AB7),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Study Mode',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: _studyMode,
                onChanged: (value) {
                  setState(() {
                    _studyMode = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _dropdownBox(
                label: 'कक्षा',
                value: _selectedClass,
                items: _classes,
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedClass = value;
                  });
                },
              ),
              const SizedBox(width: 12),
              _dropdownBox(
                label: 'विषय',
                value: _selectedSubject,
                items: _subjects,
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedSubject = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _editTopic,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 17,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    color: Color(0xFF673AB7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedTopic.isEmpty
                          ? 'अध्याय / Topic (वैकल्पिक)'
                          : _selectedTopic,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _selectedTopic.isEmpty
                            ? Colors.grey.shade700
                            : Colors.black87,
                      ),
                    ),
                  ),
                  const Icon(Icons.edit_outlined),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFFE3CCFF)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(
              isUser ? 22 : 5,
            ),
            bottomRight: Radius.circular(
              isUser ? 5 : 22,
            ),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 4),
              color: Colors.black.withValues(
                alpha: 0.06,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: isUser
                      ? const Color(0xFF673AB7)
                      : const Color(0xFFE9D8FF),
                  child: Icon(
                    isUser
                        ? Icons.person
                        : Icons.school_rounded,
                    color: isUser
                        ? Colors.white
                        : const Color(0xFF673AB7),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isUser ? 'आप' : 'Teacher',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            if (message.imageBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  message.imageBytes!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SelectableText(
              message.text,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => _speak(message.text),
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: Color(0xFF673AB7),
                  ),
                  tooltip: 'सुनें',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFE9D8FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 52,
                color: Color(0xFF673AB7),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'नमस्ते! 👋',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'मैं आपका digital teacher हूँ।\n'
              'कोई भी सवाल पूछिए।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INPUT AREA
  // ============================================================

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, -4),
              color: Colors.black.withValues(
                alpha: 0.06,
              ),
            ),
          ],
        ),
        child: Column(
          children: [
            if (_selectedImage != null)
              Container(
                margin: const EdgeInsets.only(
                  bottom: 8,
                ),
                height: 80,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(14),
                      child: Image.memory(
                        _selectedImage!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -5,
                      top: -5,
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                        icon: const Icon(
                          Icons.close,
                        ),
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
                      _loading ? null : _pickImage,
                  icon: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 30,
                    color: Color(0xFF673AB7),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction:
                        TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: _listening
                          ? '🎤 सुन रहा हूँ...'
                          : 'अपना सवाल लिखें...',
                      filled: true,
                      fillColor:
                          const Color(0xFFF2EDFA),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed:
                      _loading ? null : _toggleListening,
                  icon: Icon(
                    _listening
                        ? Icons.stop_circle_rounded
                        : Icons.mic_rounded,
                    size: 31,
                    color: _listening
                        ? Colors.red
                        : const Color(0xFF673AB7),
                  ),
                ),
                IconButton(
                  onPressed:
                      _loading ? null : _sendMessage,
                  icon: Icon(
                    Icons.send_rounded,
                    size: 34,
                    color: _loading
                        ? Colors.grey
                        : const Color(0xFF673AB7),
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
        padding: const EdgeInsets.fromLTRB(
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
              decoration: BoxDecoration(
                color: const Color(0xFFE9D8FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 32,
                color: Color(0xFF673AB7),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Personal Teacher',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'आपका digital teacher',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _newChat,
              icon: const Icon(
                Icons.add_comment_outlined,
                size: 30,
              ),
              tooltip: 'नई chat',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _newChat();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'clear',
                  child: Text('नई Chat'),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildStudyPanel(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      top: 8,
                      bottom: 20,
                    ),
                    itemCount: _messages.length +
                        (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index ==
                          _messages.length) {
                        return _buildLoadingBubble();
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

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Teacher सोच रहा है...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
