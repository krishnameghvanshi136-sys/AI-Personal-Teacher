import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() => runApp(const TeacherApp());

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AI Personal Teacher',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8F7FC),
        ),
        home: const TeacherPage(),
      );
}

class ChatMessage {
  final bool user;
  final String text;
  final String? imagePath;

  const ChatMessage({
    required this.user,
    required this.text,
    this.imagePath,
  });
}

class GeminiError implements Exception {
  final int code;
  final String message;

  GeminiError(this.code, this.message);

  @override
  String toString() => message;
}

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  static const apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const primaryModel = 'gemini-2.5-flash';
  static const fallbackModel = 'gemini-2.5-flash-lite';

  final input = TextEditingController();
  final scroll = ScrollController();
  final speech = stt.SpeechToText();
  final tts = FlutterTts();
  final picker = ImagePicker();

  final List<ChatMessage> chat = [];

  bool studyMode = true;
  bool loading = false;
  bool listening = false;
  bool speaking = false;
  bool speechReady = false;

  XFile? image;

  String selectedClass = 'कक्षा 5';
  String selectedSubject = 'गणित';

  final classes = List.generate(
    12,
    (i) => 'कक्षा ${i + 1}',
  );

  final subjects = const [
    'गणित',
    'विज्ञान',
    'हिंदी',
    'अंग्रेजी',
    'सामाजिक विज्ञान',
    'कंप्यूटर',
    'सामान्य ज्ञान',
  ];

  @override
  void initState() {
    super.initState();

    _initTts();
    _initSpeech();

    chat.add(
      const ChatMessage(
        user: false,
        text:
            'नमस्ते! 👋\n\n'
            'मैं आपका AI Personal Teacher हूँ।\n'
            'सवाल लिखें, 🎤 बोलें या 📷 फोटो भेजें।\n\n'
            'Study Mode में मैं step-by-step समझाऊँगा।',
      ),
    );
  }

  Future<void> _initTts() async {
    try {
      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(.45);
      await tts.setVolume(1);
      await tts.setPitch(1);

      tts.setStartHandler(() {
        if (mounted) {
          setState(() => speaking = true);
        }
      });

      tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => speaking = false);
        }
      });

      tts.setErrorHandler((_) {
        if (mounted) {
          setState(() => speaking = false);
        }
      });
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    try {
      speechReady = await speech.initialize(
        onStatus: (s) {
          if (mounted &&
              (s == 'done' || s == 'notListening')) {
            setState(() => listening = false);
          }
        },
        onError: (_) {
          if (mounted) {
            setState(() => listening = false);
          }
        },
      );

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      speechReady = false;
    }
  }

  Future<void> _mic() async {
    if (loading) return;

    if (!speechReady) {
      await _initSpeech();
    }

    if (!speechReady) {
      _snack(
        '🎤 Microphone permission Allow करें।',
      );
      return;
    }

    if (speech.isListening) {
      await speech.stop();

      if (mounted) {
        setState(() => listening = false);
      }

      return;
    }

    try {
      await tts.stop();

      setState(() => listening = true);

      await speech.listen(
        localeId: 'hi_IN',
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        onResult: (r) {
          if (!mounted) return;

          setState(() {
            input.text = r.recognizedWords;

            input.selection =
                TextSelection.collapsed(
              offset: input.text.length,
            );
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => listening = false);
      }

      _snack(
        '🎤 Voice input शुरू नहीं हो पाया।',
      );
    }
  }

  Future<void> _camera() async {
    try {
      final x = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (x != null && mounted) {
        setState(() => image = x);
      }
    } catch (_) {
      _snack(
        '📷 Camera permission Allow करें।',
      );
    }
  }

  Future<void> _gallery() async {
    try {
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (x != null && mounted) {
        setState(() => image = x);
      }
    } catch (_) {
      _snack(
        '🖼️ Gallery से फोटो नहीं मिल पाई।',
      );
    }
  }

  void _photoMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'फोटो भेजें',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text(
                'Camera से फोटो लें',
              ),
              onTap: () {
                Navigator.pop(context);
                _camera();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library),
              title: const Text(
                'Gallery से फोटो चुनें',
              ),
              onTap: () {
                Navigator.pop(context);
                _gallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (loading) return;

    final q = input.text.trim();

    if (q.isEmpty && image == null) {
      _snack(
        '✏️ पहले सवाल लिखें, बोलें या फोटो भेजें।',
      );
      return;
    }

    if (apiKey.trim().isEmpty) {
      _snack(
        '❌ GEMINI_API_KEY नहीं मिली।',
      );
      return;
    }

    if (speech.isListening) {
      await speech.stop();
    }

    await tts.stop();

    final imagePath = image?.path;

    setState(() {
      chat.add(
        ChatMessage(
          user: true,
          text: q.isEmpty
              ? 'इस फोटो को समझाकर बताइए।'
              : q,
          imagePath: imagePath,
        ),
      );

      input.clear();

      image = null;

      listening = false;

      loading = true;
    });

    _bottom();

    try {
      final result = await _ask(
        q,
        imagePath,
      );

      if (!mounted) return;

      setState(() {
        chat.add(
          ChatMessage(
            user: false,
            text: result,
          ),
        );

        loading = false;
      });

      _bottom();

      await _speak(
        _speechText(result),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        chat.add(
          ChatMessage(
            user: false,
            text: _friendly(e),
          ),
        );

        loading = false;
      });

      _bottom();
    }
  }

  Future<String> _ask(
    String q,
    String? imagePath,
  ) async {
    Object? last;

    for (final model in [
      primaryModel,
      fallbackModel,
    ]) {
      for (
        var attempt = 0;
        attempt < 3;
        attempt++
      ) {
        try {
          return _clean(
            await _request(
              model,
              q,
              imagePath,
            ),
          );
        } catch (e) {
          last = e;

          final code =
              e is GeminiError ? e.code : null;

          final retry =
              code == 408 ||
              code == 429 ||
              code == 500 ||
              code == 502 ||
              code == 503 ||
              code == 504;

          if (!retry) break;

          if (attempt < 2) {
            await Future.delayed(
              Duration(
                seconds: 1 << attempt,
              ),
            );
          }
        }
      }
    }

    throw last ??
        Exception(
          'Gemini से जवाब नहीं मिला।',
        );
  }

  Future<String> _request(
    String model,
    String q,
    String? imagePath,
  ) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/'
      'v1beta/models/$model:generateContent',
    );

    final parts =
        <Map<String, dynamic>>[];

    if (imagePath != null) {
      final f = File(imagePath);

      if (await f.exists()) {
        final ext = imagePath
            .split('.')
            .last
            .toLowerCase();

        final mime =
            ext == 'png'
                ? 'image/png'
                : ext == 'webp'
                    ? 'image/webp'
                    : 'image/jpeg';

        parts.add({
          'inlineData': {
            'mimeType': mime,
            'data': base64Encode(
              await f.readAsBytes(),
            ),
          },
        });
      }
    }

    parts.add({
      'text': '''
आप AI Personal Teacher हैं।

कक्षा: $selectedClass
विषय: $selectedSubject
Study Mode: ${studyMode ? 'ON' : 'OFF'}

${studyMode ? '''
विद्यार्थी को teacher की तरह समझाएँ।

पहले सही उत्तर दें।

फिर आसान concept समझाएँ।

फिर step-by-step solution दें।

जरूरत होने पर example दें।

अंत में एक छोटा practice question दें।
''' : '''
सीधा, सही और संक्षिप्त उत्तर दें।
जरूरत होने पर छोटी explanation दें।
'''}

महत्वपूर्ण नियम:

- आसान हिंदी रखें।
- विद्यार्थी को confuse न करें।
- गणित में calculation step-by-step दिखाएँ।
- फोटो में सवाल हो तो ध्यान से पढ़ें।
- फोटो साफ न हो तो अनुमान न लगाएँ।
- **, ##, ### जैसे Markdown symbols न दिखाएँ।
- अनावश्यक technical/API जानकारी न दें।
- अगर यह follow-up question है तो बातचीत के context को ध्यान में रखें।
- गलत जानकारी न दें।

Student का सवाल:

${q.isEmpty ? 'फोटो में दिए सवाल को समझाकर बताइए।' : q}
''',
    });

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type':
                'application/json',
            'x-goog-api-key':
                apiKey.trim(),
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': parts,
              }
            ],
            'generationConfig': {
              'maxOutputTokens': 1200,
            },
          }),
        )
        .timeout(
          const Duration(seconds: 45),
        );

    if (response.statusCode != 200) {
      String msg =
          'Gemini API Error '
          '${response.statusCode}';

      try {
        msg = (
          jsonDecode(response.body)['error']
              ?['message'] ??
          msg
        ).toString();
      } catch (_) {}

      throw GeminiError(
        response.statusCode,
        msg,
      );
    }

    final data =
        jsonDecode(response.body);

    final candidates =
        data['candidates'];

    if (candidates is! List ||
        candidates.isEmpty) {
      throw Exception(
        'Gemini ने कोई जवाब नहीं दिया।',
      );
    }

    final p =
        candidates[0]['content']?['parts'];

    if (p is! List || p.isEmpty) {
      throw Exception(
        'Gemini response खाली है।',
      );
    }

    final out = StringBuffer();

    for (final x in p) {
      if (x is Map &&
          x['text'] is String) {
        out.write(
          '${x['text']}\n',
        );
      }
    }

    final result =
        out.toString().trim();

    if (result.isEmpty) {
      throw Exception(
        'Gemini ने text answer नहीं दिया।',
      );
    }

    return result;
  }

  String _clean(String s) {
    return s
        .replaceAll('**', '')
        .replaceAll('###', '')
        .replaceAll('##', '')
        .replaceAll(
          RegExp(r'\n{3,}'),
          '\n\n',
        )
        .trim();
  }

  String _speechText(String s) {
    return s
        .replaceAll('**', '')
        .replaceAll('###', '')
        .replaceAll('##', '')
        .replaceAll('#', '')
        .trim();
  }

  String _friendly(Object e) {
    if (e is GeminiError) {
      if (e.code == 429) {
        return 'अभी AI service पर बहुत ज्यादा requests हैं। '
            'थोड़ी देर बाद फिर कोशिश करें।';
      }

      if (e.code == 503) {
        return 'अभी AI server busy है। '
            'मैंने दूसरा model भी try किया। '
            'थोड़ी देर बाद फिर कोशिश करें।';
      }

      if (e.code == 401 ||
          e.code == 403) {
        return 'AI service की permission/API key में समस्या है।';
      }

      if (e.code == 404) {
        return 'AI model अभी उपलब्ध नहीं है।';
      }
    }

    final s = e.toString();

    if (s.contains('SocketException') ||
        s.contains('Timeout') ||
        s.contains('Network')) {
      return 'Internet connection में समस्या है। '
          'Internet check करके फिर कोशिश करें।';
    }

    return 'अभी जवाब नहीं मिल पाया। '
        'कृपया फिर कोशिश करें।';
  }

  Future<void> _speak(String text) async {
    try {
      await tts.stop();

      await tts.setLanguage(
        'hi-IN',
      );

      await tts.setSpeechRate(
        .45,
      );

      await tts.speak(text);
    } catch (_) {}
  }

  Future<void> _stopVoice() async {
    await tts.stop();

    if (mounted) {
      setState(
        () => speaking = false,
      );
    }
  }

  void _newChat() {
    tts.stop();

    setState(() {
      chat.clear();

      input.clear();

      image = null;

      loading = false;

      chat.add(
        const ChatMessage(
          user: false,
          text:
              'नई चैट शुरू हो गई। 👋\n\n'
              'अपना अगला सवाल पूछें।',
        ),
      );
    });

    _bottom();
  }

  void _bottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 300,
          ),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String s) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    input.dispose();

    scroll.dispose();

    speech.stop();

    tts.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(
        appBar: AppBar(
          backgroundColor:
              Colors.transparent,
          titleSpacing: 14,
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Personal Teacher',
                      style: TextStyle(
                        fontSize: 18,
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
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'नई चैट',
              onPressed:
                  loading ? null : _newChat,
              icon: const Icon(
                Icons.add_comment_outlined,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'new') {
                  _newChat();
                }

                if (v == 'stop') {
                  _stopVoice();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'new',
                  child: Text('नई चैट'),
                ),
                PopupMenuItem(
                  value: 'stop',
                  child: Text(
                    'Voice बंद करें',
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            _controls(),

            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding:
                    const EdgeInsets.fromLTRB(
                  12,
                  10,
                  12,
                  18,
                ),
                itemCount:
                    chat.length +
                        (loading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == chat.length) {
                    return _loadingBubble();
                  }

                  return _bubble(
                    chat[i],
                  );
                },
              ),
            ),

            _inputBar(),
          ],
        ),
      );

  Widget _controls() =>
      Container(
        margin:
            const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        padding:
            const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color:
                Colors.black.withOpacity(.06),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(
                  width: 8,
                ),
                const Expanded(
                  child: Text(
                    'Study Mode',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: studyMode,
                  onChanged: loading
                      ? null
                      : (v) {
                          setState(
                            () => studyMode =
                                v,
                          );
                        },
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child:
                      DropdownButtonFormField<
                          String>(
                    value: selectedClass,
                    isDense: true,
                    decoration:
                        const InputDecoration(
                      labelText: 'कक्षा',
                      border:
                          OutlineInputBorder(),
                    ),
                    items: classes
                        .map(
                          (x) =>
                              DropdownMenuItem(
                            value: x,
                            child: Text(x),
                          ),
                        )
                        .toList(),
                    onChanged: loading
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(
                                () =>
                                    selectedClass =
                                        v,
                              );
                            }
                          },
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child:
                      DropdownButtonFormField<
                          String>(
                    value:
                        selectedSubject,
                    isDense: true,
                    decoration:
                        const InputDecoration(
                      labelText: 'विषय',
                      border:
                          OutlineInputBorder(),
                    ),
                    items: subjects
                        .map(
                          (x) =>
                              DropdownMenuItem(
                            value: x,
                            child: Text(
                              x,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: loading
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(
                                () =>
                                    selectedSubject =
                                        v,
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _bubble(
    ChatMessage m,
  ) =>
      Align(
        alignment: m.user
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          constraints:
              const BoxConstraints(
            maxWidth: 370,
          ),
          margin: EdgeInsets.only(
            left: m.user ? 48 : 4,
            right: m.user ? 4 : 48,
            bottom: 10,
          ),
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: m.user
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                : Colors.white,
            borderRadius:
                BorderRadius.only(
              topLeft:
                  const Radius.circular(
                20,
              ),
              topRight:
                  const Radius.circular(
                20,
              ),
              bottomLeft:
                  Radius.circular(
                m.user ? 20 : 5,
              ),
              bottomRight:
                  Radius.circular(
                m.user ? 5 : 20,
              ),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 5,
                color:
                    Colors.black.withOpacity(
                  .05,
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    m.user
                        ? Icons.person_rounded
                        : Icons.school_rounded,
                    size: 18,
                    color: m.user
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                        : Colors.deepPurple,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    m.user
                        ? 'आप'
                        : 'Teacher',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),

              if (m.imagePath != null) ...[
                const SizedBox(
                  height: 9,
                ),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  child: Image.file(
                    File(
                      m.imagePath!,
                    ),
                    height: 180,
                    width:
                        double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              const SizedBox(
                height: 8,
              ),

              SelectableText(
                m.text,
                style:
                    const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              if (!m.user)
                Align(
                  alignment:
                      Alignment.centerRight,
                  child: IconButton(
                    visualDensity:
                        VisualDensity
                            .compact,
                    onPressed: () =>
                        _speak(
                      _speechText(
                        m.text,
                      ),
                    ),
                    icon: Icon(
                      Icons
                          .volume_up_rounded,
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _loadingBubble() =>
      Align(
        alignment:
            Alignment.centerLeft,
        child: Container(
          margin:
              const EdgeInsets.only(
            left: 4,
            right: 80,
            bottom: 10,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          decoration:
              BoxDecoration(
            color: Colors.white,
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
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                'Teacher सोच रहा है...',
              ),
            ],
          ),
        ),
      );

  Widget _inputBar() =>
      SafeArea(
        top: false,
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(
            7,
            7,
            7,
            7,
          ),
          decoration:
              BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                color:
                    Colors.black.withOpacity(
                  .08,
                ),
                offset:
                    const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (image != null)
                Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 6,
                  ),
                  padding:
                      const EdgeInsets.all(
                    6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF0EDF5,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          8,
                        ),
                        child:
                            Image.file(
                          File(
                            image!.path,
                          ),
                          width: 55,
                          height: 55,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      const Expanded(
                        child: Text(
                          'फोटो तैयार है',
                        ),
                      ),
                      IconButton(
                        onPressed:
                            loading
                                ? null
                                : () {
                                    setState(
                                      () =>
                                          image =
                                              null,
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
                    tooltip: 'फोटो',
                    onPressed: loading
                        ? null
                        : _photoMenu,
                    icon:
                        const Icon(
                      Icons
                          .add_a_photo_outlined,
                      size: 28,
                    ),
                  ),

                  Expanded(
                    child: TextField(
                      controller: input,
                      enabled: !loading,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization:
                          TextCapitalization
                              .sentences,
                      decoration:
                          InputDecoration(
                        hintText: listening
                            ? '🎤 सुन रहा हूँ...'
                            : 'अपना सवाल लिखें...',
                        filled: true,
                        fillColor:
                            const Color(
                          0xFFF3F1F7,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            25,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Mic',
                    onPressed: loading
                        ? null
                        : _mic,
                    icon: Icon(
                      listening
                          ? Icons.mic_rounded
                          : Icons
                              .mic_none_rounded,
                      color: listening
                          ? Colors.red
                          : Theme.of(
                              context,
                            )
                              .colorScheme
                              .primary,
                      size: 31,
                    ),
                  ),

                  IconButton(
                    tooltip: 'Send',
                    onPressed: loading
                        ? null
                        : _send,
                    icon: Icon(
                      Icons
                          .send_rounded,
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .primary,
                      size: 31,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
