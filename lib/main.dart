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
        fontFamily: 'sans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF673AB7),
          brightness: Brightness.light,
        ),
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
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TextEditingController _controller = TextEditingController();
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
    _initializeTts();
    _initializeSpeech();
  }

  Future<void> _initializeTts() async {
    await _tts.setLanguage('hi-IN');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
  }

  Future<void> _initializeSpeech() async {
    await _speech.initialize(
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (loading) return;

    if (!_speech.isAvailable) {
      final available = await _speech.initialize();

      if (!available) {
        _showSnackBar(
          'Mic उपलब्ध नहीं है। फोन की Microphone permission check करें।',
        );
        return;
      }
    }

    if (listening) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          listening = false;
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        listening = true;
      });
    }

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<void> _pickImage() async {
    if (loading) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
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
                  'सवाल की फोटो लें',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.camera_alt),
                  ),
                  title: const Text('Camera से फोटो लें'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_library),
                  ),
                  title: const Text('Gallery से फोटो चुनें'),
                  onTap: () => Navigator.pop(context, 'gallery'),
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
          imageQuality: 75,
          maxWidth: 1600,
          maxHeight: 1600,
        );
      } else {
        image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
          maxWidth: 1600,
          maxHeight: 1600,
        );
      }

      if (image != null && mounted) {
        setState(() {
          selectedImage = image;
        });
      }
    } catch (e) {
      _showSnackBar('फोटो खोलने में समस्या हुई। Permission check करें।');
    }
  }

  Future<void> _sendMessage() async {
    if (loading) return;

    final question = _controller.text.trim();
    final image = selectedImage;

    if (question.isEmpty && image == null) {
      _showSnackBar('पहले अपना सवाल लिखें या फोटो लें।');
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
        userQuestion: userText,
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

  Future<String> _askGemini({
    required String userQuestion,
    XFile? imageFile,
  }) async {
    if (geminiApiKey.trim().isEmpty) {
      throw Exception(
        'API_KEY_MISSING',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$geminiModel:generateContent',
    );

    final parts = <Map<String, dynamic>>[];

    final systemPrompt = '''
आप "AI Personal Teacher" हैं।

आपका काम एक अच्छे स्कूल शिक्षक की तरह विद्यार्थी को पढ़ाना है।

विद्यार्थी की जानकारी:
कक्षा: $selectedClass
विषय: $selectedSubject
Study Mode: ${studyMode ? 'ON' : 'OFF'}

नियम:
1. विद्यार्थी को आसान और स्पष्ट भाषा में समझाएं।
2. अगर विद्यार्थी हिंदी में पूछे तो हिंदी में जवाब दें।
3. अगर विद्यार्थी अंग्रेजी में पूछे तो अंग्रेजी में जवाब दें।
4. गणित के सवाल में सही calculation करें।
5. गणित में जरूरत होने पर Step 1, Step 2, Step 3 में समझाएं।
6. बहुत कठिन शब्दों से बचें।
7. छोटे विद्यार्थी के लिए उदाहरण दें।
8. सिर्फ अंतिम उत्तर न दें, जरूरत के अनुसार समझाएं।
9. अगर फोटो में सवाल है तो फोटो को ध्यान से पढ़कर उसका समाधान दें।
10. Study Mode ON होने पर पहले concept समझाएं, फिर example दें और अंत में छोटा practice question दें।
11. विद्यार्थी अगर सामान्य बातचीत करे तो सामान्य शिक्षक की तरह जवाब दें।
12. Markdown के बहुत ज्यादा symbols जैसे ** और ### का उपयोग न करें।
13. जवाब साफ, mobile-friendly और पढ़ने में आसान रखें।
14. अगर सवाल अधूरा हो तो विद्यार्थी से जरूरी जानकारी पूछें।
''';

    final combinedPrompt = '''
$systemPrompt

विद्यार्थी का नया सवाल:
$userQuestion
''';

    parts.add({
      'text': combinedPrompt,
    });

    if (imageFile != null) {
      final bytes = await File(imageFile.path).readAsBytes();

      final base64Image = base64Encode(bytes);

      parts.add({
        'inline_data': {
          'mime_type': _imageMimeType(imageFile.path),
          'data': base64Image,
        },
      });
    }

    final contents = <Map<String, dynamic>>[];

    for (final message in _messages) {
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

    if (contents.isNotEmpty) {
      contents.removeLast();
    }

    contents.add({
      'role': 'user',
      'parts': parts,
    });

    final body = {
      'system_instruction': {
        'parts': [
          {
            'text': systemPrompt,
          }
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.5,
        'maxOutputTokens': 2048,
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String details = '';

      try {
        final decoded = jsonDecode(response.body);

        details = decoded['error']?['message']?.toString() ?? '';
      } catch (_) {
        details = response.body;
      }

      throw Exception(
        'API_${response.statusCode}: $details',
      );
    }

    final data = jsonDecode(response.body);

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

    if (responseParts == null || responseParts is! List) {
      throw Exception('NO_TEXT');
    }

    final buffer = StringBuffer();

    for (final part in responseParts) {
      if (part is Map && part['text'] != null) {
        buffer.write(part['text']);
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

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('API_KEY_MISSING')) {
      return '''
❌ Gemini API Key नहीं मिली।

GitHub Actions में GEMINI_API_KEY secret check करें और APK को दोबारा build करें।
''';
    }

    if (message.contains('API_400')) {
      return '''
❌ Gemini request गलत है।

API request या model configuration में समस्या है।

Technical error:
$message
''';
    }

    if (message.contains('API_401') ||
        message.contains('API_403')) {
      return '''
❌ Gemini API Key स्वीकार नहीं हुई।

Google AI Studio में API key check करें और देखें कि key सही project की है।
''';
    }

    if (message.contains('API_404')) {
      return '''
❌ Gemini model उपलब्ध नहीं है।

Current model:
$geminiModel

Technical error:
$message
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
🌐 Internet connection बहुत slow है।

Internet check करके फिर कोशिश करें।
''';
    }

    return '''
❌ जवाब नहीं मिल पाया।

Technical error:
$message

Internet और Gemini API key check करें।
''';
  }

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

  Future<void> _speak(String text) async {
    await _tts.stop();

    final language = _detectLanguage(text);

    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.48);
    await _tts.speak(text);
  }

  String _detectLanguage(String text) {
    final hindiPattern = RegExp(r'[\u0900-\u097F]');

    if (hindiPattern.hasMatch(text)) {
      return 'hi-IN';
    }

    return 'en-IN';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearChat() {
    if (_messages.isEmpty) return;

    setState(() {
      _messages.clear();
    });

    _showSnackBar('Chat साफ कर दी गई।');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9F5FF),
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE9D9FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.school,
              color: Color(0xFF673AB7),
            ),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Personal Teacher',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Text(
              'आपका digital teacher',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'नई Chat',
            onPressed: loading ? null : _clearChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearChat();
              }
            },
            itemBuilder: (context) => const [
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
            ],
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
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      20,
                    ),
                    itemCount: _messages.length + (loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildLoadingMessage();
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFEBDDFF),
              const Color(0xFFF1E9FF),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
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
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF673AB7),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Study Mode',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: studyMode,
                  activeColor: const Color(0xFF673AB7),
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _dropdownBox(
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
                  child: _dropdownBox(
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
      ),
    );
  }

  Widget _dropdownBox({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 3,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 25),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFE7D6FF),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 52,
              color: Color(0xFF673AB7),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'नमस्ते विद्यार्थी! 👋',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'मैं आपका AI Personal Teacher हूँ।',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 22),
          _suggestion(
            '📚',
            'मुझे गणित समझाओ',
          ),
          _suggestion(
            '📝',
            'आज क्या पढ़ना चाहिए?',
          ),
          _suggestion(
            '📷',
            'फोटो में दिए सवाल को हल करो',
          ),
          _suggestion(
            '🎤',
            'माइक दबाकर सवाल बोलें',
          ),
        ],
      ),
    );
  }

  Widget _suggestion(String icon, String text) {
    return GestureDetector(
      onTap: loading
          ? null
          : () {
              _controller.text = text;
            },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE5D9F2),
          ),
        ),
        child: Row(
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 360,
          ),
          margin: const EdgeInsets.only(
            bottom: 14,
            left: 35,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE4D1FF),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFF673AB7),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 9),
                  Text(
                    'आप',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              if (message.imagePath != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(message.imagePath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                message.text,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 380,
        ),
        margin: const EdgeInsets.only(
          bottom: 14,
          right: 18,
        ),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(22),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 3),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9D9FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Color(0xFF673AB7),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Teacher',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            SelectableText(
              message.text,
              style: const TextStyle(
                fontSize: 17,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'सुनें',
                onPressed: () => _speak(message.text),
                icon: const Icon(
                  Icons.volume_up_rounded,
                  color: Color(0xFF673AB7),
                  size: 29,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 14,
          right: 80,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF673AB7),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Teacher सोच रहा है...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          10,
          8,
          10,
          10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, -3),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Column(
          children: [
            if (selectedImage != null)
              Container(
                margin: const EdgeInsets.only(
                  bottom: 8,
                ),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E7FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(selectedImage!.path),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'फोटो तैयार है। सवाल भेजें।',
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
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'फोटो लें',
                  onPressed: loading ? null : _pickImage,
                  icon: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 30,
                    color: Color(0xFF673AB7),
                  ),
                ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 52,
                      maxHeight: 130,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4ECFF),
                      borderRadius: BorderRadius.circular(27),
                    ),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization:
                          TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'अपना सवाल लिखें...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!loading) {
                          _sendMessage();
                        }
                      },
                    ),
                  ),
                ),
                IconButton(
                  tooltip: listening
                      ? 'Mic बंद करें'
                      : 'बोलकर सवाल पूछें',
                  onPressed: loading
                      ? null
                      : _startListening,
                  icon: Icon(
                    listening
                        ? Icons.mic
                        : Icons.mic_none_rounded,
                    size: 31,
                    color: listening
                        ? Colors.red
                        : const Color(0xFF673AB7),
                  ),
                ),
                IconButton(
                  tooltip: 'सवाल भेजें',
                  onPressed: loading
                      ? null
                      : _sendMessage,
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 34,
                    color: Color(0xFF673AB7),
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
