import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const String geminiApiKey =
    String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

const String geminiModel = 'gemini-2.5-flash';

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
        scaffoldBackgroundColor: const Color(0xFFF9F7FC),
        fontFamily: 'sans',
      ),
      home: const TeacherHomePage(),
    );
  }
}

class ChatMessage {
  final bool isUser;
  final String text;
  final XFile? image;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.image,
  });
}

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final ImagePicker _imagePicker = ImagePicker();

  final stt.SpeechToText _speech = stt.SpeechToText();

  final List<ChatMessage> _messages = [];

  bool _studyMode = false;
  bool _loading = false;
  bool _listening = false;
  bool _speechAvailable = false;

  String _selectedClass = 'कक्षा 5';
  String _selectedSubject = 'गणित';
  String _selectedTopic = '';

  XFile? _selectedImage;

  final List<String> _classes = [
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

  final List<String> _subjects = [
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

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'done' || status == 'notListening') {
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
    }

    if (!_speechAvailable) {
      _showSnackBar(
        'Mic उपलब्ध नहीं है। Phone की Microphone permission check करें।',
      );
      return;
    }

    if (_listening) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          _listening = false;
        });
      }

      return;
    }

    setState(() {
      _listening = true;
    });

    await _speech.listen(
      localeId: 'hi_IN',
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _messageController.text = result.recognizedWords;
          _messageController.selection =
              TextSelection.fromPosition(
            TextPosition(
              offset: _messageController.text.length,
            ),
          );
        });
      },
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = image;
      });
    } catch (e) {
      _showSnackBar('Image चुनने में समस्या हुई।');
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _sendMessage() async {
    final question = _messageController.text.trim();

    if (question.isEmpty && _selectedImage == null) {
      return;
    }

    if (_loading) return;

    final image = _selectedImage;

    setState(() {
      _messages.add(
        ChatMessage(
          isUser: true,
          text: question.isEmpty
              ? 'इस तस्वीर को समझाइए।'
              : question,
          image: image,
        ),
      );

      _messageController.clear();
      _selectedImage = null;
      _loading = true;
    });

    _scrollToBottom();

    try {
      final answer = await _askGemini(
        question.isEmpty
            ? 'इस तस्वीर को समझाइए।'
            : question,
        image: image,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: answer,
          ),
        );

        _loading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: '❌ जवाब नहीं मिल पाया।\n\n$e',
          ),
        );

        _loading = false;
      });

      _scrollToBottom();
    }
  }

  Future<String> _askGemini(
    String question, {
    XFile? image,
  }) async {
    if (geminiApiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY app में नहीं मिली। '
        'GitHub Secret और --dart-define check करें।',
      );
    }

    final List<Map<String, dynamic>> contents = [];

    for (final message in _messages) {
      if (message.text.trim().isEmpty) continue;

      contents.add({
        'role': message.isUser ? 'user' : 'model',
        'parts': [
          {
            'text': message.text,
          },
        ],
      });
    }

    final List<Map<String, dynamic>> currentParts = [];

    final systemInstruction = _buildTeacherInstruction();

    currentParts.add({
      'text': '$systemInstruction\n\nछात्र का सवाल:\n$question',
    });

    if (image != null) {
      final bytes = await image.readAsBytes();

      final mimeType = _getMimeType(image.name);

      currentParts.add({
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Encode(bytes),
        },
      });
    }

    /*
     * Important:
     * The current question is already present in _messages.
     * इसलिए यहाँ duplicate question भेजने से बचने के लिए
     * history में आखिरी user message को हटाकर currentParts जोड़ रहे हैं.
     */

    if (contents.isNotEmpty &&
        contents.last['role'] == 'user') {
      contents.removeLast();
    }

    contents.add({
      'role': 'user',
      'parts': currentParts,
    });

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$geminiModel:generateContent',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': geminiApiKey,
      },
      body: jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 2048,
        },
      }),
    );

    if (response.statusCode != 200) {
      String message = response.body;

      try {
        final errorJson = jsonDecode(response.body);

        if (errorJson is Map &&
            errorJson['error'] is Map) {
          final error = errorJson['error'];

          message = error['message']?.toString() ??
              response.body;
        }
      } catch (_) {}

      throw Exception(
        'Gemini API Error (${response.statusCode}):\n$message',
      );
    }

    final data = jsonDecode(response.body);

    final candidates = data['candidates'];

    if (candidates == null ||
        candidates is! List ||
        candidates.isEmpty) {
      throw Exception(
        'Gemini ने कोई जवाब नहीं दिया।\n'
        'Response: ${response.body}',
      );
    }

    final candidate = candidates.first;

    final content = candidate['content'];

    if (content == null) {
      throw Exception(
        'Gemini response में content नहीं मिला।',
      );
    }

    final parts = content['parts'];

    if (parts == null ||
        parts is! List ||
        parts.isEmpty) {
      throw Exception(
        'Gemini response में text नहीं मिला।',
      );
    }

    final buffer = StringBuffer();

    for (final part in parts) {
      if (part is Map && part['text'] != null) {
        buffer.write(part['text']);
      }
    }

    final result = buffer.toString().trim();

    if (result.isEmpty) {
      throw Exception(
        'Gemini ने खाली जवाब दिया।',
      );
    }

    return result;
  }

  String _buildTeacherInstruction() {
    return '''
आप AI Personal Teacher हैं।

छात्र:
कक्षा: $_selectedClass
विषय: $_selectedSubject
अध्याय/Topic: ${_selectedTopic.isEmpty ? 'कोई विशेष topic नहीं' : _selectedTopic}

आपका काम:
1. छात्र के सवाल का सही और आसान उत्तर दें।
2. छात्र की कक्षा के स्तर के अनुसार भाषा रखें।
3. जरूरत होने पर step-by-step समझाएँ।
4. गणित में calculation साफ-साफ दिखाएँ।
5. अंग्रेजी सीखने वाले छात्र को आसान English और Hindi explanation दें।
6. छात्र अगर सामान्य सवाल पूछे तो भी सही जवाब दें।
7. बिना जरूरत बहुत लंबा जवाब न दें।
8. छात्र से दोस्ताना लेकिन शिक्षक जैसा व्यवहार करें।
9. अगर सवाल अस्पष्ट हो तो छोटा clarification पूछें।
10. गलत जानकारी न बनाएं।
11. उत्तर मुख्य रूप से हिंदी में दें, लेकिन जरूरत के अनुसार English शब्द इस्तेमाल कर सकते हैं।
12. Study Mode ON होने पर पहले concept समझाएँ, फिर छोटा example और अंत में practice question दें।
''';
  }

  String _getMimeType(String filename) {
    final name = filename.toLowerCase();

    if (name.endsWith('.png')) {
      return 'image/png';
    }

    if (name.endsWith('.webp')) {
      return 'image/webp';
    }

    if (name.endsWith('.gif')) {
      return 'image/gif';
    }

    return 'image/jpeg';
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

  void _clearChat() {
    if (_messages.isEmpty) return;

    setState(() {
      _messages.clear();
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _speak(String text) async {
    /*
     * फिलहाल Android की built-in TTS intent/service को
     * अलग package के बिना इस्तेमाल नहीं किया जा रहा।
     *
     * इसलिए यहाँ text को clipboard में copy किया जाता है।
     *
     * बाद में flutter_tts जोड़कर वास्तविक "सुनें" सुविधा
     * activate कर सकते हैं।
     */

    await Clipboard.setData(
      ClipboardData(text: text),
    );

    _showSnackBar(
      'जवाब copy हो गया।',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildStudyPanel(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildWelcome()
                  : _buildChat(),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE9DDFF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Color(0xFF673AB7),
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Personal Teacher',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'आपका digital teacher',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
          tooltip: 'नई चैट',
          onPressed: _clearChat,
          icon: const Icon(
            Icons.add_comment_outlined,
            size: 30,
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'clear') {
              _clearChat();
            }

            if (value == 'about') {
              _showAbout();
            }
          },
          itemBuilder: (context) {
            return const [
              PopupMenuItem(
                value: 'clear',
                child: Text('चैट साफ करें'),
              ),
              PopupMenuItem(
                value: 'about',
                child: Text('About'),
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _buildStudyPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEBDDFF),
            Color(0xFFF1E7FF),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF673AB7),
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Study Mode',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: _studyMode,
                activeColor: const Color(0xFF673AB7),
                onChanged: (value) {
                  setState(() {
                    _studyMode = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dropdownBox(
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdownBox(
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
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) {
              _selectedTopic = value;
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF673AB7),
              ),
              hintText: 'अध्याय / Topic (वैकल्पिक)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownBox({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFE9DDFF),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Color(0xFF673AB7),
              size: 54,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'नमस्ते! 👋',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'मैं आपका AI Personal Teacher हूँ।',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          _suggestionCard(
            'गणित का सवाल समझाओ',
            Icons.calculate_rounded,
          ),
          _suggestionCard(
            'मुझे English बोलना सिखाओ',
            Icons.language_rounded,
          ),
          _suggestionCard(
            'भारत की राजधानी क्या है?',
            Icons.public_rounded,
          ),
          _suggestionCard(
            'मुझे एक practice question दो',
            Icons.quiz_rounded,
          ),
        ],
      ),
    );
  }

  Widget _suggestionCard(
    String text,
    IconData icon,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE8E0F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF673AB7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _messages.length +
          (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_loading &&
            index == _messages.length) {
          return _buildLoadingBubble();
        }

        final message = _messages[index];

        return _buildMessage(message);
      },
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.88,
        ),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFFE4D1FF)
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
              blurRadius: 10,
              offset: const Offset(0, 3),
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: isUser
                      ? const Color(0xFF673AB7)
                      : const Color(0xFFE9DDFF),
                  child: Icon(
                    isUser
                        ? Icons.person
                        : Icons.school_rounded,
                    color: isUser
                        ? Colors.white
                        : const Color(0xFF673AB7),
                    size: 22,
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
            if (message.image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FutureBuilder<Uint8List>(
                  future: message.image!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 160,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    return Image.memory(
                      snapshot.data!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            SelectableText(
              message.text,
              style: const TextStyle(
                fontSize: 17,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'जवाब सुनें',
                  onPressed: () {
                    _speak(message.text);
                  },
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: Color(0xFF673AB7),
                    size: 28,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 14,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 15,
            offset: const Offset(0, -4),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(
                  left: 6,
                  bottom: 8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E8FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.image,
                      color: Color(0xFF673AB7),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Image selected',
                    ),
                    IconButton(
                      onPressed: _clearImage,
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: 'Image',
                onPressed: _loading
                    ? null
                    : _pickImage,
                icon: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 30,
                  color: Color(0xFF673AB7),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction:
                      TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _listening
                        ? '🎤 सुन रहा हूँ...'
                        : 'अपना सवाल लिखें...',
                    filled: true,
                    fillColor: const Color(0xFFF4EDFF),
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Voice',
                onPressed: _loading
                    ? null
                    : _startListening,
                icon: Icon(
                  _listening
                      ? Icons.stop_circle
                      : Icons.mic_none_rounded,
                  size: 31,
                  color: _listening
                      ? Colors.red
                      : const Color(0xFF673AB7),
                ),
              ),
              IconButton(
                tooltip: 'Send',
                onPressed:
                    _loading ? null : _sendMessage,
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
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'AI Personal Teacher',
          ),
          content: const Text(
            'आपका digital teacher\n\n'
            'Class-wise AI learning assistant.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
