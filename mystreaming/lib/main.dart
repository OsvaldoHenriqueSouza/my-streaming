// @dart=2.17

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';

part 'main.g.dart';

@HiveType(typeId: 0)
class Media extends HiveObject {
  @HiveField(0)
  String imdbID;

  @HiveField(1)
  String title;

  @HiveField(2)
  String year;

  @HiveField(3)
  String poster;

  @HiveField(4)
  int rating;

  @HiveField(5)
  String status;

  Media({
    required this.imdbID,
    required this.title,
    required this.year,
    required this.poster,
    this.rating = 0,
    this.status = 'Não Assistido',
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      imdbID: json['imdbID'] ?? '',
      title: json['Title'] ?? 'N/A',
      year: json['Year'] ?? 'N/A',
      poster: json['Poster'] ?? 'https://via.placeholder.com/150',
    );
  }
}

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(MediaAdapter());
  await Hive.openBox<Media>('myMediaBox');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyStreaming',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black87,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final String _apiKey = "6a7de593";
  final TextEditingController _searchController = TextEditingController();
  List<Media> _searchResults = [];
  final List<String> _statuses = ['Assistido', 'Não Assistido', 'Pretendo Assistir'];

  Future<void> _searchMedia(String query) async {
    if (query.isEmpty) {
      return;
    }
    final response = await http.get(Uri.parse(
        'https://www.omdbapi.com/?s=$query&apikey=$_apiKey&r=json&page=1'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['Response'] == 'True') {
        setState(() {
          _searchResults = (data['Search'] as List)
              .map((item) => Media.fromJson(item))
              .toList();
        });
      } else {
        setState(() {
          _searchResults = [];
        });
        _showSnackbar('Nenhum resultado encontrado.');
      }
    } else {
      _showSnackbar('Erro ao buscar dados da API. Código: ${response.statusCode}');
    }
  }

  void _addMedia(Media media) {
    final box = Hive.box<Media>('myMediaBox');
    bool exists = box.values.any((m) => m.imdbID == media.imdbID);
    if (!exists) {
      box.add(media);
      _showSnackbar('"${media.title}" adicionado(a) à sua lista!');
    } else {
      _showSnackbar('"${media.title}" já está na sua lista.');
    }
    setState(() {});
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    Hive.box('myMediaBox').close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Media>('myMediaBox');

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyStreaming', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar filmes ou séries...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[800],
              ),
              onSubmitted: (query) => _searchMedia(query),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16.0),
            if (_searchResults.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resultados da Pesquisa',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8.0),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final media = _searchResults[index];
                          return _buildMediaCard(
                            media,
                            isSearchResult: true,
                            onAdd: () => _addMedia(media),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Minha Lista',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8.0),
                    Expanded(
                      child: ListView.builder(
                        itemCount: box.length,
                        itemBuilder: (context, index) {
                          final media = box.getAt(index)!;
                          return _buildMediaCard(
                            media,
                            isSearchResult: false,
                            onUpdate: (updatedMedia) async {
                              await box.putAt(index, updatedMedia);
                              setState(() {});
                            },
                            onDelete: () {
                              box.deleteAt(index);
                              _showSnackbar('"${media.title}" removido(a) da sua lista.');
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard(
      Media media, {
        required bool isSearchResult,
        VoidCallback? onAdd,
        Function(Media)? onUpdate,
        VoidCallback? onDelete,
      }) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                media.poster,
                width: 100,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 100,
                  height: 150,
                  color: Colors.grey[700],
                  child: const Icon(Icons.broken_image, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Ano: ${media.year}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  if (!isSearchResult) ...[
                    _buildStatusDropdown(media, onUpdate),
                    const SizedBox(height: 8.0),
                    _buildRatingStars(media, onUpdate),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Excluir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar à Minha Lista'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(Media media, Function(Media)? onUpdate) {
    return DropdownButton<String>(
      value: media.status,
      items: _statuses.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null && onUpdate != null) {
          media.status = newValue;
          onUpdate(media);
        }
      },
      dropdownColor: Colors.grey[850],
      style: const TextStyle(color: Colors.white),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
      isExpanded: true,
      underline: Container(height: 1, color: Colors.grey[700]),
    );
  }

  Widget _buildRatingStars(Media media, Function(Media)? onUpdate) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < media.rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: () {
            if (onUpdate != null) {
              media.rating = index + 1;
              onUpdate(media);
            }
          },
        );
      }),
    );
  }
}