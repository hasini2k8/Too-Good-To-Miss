import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:record/record.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' show MediaType;
import 'bottom_nav_bar.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import '../services/bookmark_services.dart';
import '../services/deal_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}


class AIChatbotPage extends StatefulWidget {
  const AIChatbotPage({super.key});

  @override
  State<AIChatbotPage> createState() => _AIChatbotPageState();
}

class _AIChatbotPageState extends State<AIChatbotPage>
    with SingleTickerProviderStateMixin {

  // ── UI Controllers ──────────────────────────────────────────
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late AnimationController _typingAnimationController;

  // ── Audio ────────────────────────────────────────────────────
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;

  // ── API Config ───────────────────────────────────────────────
  final String _geminiApiKey = 'AIzaSyCE07l1fnNjBFjdTO68l6gBsiW5IAJBX3U';
  final String _elevenLabsApiKey =
      'sk_003a81898f04416af221f528385992eea4a41f0e4f9e6e7e';
  final String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  final String _elevenLabsApiUrl = 'https://api.elevenlabs.io/v1';
  String? _previousInteractionId;

  Map<String, dynamic>? _startupsData;
  String _systemInstruction = '';


  final ReviewService _reviewService = ReviewService();
  final BookmarkService _bookmarkService = BookmarkService();
  final DealService _dealService = DealService();

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadStartupsData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }



  Future<void> _loadStartupsData() async {
    try {
      // Load base startup list from assets
      final String jsonString =
          await rootBundle.loadString('assets/startups.json');
      final data = jsonDecode(jsonString);
      final List startups = data['startups'] as List;

      // Initialise all services before querying
      await _reviewService.initialize();
      await _bookmarkService.initialize();
      await _dealService.initialize();

      // Get current user context so MIVI can personalise responses
      final user = await AuthService.getCurrentUser();
      final username = user?['username'] ?? 'Guest';

      // Enrich each startup with live data from services
      // This is the core change: MIVI now knows what the app knows
      final List<Map<String, dynamic>> enrichedStartups = [];

      for (var s in startups) {
        final String startupId = s['id'];

        // ReviewService → live average rating + recent comments
        final reviews =
            await _reviewService.getReviewsForStartup(startupId);
        final avgRating =
            await _reviewService.getAverageRating(startupId);
        final reviewCount = reviews.length;

        // BookmarkService → whether current user saved this business
        final isBookmarked =
            await _bookmarkService.isBookmarked(startupId);

        // DealService → active, non-expired deals only
        final activeDeals =
            _dealService.getValidDealsForStartup(startupId);
        final dealSummaries = activeDeals
            .map((d) =>
                '${d.title} — ${d.discountPercentage}% off '
                '(expires ${d.getFormattedValidUntil()})')
            .toList();

        // Build 3 most recent review snippets for MIVI context
        final recentReviews = reviews
            .take(3)
            .map((r) =>
                '${r.username}: "${r.comment}" (${r.rating}/5 '
                'on ${r.getFormattedDate()})')
            .toList();

        enrichedStartups.add({
          ...Map<String, dynamic>.from(s),
          // Prefer live rating if reviews exist, fallback to static
          'liveRating':
              avgRating > 0 ? avgRating.toStringAsFixed(1) : s['rating'],
          'liveReviewCount':
              reviewCount > 0 ? reviewCount : s['reviewCount'],
          'isBookmarkedByUser': isBookmarked,
          'activeDeals': dealSummaries,
          'recentReviews': recentReviews,
        });
      }

      final enrichedData = {
        ...Map<String, dynamic>.from(data),
        'startups': enrichedStartups,
        'currentUser': username,
      };

      setState(() {
        _startupsData = enrichedData;
        _systemInstruction = _buildSystemInstruction(enrichedData);
        _messages.add(ChatMessage(
          text: 'Hi! I\'m MIVI, your Toronto startup expert! 🚀\n\n'
              'I can help you:\n'
              '• Find local businesses nearby\n'
              '• Get personalised recommendations\n'
              '• Check live reviews and active deals\n'
              '• See your bookmarked favourites\n\n'
              'You can type or tap the mic to speak. '
              'What would you like to know?',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Hi! I\'m MIVI. '
              '(Note: Could not load startup data — $e)',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }
  }


  String _buildSystemInstruction(Map<String, dynamic> data) {
    final userLocation = data['user_location'];
    final startups = data['startups'] as List;
    final currentUser = data['currentUser'] ?? 'Guest';

    return '''
You are MIVI, a helpful AI assistant specialised in local startups 
in Toronto, Ontario, Canada.

CURRENT USER: $currentUser

USER LOCATION:
- City: ${userLocation['city']}, ${userLocation['province']}
- Coordinates: ${userLocation['latitude']}, ${userLocation['longitude']}
- Search radius: ${data['search_radius_km']} km

LIVE STARTUP DATABASE (${startups.length} businesses):
The data below is LIVE — ratings and reviews reflect real user 
submissions, deals are currently active and not expired.

${_formatStartupsForAI(startups)}

INSTRUCTIONS:
1. Only provide info about businesses listed above.
2. If asked about a business not in the database, say you 
   don't have information about it.
3. When recommending, consider: location/distance, category 
   match, live rating, review count, and active deals.
4. Always mention business name, category, and location.
5. If a business is outside the search radius, flag this.
6. Be helpful, friendly, and concise.
7. When listing businesses, format clearly with key details.
8. Use LIVE rating (liveRating) — not the static base rating.
9. When relevant, mention specific recent reviews by name.
10. Highlight active deals when users ask about value or savings.
11. If the user asks about their favourites, check the 
    isBookmarkedByUser field — only mention those businesses.
12. If no reviews exist yet for a business, say so honestly.
13. You can compare businesses, list top-rated ones, find 
    nearby options, recommend deals, and more.

Example queries to handle:
- "Find me a good coffee shop nearby"
- "What are the highest-rated restaurants?"
- "Show me businesses with active deals"
- "What did people say about X?"
- "What are my bookmarked businesses?"
- "Which startup has the most reviews?"
- "Find me something on Queen Street"
''';
  }

  

  String _formatStartupsForAI(List startups) {
    return startups.map((s) {
      final deals = (s['activeDeals'] as List?)?.isNotEmpty == true
          ? (s['activeDeals'] as List).join(' | ')
          : 'No active deals';

      final reviews = (s['recentReviews'] as List?)?.isNotEmpty == true
          ? (s['recentReviews'] as List).join(' | ')
          : 'No reviews yet';

      final bookmarked =
          s['isBookmarkedByUser'] == true ? ' ⭐ [Saved by current user]' : '';

      return '''
--- ${s['name']} ${s['icon']}$bookmarked
  Category    : ${s['category']}
  Description : ${s['description']}
  Location    : ${s['location']}
  Coordinates : ${s['latitude']}, ${s['longitude']}
  Live Rating : ${s['liveRating']}/5.0 (${s['liveReviewCount']} reviews)
  Active Deals: $deals
  Recent Reviews: $reviews
  ID          : ${s['id']}''';
    }).join('\n\n');
  }



  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_startupsData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, loading startup data...')),
      );
      return;
    }

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Re-enrich data before each message so MIVI always has
      // the latest bookmarks/reviews (in case user changed something)
      await _refreshEnrichedData();

      final Map<String, dynamic> requestBody = {
        'model': 'gemini-2.5-flash',
        'input': text,
        'system_instruction': _systemInstruction,
        if (_previousInteractionId != null)
          'previous_interaction_id': _previousInteractionId,
      };

      final response = await http.post(
        Uri.parse('$_geminiApiUrl/interactions?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String botResponse = '';

        if (data.containsKey('id')) {
          _previousInteractionId = data['id'];
        }

        if (data.containsKey('outputs') && data['outputs'] is List) {
          for (var output in (data['outputs'] as List).reversed) {
            if (output['type'] == 'text' &&
                output.containsKey('text')) {
              botResponse = output['text'];
              break;
            }
          }
        }

        if (botResponse.isEmpty) {
          botResponse =
              'I apologise, but I couldn\'t generate a response. '
              'Please try again.';
        }

        setState(() {
          _messages.add(ChatMessage(
            text: botResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
      } else {
        String errorMessage = 'Error ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('error')) {
            errorMessage =
                'Error: ${errorData['error']['message'] ?? errorData['error']}';
          }
        } catch (_) {}

        setState(() {
          _messages.add(ChatMessage(
            text: errorMessage,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Connection error: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _refreshEnrichedData() async {
    if (_startupsData == null) return;
    try {
      final List startups = _startupsData!['startups'] as List;
      final user = await AuthService.getCurrentUser();
      final username = user?['username'] ?? 'Guest';

      final List<Map<String, dynamic>> refreshed = [];
      for (var s in startups) {
        final String startupId = s['id'];
        final reviews =
            await _reviewService.getReviewsForStartup(startupId);
        final avgRating =
            await _reviewService.getAverageRating(startupId);
        final isBookmarked =
            await _bookmarkService.isBookmarked(startupId);
        final activeDeals =
            _dealService.getValidDealsForStartup(startupId);

        refreshed.add({
          ...Map<String, dynamic>.from(s),
          'liveRating': avgRating > 0
              ? avgRating.toStringAsFixed(1)
              : s['liveRating'],
          'liveReviewCount':
              reviews.isNotEmpty ? reviews.length : s['liveReviewCount'],
          'isBookmarkedByUser': isBookmarked,
          'activeDeals': activeDeals
              .map((d) =>
                  '${d.title} — ${d.discountPercentage}% off')
              .toList(),
          'recentReviews': reviews
              .take(3)
              .map((r) =>
                  '${r.username}: "${r.comment}" (${r.rating}/5)')
              .toList(),
        });
      }

      final refreshedData = {
        ..._startupsData!,
        'startups': refreshed,
        'currentUser': username,
      };

      _startupsData = refreshedData;
      _systemInstruction = _buildSystemInstruction(refreshedData);
    } catch (e) {
      debugPrint('Warning: could not refresh enriched data — $e');
    }
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _previousInteractionId = null;
      if (_startupsData != null) {
        _messages.add(ChatMessage(
          text: 'Hi! I\'m MIVI, your Toronto startup expert! 🚀\n\n'
              'What would you like to know?',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }



  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = kIsWeb
            ? 'mivi_recording_$timestamp'
            : '/cache/mivi_recording_$timestamp.m4a';

        await _audioRecorder.start(
          RecordConfig(
            encoder:
                kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: kIsWeb ? 48000 : 44100,
          ),
          path: filePath,
        );

        setState(() => _isRecording = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.fiber_manual_record,
                    color: Colors.white, size: 14),
                SizedBox(width: 10),
                Text('Recording... Tap mic to stop'),
              ]),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Microphone permission denied. '
                  'Please allow microphone access.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null && path.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Transcribing...'),
              ]),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        }
        await _transcribeAudio(path);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Recording was too short. Please try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    setState(() => _isTranscribing = true);

    try {
      late List<int> audioBytes;
      String contentType = 'audio/ogg';
      String filename = 'recording.ogg';

      if (kIsWeb) {
        if (audioPath.startsWith('blob:') ||
            audioPath.startsWith('http')) {
          final response =
              await http.get(Uri.parse(audioPath));
          audioBytes = response.bodyBytes;
          final ct = response.headers['content-type'];
          if (ct != null) {
            contentType = ct;
            if (ct.contains('opus')) filename = 'recording.opus';
            if (ct.contains('webm')) filename = 'recording.webm';
          }
        } else if (audioPath.startsWith('data:')) {
          final parts = audioPath.split(',');
          if (parts.length > 1) {
            audioBytes = base64Decode(parts[1]);
            if (parts[0].contains('audio/')) {
              contentType = parts[0].split(':')[1].split(';')[0];
              if (contentType.contains('opus'))
                filename = 'recording.opus';
              if (contentType.contains('webm'))
                filename = 'recording.webm';
            }
          } else {
            throw Exception('Invalid data URL format');
          }
        } else {
          throw Exception(
              'Unsupported audio path format on web: $audioPath');
        }
      } else {
        final audioFile = File(audioPath);
        if (!await audioFile.exists()) {
          throw Exception(
              'Recording file not found at: $audioPath');
        }
        audioBytes = await audioFile.readAsBytes();
        contentType = 'audio/m4a';
        filename = 'recording.m4a';
      }

      if (audioBytes.isEmpty) {
        throw Exception('Recording file is empty');
      }
      if (audioBytes.length < 1000) {
        throw Exception(
            'Recording too short (${audioBytes.length} bytes). '
            'Please speak for at least 1 second.');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_elevenLabsApiUrl/speech-to-text'),
      );
      request.headers['xi-api-key'] = _elevenLabsApiKey;
      request.fields['model_id'] = 'scribe_v2';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ));

      final streamedResponse = await request.send();
      final response =
          await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcription = data['text'] ?? '';

        if (transcription.isNotEmpty) {
          setState(() {
            _messageController.text = transcription;
            _isTranscribing = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '✓ "$transcription"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() => _isTranscribing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No speech detected. '
                    'Please speak clearly and try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        setState(() => _isTranscribing = false);
        String errorMsg =
            'Transcription failed (${response.statusCode})';
        String errorDetails = response.body;

        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map) {
            errorDetails = errorData['detail']?.toString() ??
                errorData['message']?.toString() ??
                errorData['error']?.toString() ??
                response.body;
          }
        } catch (_) {}

        if (response.statusCode == 401) {
          errorMsg = 'Invalid API key';
          errorDetails =
              'Please check your ElevenLabs API key.';
        } else if (response.statusCode == 400) {
          errorMsg = 'Invalid audio format';
          errorDetails =
              'The audio format may not be supported. '
              'Try recording again.';
        } else if (response.statusCode == 413) {
          errorMsg = 'Audio file too large';
          errorDetails =
              'Recording is too long. Keep it under 25MB.';
        } else if (response.statusCode == 429) {
          errorMsg = 'Rate limit exceeded';
          errorDetails =
              'Too many requests. Please wait and try again.';
        } else if (response.statusCode >= 500) {
          errorMsg = 'Server error';
          errorDetails =
              'ElevenLabs is temporarily unavailable.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(errorMsg,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(errorDetails,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'COPY',
                textColor: Colors.white,
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: '$errorMsg: $errorDetails\n'
                        'Full response: ${response.body}',
                  ));
                },
              ),
            ),
          );
        }
      }

      // Clean up audio file on mobile
      if (!kIsWeb) {
        try {
          final audioFile = File(audioPath);
          if (await audioFile.exists()) await audioFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      setState(() => _isTranscribing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transcription Error',
                    style:
                        TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(e.toString(),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

 

  String _formatTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
  }



  Widget _buildTypingIndicator() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildBotAvatar(size: 36),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final value =
            (_typingAnimationController.value - (index * 0.2)) %
                1.0;
        final scale = value < 0.5
            ? 1.0 + (value * 0.6)
            : 1.6 - ((value - 0.5) * 1.2);
        return Transform.scale(
          scale: scale.clamp(0.8, 1.4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.7),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBotAvatar({double size = 36}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.smart_toy,
            color: Colors.white, size: size * 0.55),
      ),
    );
  }

  Widget _buildUserAvatar({double size = 36}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child:
            Icon(Icons.person, color: Colors.white, size: size * 0.55),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isBot = !message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isBot) ...[
            _buildBotAvatar(),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isBot
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isBot
                        ? null
                        : const LinearGradient(
                            colors: [
                              Color(0xFF1565C0),
                              Color(0xFF1976D2),
                            ],
                          ),
                    color: isBot ? Colors.white : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft:
                          Radius.circular(isBot ? 4 : 20),
                      bottomRight:
                          Radius.circular(isBot ? 20 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color:
                          isBot ? Colors.black87 : Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 12),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            _buildBotAvatar(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MIVI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _startupsData != null
                            ? 'Online • '
                                '${(_startupsData!['startups'] as List).length}'
                                ' Startups'
                            : 'Loading...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Clear conversation',
              onPressed: _clearConversation,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ──────────────────────────────────────
          Expanded(
            child: _startupsData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBotAvatar(size: 80),
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF1565C0)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading startup database...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length &&
                          _isLoading) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(
                          _messages[index]);
                    },
                  ),
          ),

          // ── Transcribing indicator ────────────────────────────
          if (_isTranscribing)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                border: Border(
                  top: BorderSide(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Converting speech to text...',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // ── Input bar ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Mic button
                  Container(
                    decoration: BoxDecoration(
                      gradient: _isRecording
                          ? const LinearGradient(
                              colors: [
                                Colors.red,
                                Colors.redAccent
                              ],
                            )
                          : const LinearGradient(
                              colors: [
                                Color(0xFF1565C0),
                                Color(0xFF1976D2),
                              ],
                            ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording
                                  ? Colors.red
                                  : const Color(0xFF1565C0))
                              .withOpacity(
                                  _isRecording ? 0.5 : 0.3),
                          blurRadius: _isRecording ? 15 : 10,
                          spreadRadius: _isRecording ? 3 : 0,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _isTranscribing
                          ? null
                          : _toggleRecording,
                      tooltip: _isRecording
                          ? 'Stop recording'
                          : 'Start recording',
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Text field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                            color: Colors.grey[300]!, width: 1),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Ask about startups...',
                          hintStyle:
                              TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1565C0),
                          Color(0xFF1976D2)
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0)
                              .withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white),
                      onPressed:
                          _isLoading ? null : _sendMessage,
                      tooltip: 'Send message',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          const BottomNavBar(selectedIndex: 2),
    );
  }
}