import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/roadmap.dart';

class RoadmapParser {
  /// Extracts the roadmap slug from a roadmap.sh URL.
  /// e.g., https://roadmap.sh/sql -> sql
  /// e.g., https://roadmap.sh/frontend -> frontend
  static String? extractSlug(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (!uri.host.contains('roadmap.sh')) return null;
    
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return segments.first;
  }

  /// Fetches roadmap topics from the GitHub repository.
  /// The developer-roadmap repo stores topics as markdown files:
  /// roadmaps/{slug}/content/topic-name@hash.md
  static Future<Roadmap> fetchRoadmap(String url) async {
    final slug = extractSlug(url);
    if (slug == null) {
      throw Exception('Invalid roadmap.sh URL. Example: https://roadmap.sh/sql');
    }

    try {
      // Try GitHub API to list content files for this roadmap
      final topics = await _fetchFromGitHub(slug);
      if (topics.isNotEmpty) {
        return Roadmap(
          id: slug,
          name: _formatName(slug),
          url: url.trim(),
          topics: topics,
          addedAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('GitHub fetch failed: $e');
    }

    // Fallback: try scraping the webpage
    try {
      final topics = await _fetchFromWebpage(url.trim(), slug);
      if (topics.isNotEmpty) {
        return Roadmap(
          id: slug,
          name: _formatName(slug),
          url: url.trim(),
          topics: topics,
          addedAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Webpage scraping failed: $e');
    }

    throw Exception(
      'Could not extract topics from this roadmap. '
      'Please check the URL and try again.',
    );
  }

  /// Fetch topics from the GitHub repo using the Trees API.
  static Future<List<RoadmapTopic>> _fetchFromGitHub(String slug) async {
    // Use GitHub API to get the tree for the content directory
    final apiUrl =
        'https://api.github.com/repos/nilbuild/developer-roadmap/contents/roadmaps/$slug/content';
    
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('GitHub API returned ${response.statusCode}');
    }

    final List<dynamic> files = jsonDecode(response.body);
    final topics = <RoadmapTopic>[];

    for (final file in files) {
      final name = file['name'] as String;
      if (!name.endsWith('.md')) continue;
      if (name == 'index.md') continue;

      // Extract topic name from filename pattern: topic-name@hash.md
      final topicName = _extractTopicName(name);
      if (topicName != null && topicName.isNotEmpty) {
        topics.add(RoadmapTopic(
          id: name,
          name: topicName,
        ));
      }
    }

    // Sort alphabetically for consistent ordering
    topics.sort((a, b) => a.name.compareTo(b.name));
    return topics;
  }

  /// Fallback: fetch the roadmap.sh webpage and extract topic info.
  static Future<List<RoadmapTopic>> _fetchFromWebpage(
    String url,
    String slug,
  ) async {
    final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to load roadmap page');
    }

    final body = response.body;
    final topics = <RoadmapTopic>[];

    // Look for topic references in the HTML
    // roadmap.sh embeds topic IDs as data attributes and in URLs
    final topicPattern = RegExp(
      r'data-(?:node-id|topic-id|group-id)="([^"]+)"',
      multiLine: true,
    );

    final matches = topicPattern.allMatches(body);
    final seen = <String>{};

    for (final match in matches) {
      final raw = match.group(1) ?? '';
      final topicName = _extractTopicName(raw);
      if (topicName != null && topicName.isNotEmpty && seen.add(topicName)) {
        topics.add(RoadmapTopic(
          id: raw,
          name: topicName,
        ));
      }
    }

    return topics;
  }

  /// Extracts a human-readable topic name from a filename like:
  /// "acting--tool-invocation@sHYd4KsKlmw5Im3nQ19W8.md"
  /// -> "Acting / Tool Invocation"
  static String? _extractTopicName(String filename) {
    // Remove .md extension
    String name = filename.replaceAll('.md', '');
    
    // Skip files that are only a hash (start with @)
    if (name.startsWith('@')) return null;

    // Remove the @hash suffix
    final atIndex = name.indexOf('@');
    if (atIndex > 0) {
      name = name.substring(0, atIndex);
    }

    if (name.isEmpty) return null;

    // Replace -- with " / " (used for subcategories)
    name = name.replaceAll('--', ' / ');
    
    // Replace - with spaces
    name = name.replaceAll('-', ' ');

    // Title case
    name = name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');

    return name.trim();
  }

  /// Formats a slug to a readable name.
  /// e.g., "ai-engineer" -> "AI Engineer"
  static String _formatName(String slug) {
    return slug
        .split('-')
        .map((word) {
          if (word.isEmpty) return word;
          // Handle common abbreviations
          final upper = word.toUpperCase();
          if (['ai', 'sql', 'api', 'qa', 'ux', 'ui', 'devops', 'mlops', 'ios']
              .contains(upper)) {
            return upper;
          }
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}
