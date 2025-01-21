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
  Map<String, String>? _translatedTexts; // Map to store multiple translations
  TextEditingController _textController = TextEditingController();
  List<Translation> _history = [];
  List<Translation> _favorites = [];
  bool _isTranslating = false;
  final String apiKey =
      'AIzaSyBzXii5o0s_xAUHz8CfLqAgQACaNCYVsjg'; // Replace with your actual Gemini API key
  late GenerativeModel _model;
  String _selectedLanguage = 'English';
  List<String> _selectedDestinationLanguages = ['English']; // Multiple selections

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
      _history = historyJson
          .map((e) => Translation.fromJson(jsonDecode(e)))
          .toList();
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
      _translatedTexts = null; // Reset to null while translating
    });

    try {
      // Create a single prompt with all languages
      String prompt =
          'define, Translate, grammer, examples of all scenarios the following text from $_selectedLanguage to  all languages between the 2 braces(${_selectedDestinationLanguages.join(', ')}): ${_textController.text}';
      final content = Content.text(prompt);

      final generateResponse = await _model.generateContent([content]);
      print(prompt);
      print(generateResponse.text);
      Map<String, String> translatedTexts = {};
      if (generateResponse.text != null) {
          // Parse the translation
           List<String> translations =  _parseTranslations(generateResponse.text!);
           if (translations.length == _selectedDestinationLanguages.length) {
              for (int i = 0; i < _selectedDestinationLanguages.length; i++) {
                 translatedTexts[_selectedDestinationLanguages[i]] = translations[i];
              }
          } else {
           throw Exception("Translation failed: The API does not return the correct number of responses");
          }
      } else {
          throw Exception("Translation failed");
      }
      setState(() {
         _isTranslating = false;
         _translatedTexts = {...translatedTexts}; // Use spread operator
         if (_translatedTexts != null) {
           final translation = Translation(
              originalText: _textController.text,
              translatedText: _translatedTexts.toString());
           _history.insert(0, translation);
           _saveData();
         }
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

// Helper method to parse translation
  List<String> _parseTranslations(String response) {
    // Split the response into parts based on language
    List<String> translations = [];
    // Implement your parsing logic here to extract individual translations
    // Example:
    var parts = response.split(RegExp(r'\[(English|Arabic|Swedish)\]:'));
      for(int i = 1; i< parts.length; i++){
           translations.add(parts[i].trim());
      }
    return translations;
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
            child: TabBar(
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
                child: _translatedTexts != null ?
                   ListView.builder(
                      itemCount: _translatedTexts!.length,
                       itemBuilder: (context, index) {
                          final language = _translatedTexts!.keys.elementAt(index);
                          final translation =  _translatedTexts![language]!;
                           return Card(
                             child: Padding(
                               padding: const EdgeInsets.only(
                                   top: 12, left: 16, right: 16, bottom: 12),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(language, style: const TextStyle(fontWeight: FontWeight.bold),),
                                 const SizedBox(height: 8),
                                 Text(translation,
                                     style: const TextStyle(fontSize: 16)),
                               ]
                             ),
                            ),
                            );
                       }
                    )
              : Container()

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
                selected: _selectedDestinationLanguages.contains(language),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedDestinationLanguages.add(language);
                    } else {
                      _selectedDestinationLanguages.remove(language);
                    }
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
              title: Row(
                children: [
                  Expanded(
                    child: Text(favorite.originalText),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _favorites.removeAt(index);
                        _saveData();
                      });
                    },
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: SingleChildScrollView(
                      child: Text(favorite.translatedText,
                          style: const TextStyle(fontSize: 16))),
                ),
              ]
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
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(child: Text(historyItem.originalText)),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      _history.removeAt(index);
                      _saveData();
                    });
                  },
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: SingleChildScrollView(
                  child: Text(historyItem.translatedText,
                      style: const TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}