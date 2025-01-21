// lib/main.dart
//import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
void main() {
  runApp(const TranslatorApp());
}

class TranslatorApp extends StatelessWidget {
  const TranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Translator App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TranslatorHome(),
    );
  }
}

// Models
class TranslationResult {
  final String word;
  final Map<String, String> definitions;
  final Map<String, List<String>> synonyms;
  final Map<String, List<String>> antonyms;
  final Map<String, Map<String, String>> conjugation;
  final List<Example> examples;

  TranslationResult({
    required this.word,
    required this.definitions,
    required this.synonyms,
    required this.antonyms,
    required this.conjugation,
    required this.examples,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      word: json['word'] ?? '',
      definitions: Map<String, String>.from(json['definitions'] ?? {}),
      synonyms: Map<String, List<String>>.from(
        (json['synonyms'] ?? {}).map(
          (k, v) => MapEntry(k, List<String>.from(v ?? [])),
        ),
      ),
      antonyms: Map<String, List<String>>.from(
        (json['antonyms'] ?? {}).map(
          (k, v) => MapEntry(k, List<String>.from(v ?? [])),
        ),
      ),
      conjugation: Map<String, Map<String, String>>.from(
        (json['conjugation'] ?? {}).map(
          (k, v) => MapEntry(
            k,
            Map<String, String>.from(v ?? {}),
          ),
        ),
      ),
      examples: (json['examples'] as List? ?? [])
          .map((e) => Example.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'definitions': definitions,
        'synonyms': synonyms,
        'antonyms': antonyms,
        'conjugation': conjugation,
        'examples': examples.map((e) => e.toJson()).toList(),
      };
}

class Example {
  final String scenario;
  final String english;
  final String swedish;
  final String arabic;

  Example({
    required this.scenario,
    required this.english,
    required this.swedish,
    required this.arabic,
  });

  factory Example.fromJson(Map<String, dynamic> json) {
    return Example(
      scenario: json['scenario'] ?? '',
      english: json['english'] ?? '',
      swedish: json['swedish'] ?? '',
      arabic: json['arabic'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'scenario': scenario,
        'english': english,
        'swedish': swedish,
        'arabic': arabic,
      };
}

// Services
class TranslationService {
  final GenerativeModel model;
  //final SharedPreferences prefs;
  
  TranslationService({required String apiKey}) 
      : model = GenerativeModel(
          model: 'gemini-2.0-flash-exp',
          apiKey: apiKey,
          generationConfig: GenerationConfig(responseMimeType: "application/json")
        );

  Future<TranslationResult> translate(String text, String fromLang) async {
    try {
      // Check offline cache first
      final cachedResult = await _checkCache(text, fromLang);
      if (cachedResult != null) {
        return cachedResult;
      }

      final prompt = '''
        Translate the word "$text" from $fromLang and provide detailed information in all three languages (English, Swedish, Arabic) in this JSON format:
        {
          "word": "$text",
          "definitions": {
            "english": "",
            "swedish": "",
            "arabic": ""
          },
          "synonyms": {
            "english": [],
            "swedish": [],
            "arabic": []
          },
          "antonyms": {
            "english": [],
            "swedish": [],
            "arabic": []
          },
          "conjugation": {...},
          "examples": [10 examples with different scenarios]
        }
      ''';

      final content = Content.text(prompt);
      final response = await model.generateContent([content]);
      
      if (response.text == null) {
        throw Exception('Empty response from API');
      }

      Map<String, dynamic> jsonResponse;
      try {
        jsonResponse = json.decode(response.text!);
      } catch (e) {
        throw Exception('Invalid JSON response: $e');
      }

      // Validate JSON structure
      _validateJsonResponse(jsonResponse);

      final result = TranslationResult.fromJson(jsonResponse);
      
      // Cache the result
      await _cacheTranslation(text, fromLang, result);
      
      // Save to history
      await _saveToHistory(result);

      return result;
    } catch (e) {
      throw Exception('Translation failed: $e');
    }
  }

  void _validateJsonResponse(Map<String, dynamic> json) {
    final requiredFields = [
      'word',
      'definitions',
      'synonyms',
      'antonyms',
      'conjugation',
      'examples'
    ];

    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        throw Exception('Missing required field: $field');
      }
    }

    // Validate definitions
    final definitions = json['definitions'];
    if (definitions is! Map) {
      throw Exception('Invalid definitions format');
    }

    // Add more specific validations as needed
  }

  Future<TranslationResult?> _checkCache(String text, String fromLang) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString('${text}_${fromLang}_cache');
    
    if (cacheJson != null) {
      final cache = TranslationCache.fromJson(json.decode(cacheJson));
      
      // Check if cache is still valid (e.g., less than 24 hours old)
      if (DateTime.now().difference(cache.timestamp).inHours < 24) {
        return cache.result;
      }
    }
    return null;
  }

  Future<void> _cacheTranslation(
    String text,
    String fromLang,
    TranslationResult result,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = TranslationCache(
      word: text,
      fromLang: fromLang,
      result: result,
      timestamp: DateTime.now(),
    );
    
    await prefs.setString(
      '${text}_${fromLang}_cache',
      json.encode(cache.toJson()),
    );
  }

  Future<void> _saveToHistory(TranslationResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('history') ?? [];
    
    // Add to beginning of history, limit to 100 items
    history.insert(0, json.encode(result.toJson()));
    if (history.length > 100) {
      history.removeLast();
    }
    
    await prefs.setStringList('history', history);
  }
}




// Screens
class TranslatorHome extends StatefulWidget {
  const TranslatorHome({super.key});

