import 'package:flutter/material.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service_mobile.dart';

void main() {
  runApp(const MLKitTestApp());
}

class MLKitTestApp extends StatefulWidget {
  const MLKitTestApp({super.key});

  @override
  State<MLKitTestApp> createState() => _MLKitTestAppState();
}

class _MLKitTestAppState extends State<MLKitTestApp> {
  final _service = ClientSideTranslationDelegateImpl();
  final _inputController = TextEditingController(text: 'Hello world');
  final _resultController = TextEditingController();
  String _selectedLanguage = 'es';
  bool _isLoading = false;
  String _status = 'Ready to test ML Kit';
  final List<String> _history = [];

  Future<void> _translate() async {
    setState(() {
      _isLoading = true;
      _status = 'Translating...';
      _resultController.clear();
    });

    final stopwatch = Stopwatch()..start();

    try {
      final result = await _service.translate(
        text: _inputController.text,
        targetLanguage: _selectedLanguage,
        sourceLanguage: 'en',
      );

      stopwatch.stop();

      setState(() {
        _resultController.text = result;
        _isLoading = false;
        _status = 'Success! (${stopwatch.elapsed.inMilliseconds}ms)';
        _history.add('"${_inputController.text}" → "$result" (${stopwatch.elapsed.inMilliseconds}ms)');
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isLoading = true;
      _status = 'Running automated tests...';
      _history.clear();
    });

    final tests = [
      {'text': 'Hello', 'lang': 'es', 'name': 'Spanish'},
      {'text': 'Thank you', 'lang': 'es', 'name': 'Spanish'},
      {'text': 'Goodbye', 'lang': 'fr', 'name': 'French'},
      {'text': 'How are you?', 'lang': 'es', 'name': 'Spanish'},
    ];

    for (final test in tests) {
      final text = test['text']! as String;
      final lang = test['lang']! as String;

      final stopwatch = Stopwatch()..start();

      try {
        final result = await _service.translate(
          text: text,
          targetLanguage: lang,
          sourceLanguage: 'en',
        );

        stopwatch.stop();

        setState(() {
          _history.add('✅ "$text" → "$result" (${stopwatch.elapsed.inMilliseconds}ms)');
        });
      } catch (e) {
        stopwatch.stop();
        setState(() {
          _history.add('❌ "$text" → Error: $e');
        });
      }
    }

    setState(() {
      _isLoading = false;
      _status = 'Tests complete! (${tests.length} translations)';
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _resultController.dispose();
    _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('ML Kit Translation Test'),
          backgroundColor: Colors.blue[700],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _status,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Enter English text:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _inputController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type English text here...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text('Target Language:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'bg', child: Text('Bulgarian')),
                  DropdownMenuItem(value: 'it', child: Text('Italian')),
                  DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                  DropdownMenuItem(value: 'ru', child: Text('Russian')),
                ],
                onChanged: (value) => setState(() => _selectedLanguage = value!),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _translate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Translate', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _runAllTests,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run Automated Tests'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Translation Result:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _resultController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Translation will appear here...',
                ),
                maxLines: 3,
                readOnly: true,
              ),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Test History:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List.generate(_history.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _history[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: _history[index].startsWith('✅') ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
