import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart';
class Translation {
  final String originalText;
  final String translatedText;

  Translation({required this.originalText, required this.translatedText});

  Map<String, dynamic> toJson() => {
        'originalText': originalText,
        'translatedText': translatedText,
      };

  factory Translation.fromJson(Map<String, dynamic> json) {
    return Translation(
        originalText: json['originalText'],
        translatedText: json['translatedText']);
  }
}

void main() {
  runApp(TranslatorApp());
}

class TranslatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Translator App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TranslatorHomePage(),
    );
  }
}

class TranslatorHomePage extends StatefulWidget {
  @override
  _TranslatorHomePageState createState() => _TranslatorHomePageState();
}

class _TranslatorHomePageState extends State<TranslatorHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Translation? _translatedText;
  TextEditingController _textController = TextEditingController();
  List<Translation> _history = [];
  List<Translation> _favorites = [];
  bool _isTranslating = false;
  final String apiKey =
      'AIzaSyBzXii5o0s_xAUHz8CfLqAgQACaNCYVsjg'; // Replace with your actual Gemini API key
    late GenerativeModel _model;
  String _selectedLanguage = 'English';
    String _selectedDestinationLanguage = 'English';


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: apiKey);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // Method to save data to local storage
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = _history.map((e) => jsonEncode(e.toJson())).toList();
    final favoriteJson = _favorites.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('history', historyJson);
    await prefs.setStringList('favorites', favoriteJson);
  }

  // Method to retrieve data from local storage
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('history');
    final favoritesJson = prefs.getStringList('favorites');

    if (historyJson != null) {
      _history =
          historyJson.map((e) => Translation.fromJson(jsonDecode(e))).toList();
    }
    if (favoritesJson != null) {
      _favorites = favoritesJson
          .map((e) => Translation.fromJson(jsonDecode(e)))
          .toList();
    }
    setState(() {});
  }

  Future<void> _translateText() async {
    if (_textController.text.isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

     try {
      final prompt =
          'Define, Translate, grammer, examples of all scenarios can be used the following text from $_selectedLanguage to $_selectedDestinationLanguage: ${_textController.text}';
      final content = Content.text(prompt);

      final generateResponse = await _model.generateContent([content]);
    
      String translatedText = "";
      if (generateResponse.text != null) {
        translatedText = generateResponse.text!;
      } else {
        throw Exception("Translation Failed");
      }

      setState(() {
        _isTranslating = false;
        final translation = Translation(
            originalText: _textController.text, translatedText: translatedText);
        _translatedText = translation;
        _history.insert(0, translation);
        _saveData();
        _textController.clear();
      });
    } catch (e) {
      setState(() {
        _isTranslating = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error translating text: $e')),
        );
      });
    }
  }


  void _toggleFavorite(Translation translation) {
    setState(() {
      if (_favorites.contains(translation)) {
        _favorites.remove(translation);
      } else {
        _favorites.add(translation);
      }
      _saveData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Translator App'),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTranslateTab(),
                _buildFavoritesTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
          Container(
           color: Colors.grey[200],
            child:  TabBar(
                controller: _tabController,
                tabs: [
                  Tab(icon: Icon(Icons.translate), text: "Translate"),
                  Tab(icon: Icon(Icons.favorite), text: "Favorites"),
                  Tab(icon: Icon(Icons.history), text: "History"),
                ],
              ),
          )
        ],
      ),
    );
  }

Widget _buildTranslateTab() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        Expanded(
          child: _translatedText != null
              ? Card(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 12, left: 16, right: 50, bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: _translatedText!.translatedText));
                              ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied to Clipboard!')),
                             );
                          },
                          child: SingleChildScrollView(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _translatedText!.translatedText,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _translatedText!.originalText,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ]),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: Icon(
                            _favorites.contains(_translatedText)
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          onPressed: () => _toggleFavorite(_translatedText!),
                        ),
                      )
                    ],
                  ),
                )
              : Container(),
        ),
        if (_isTranslating)
          const Center(
            child: CircularProgressIndicator(),
          ),
        SizedBox(height: 16.0),
        Wrap(
          spacing: 8.0, // Spacing between tags
          children: ['English', 'Arabic', 'Swedish'].map((language) {
            return FilterChip(
              label: Text(language),
              selected: _selectedDestinationLanguage == language,
              onSelected: (bool selected) {
                setState(() {
                  _selectedDestinationLanguage = language;
                });
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.0),
        Row(
          children: [
            DropdownButton<String>(
              value: _selectedLanguage,
              items: <String>['English', 'Arabic', 'Swedish']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedLanguage = newValue;
                  });
                }
              },
            ),
            SizedBox(width: 16.0),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter text to translate',
                ),
                onSubmitted: (value) {
                  _translateText();
                },
              ),
            )
          ],
        ),
        SizedBox(height: 16.0),
      ],
    ),
  );
}

    Widget _buildFavoritesTab() {
    return ListView.builder(
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        return Card(
          child: ExpansionTile(
            title: Text(favorite.originalText),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Stack(
                  children: [
                    Padding(
                       padding: const EdgeInsets.only(right: 48),
                      child: SingleChildScrollView(
                        child: Text(favorite.translatedText,
                          style: const TextStyle(fontSize: 16)
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _favorites.removeAt(index);
                            _saveData();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
     return ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final historyItem = _history[index];
            return Card(
              child:  ExpansionTile(
              title: Text(historyItem.originalText),
               children: [
                 Padding(
                   padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                   child: Stack(
                     children: [
                       Padding(
                           padding: const EdgeInsets.only(right: 48),
                           child: SingleChildScrollView(
                            child: Text(historyItem.translatedText,
                                style: const TextStyle(fontSize: 16)
                            ),
                          ),
                         ),
                      Positioned(
                        top: 0,
                        right: 0,
                         child: IconButton(
                            icon: Icon(
                             _favorites.contains(historyItem)
                                ? Icons.favorite
                                : Icons.favorite_border,
                           ),
                          onPressed: () => _toggleFavorite(historyItem),
                        ),
                      ),
                     ],
                   ),
                 ),
               ],
          ),
        );
      },
    );
  }
}