  @override
  State<TranslatorHome> createState() => _TranslatorHomeState();
}
 
  //TranslationService? _service;//test

// Modified TranslatorHome
class _TranslatorHomeState extends State<TranslatorHome> {
  final TextEditingController _textController = TextEditingController();
  TranslationResult? _result;
 TranslationService? _service=TranslationService(apiKey: 'AIzaSyBzXii5o0s_xAUHz8CfLqAgQACaNCYVsjg');//test
  String _fromLang = 'English';
  List<TranslationResult> _favorites = [];
  List<TranslationResult> _history = [];
  bool _isLoading = false;

    Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = _favorites
        .map((result) => jsonEncode(result.toJson()))
        .toList();
    await prefs.setStringList('favorites', favoritesJson);
  }
  void _toggleFavorite(TranslationResult result) {
    setState(() {
      if (_favorites.any((f) => f.word == result.word)) {
        _favorites.removeWhere((f) => f.word == result.word);
      } else {
        _favorites.add(result);
      }
    });
    _saveFavorites();
  }
  
    Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList('favorites') ?? [];
    setState(() {
      _favorites = favoritesJson
          .map((json) => TranslationResult.fromJson(jsonDecode(json)))
          .toList();
    });
  }
  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadFavorites();
    _loadHistory();
  }

  Future<void> _initializeService() async {
    final apiKey = await SharedPrefsService.getApiKey();
    print("API Key retrieved-----------------------------------------------------------: ${apiKey != null}"); // Debug print
    if (apiKey != null) {
      setState(() {
        _service = TranslationService(apiKey: apiKey);
      });
        print("Service initialized+++++++++++++++++++++++++++++++++++++++++++++++++++++: ${_service != null}"); 
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('history') ?? [];
    setState(() {
      _history = historyJson
          .map((json) => TranslationResult.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final result = _history[index];
        return ListTile(
          title: Text(result.word),
          subtitle: Text(result.definitions['english'] ?? ''),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _favorites.any((f) => f.word == result.word)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                color: Colors.red,
                onPressed: () => _toggleFavorite(result),
              ),
              IconButton(
                icon: Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: result.definitions['english'] ?? '',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ],
          ),
          onTap: () => _showTranslationDialog(result),
        );
      },
    );
  }
    Widget _buildTranslationResult(TranslationResult result) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                result.word,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: Icon(
                  _favorites.any((f) => f.word == result.word)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                color: Colors.red,
                onPressed: () => _toggleFavorite(result),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Definitions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...result.definitions.entries.map(
            (e) => ListTile(
              title: Text(e.key.capitalize()),
              subtitle: Text(e.value),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Conjugation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...result.conjugation.entries.map(
            (lang) => ExpansionTile(
              title: Text(lang.key.capitalize()),
              children: lang.value.entries.map(
                (conj) => ListTile(
                  title: Text(conj.key.replaceAll('_', ' ').capitalize()),
                  subtitle: Text(conj.value),
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Examples',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...result.examples.map(
            (example) => ExpansionTile(
              title: Text(example.scenario),
              children: [
                ListTile(
                  title: const Text('English'),
                  subtitle: Text(example.english),
                ),
                ListTile(
                  title: const Text('Swedish'),
                  subtitle: Text(example.swedish),
                ),
                ListTile(
                  title: const Text('Arabic'),
                  subtitle: Text(example.arabic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTranslationDialog(TranslationResult result) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTranslationResult(result),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildFavoritesTab() {
    return ListView.builder(
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final result = _favorites[index];
        return ListTile(
          title: Text(result.word),
          subtitle: Text(result.definitions[''] ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.favorite),
            color: Colors.red,
            onPressed: () => _toggleFavorite(result),
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildTranslationResult(result),
                ),
              ),
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Translator'),
          actions: [
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen()),
                );
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Translate'),
              Tab(text: 'History'),
              Tab(text: 'Favorites'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTranslateTab(),
            _buildHistoryTab(),
            _buildFavoritesTab(),
          ],
        ),
      ),
    );
  }

Widget _buildTranslateTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButton<String>(
            value: _fromLang,
            items: ['English', 'Swedish', 'Arabic']
                .map((lang) => DropdownMenuItem(
                      value: lang,
                      child: Text(lang),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => _fromLang = value!);
            },
          ),
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: 'Enter text to translate',
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _service == null || _isLoading ? null:
                 
            () async {
                    if (_textController.text.isEmpty) return;
                    setState(() => _isLoading = true);
                    try {
                      final result = await _service!.translate(
                        _textController.text,
                        _fromLang,
                      );
                      //print("-------------------------"+result.toJson().jsify().toString());
                      setState(() {
                        _result = result;
                        _isLoading = false;
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Translation failed: $e')),
                      );
                      setState(() => _isLoading = false);
                    }
                  },
            child: _isLoading
                ? CircularProgressIndicator()
                : Text(_service == null ? 'Set API Key' : 'Translate'),
          ),
          if (_result != null) ...[
            SizedBox(height: 16),
            Expanded(
              child: _buildTranslationResult(_result!),
            ),
          ],
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}class SharedPrefsService {
  static const String _apiKeyKey = 'api_key';
  static const String _historyKey = 'history';
  static const String _offlineCacheKey = 'offline_cache';



  static Future<String?> getCachedTranslation(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_offlineCacheKey}_$cacheKey');
  }

  static Future<void> cacheTranslation(String cacheKey, String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_offlineCacheKey}_$cacheKey', data);
  }

  
    static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }
  

  static Future<void> saveHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, history);
  }
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }
  
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
    //_service = TranslationService(apiKey: apiKey);
  }
  
  static Future<void> deleteApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
  }
}
class TranslationCache {
  final String word;
  final String fromLang;
  final TranslationResult result;
  final DateTime timestamp;

  TranslationCache({
    required this.word,
    required this.fromLang,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'word': word,
    'fromLang': fromLang,
    'result': result.toJson(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory TranslationCache.fromJson(Map<String, dynamic> json) {
    return TranslationCache(
      word: json['word'],
      fromLang: json['fromLang'],
      result: TranslationResult.fromJson(json['result']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
// lib/screens/settings_screen.dart
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final apiKey = await SharedPrefsService.getApiKey();
    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.save),
                        onPressed: () async {
                          await SharedPrefsService.saveApiKey(
                            _apiKeyController.text,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('API Key saved')),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await SharedPrefsService.deleteApiKey();
                      setState(() => _apiKeyController.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('API Key deleted')),
                      );
                    },
                    child: Text('Delete API Key'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('All data cleared')),
                      );
                    },
                    child: Text('Clear All Data'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}