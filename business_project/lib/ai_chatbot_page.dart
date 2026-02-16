import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:record/record.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' show MediaType;
import 'bottom_nav_bar.dart';

class AIChatbotPage extends StatefulWidget {
  const AIChatbotPage({super.key});

  @override
  State<AIChatbotPage> createState() => _AIChatbotPageState();
}

class _AIChatbotPageState extends State<AIChatbotPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late AnimationController _typingAnimationController;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _recordingPath;

  final String _geminiApiKey = 'AIzaSyCE07l1fnNjBFjdTO68l6gBsiW5IAJBX3U';
  final String _elevenLabsApiKey = 'sk_003a81898f04416af221f528385992eea4a41f0e4f9e6e7e';
  
  final String _geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta';
  final String _elevenLabsApiUrl = 'https://api.elevenlabs.io/v1';
  
  String? _previousInteractionId;
  
  Map<String, dynamic>? _startupsData;
  String _systemInstruction = '';

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadStartupsData();
  }

  Future<void> _loadStartupsData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/startups.json');
      final data = jsonDecode(jsonString);
      
      setState(() {
        _startupsData = data;
        _systemInstruction = _buildSystemInstruction(data);
        
        _messages.add(
          ChatMessage(
            text: 'Hi! I\'m MIVI, your Toronto startup expert! 🚀\n\nI can help you:\n• Find local businesses nearby\n• Get personalized recommendations\n• Answer questions about startups\n\nYou can type or tap the mic to speak. What would you like to know?',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Hi! I\'m your AI assistant. (Note: Could not load startups data: $e)',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  String _buildSystemInstruction(Map<String, dynamic> data) {
    final userLocation = data['user_location'];
    final startups = data['startups'] as List;
    
    return '''You are a helpful AI assistant named MIVI specialized in providing information about local startups in Toronto, Ontario, Canada.

USER LOCATION:
- City: ${userLocation['city']}, ${userLocation['province']}
- Coordinates: ${userLocation['latitude']}, ${userLocation['longitude']}
- Search radius: ${data['search_radius_km']} km

AVAILABLE STARTUPS DATABASE:
You have access to ${startups.length} local startups. Here is the complete database:

${_formatStartupsForAI(startups)}

IMPORTANT INSTRUCTIONS:
1. ONLY provide information about the startups listed in the database above
2. If asked about a business not in the database, politely say you don't have information about it
3. When recommending businesses, consider:
   - User's location and distance to the business
   - Category matching user's request
   - Rating (higher is better)
   - Number of reviews
4. Always mention the business name, category, and location when recommending
5. If a startup is outside the search radius (like "Distant Diner" in Barrie), mention that it's too far
6. Be helpful, friendly, and concise
7. You can compare businesses, list top-rated ones, find nearby options, etc.
8. When listing multiple businesses, format them clearly with their key details

Example queries you should handle:
- "Find me a good coffee shop nearby"
- "What are the highest-rated restaurants?"
- "Show me retail stores"
- "Which startup has the best reviews?"
- "Find me something on Queen Street"
- "What food options do I have?"''';
  }

  String _formatStartupsForAI(List startups) {
    return startups.map((s) {
      return '''
- ${s['name']} (${s['icon']})
  Category: ${s['category']}
  Description: ${s['description']}
  Location: ${s['location']}
  Coordinates: ${s['latitude']}, ${s['longitude']}
  Rating: ${s['rating']}/5.0 (${s['reviewCount']} reviews)
  ID: ${s['id']}''';
    }).join('\n');
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
        
        // On web, use opus or wav encoder (better compatibility)
        // On mobile, use aac
        final filePath = kIsWeb 
            ? 'mivi_recording_$timestamp'  // Web: extension will be added automatically
            : '/cache/mivi_recording_$timestamp.m4a';  // Mobile: actual path
        
        await _audioRecorder.start(
          RecordConfig(
            encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: kIsWeb ? 48000 : 44100,  // 48kHz is standard for web
          ),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('🎤 Recording... Tap mic to stop'),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission denied. Please allow microphone access.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });

      if (path != null && path.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('✨ Transcribing...'),
                ],
              ),
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
              content: Text('Recording was too short. Please try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
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
    setState(() {
      _isTranscribing = true;
    });

    try {
      late List<int> audioBytes;
      String contentType = 'audio/ogg';
      String filename = 'recording.ogg';
      
      print('=== TRANSCRIPTION DEBUG START ===');
      print('Platform: ${kIsWeb ? "Web" : "Mobile"}');
      print('Audio path: $audioPath');
      
      // Handle differently for web vs mobile
      if (kIsWeb) {
        // On web, audioPath is typically a blob URL
        try {
          print('Processing web audio...');
          
          // Try to fetch the blob data
          if (audioPath.startsWith('blob:') || audioPath.startsWith('http')) {
            final response = await http.get(Uri.parse(audioPath));
            audioBytes = response.bodyBytes;
            print('✓ Web audio fetched: ${audioBytes.length} bytes');
            
            // Detect format from response headers or data
            final responseContentType = response.headers['content-type'];
            if (responseContentType != null) {
              contentType = responseContentType;
              print('✓ Detected content type: $contentType');
              
              // Set appropriate filename based on content type
              if (contentType.contains('opus')) {
                filename = 'recording.opus';
              } else if (contentType.contains('webm')) {
                filename = 'recording.webm';
              } else if (contentType.contains('ogg')) {
                filename = 'recording.ogg';
              }
            }
          } else if (audioPath.startsWith('data:')) {
            // Handle base64 data URL
            print('Processing base64 data URL...');
            final parts = audioPath.split(',');
            if (parts.length > 1) {
              final base64Data = parts[1];
              audioBytes = base64Decode(base64Data);
              
              // Extract content type from data URL
              if (parts[0].contains('audio/')) {
                contentType = parts[0].split(':')[1].split(';')[0];
                print('✓ Extracted content type: $contentType');
                
                // Set filename based on content type
                if (contentType.contains('opus')) {
                  filename = 'recording.opus';
                } else if (contentType.contains('webm')) {
                  filename = 'recording.webm';
                } else if (contentType.contains('ogg')) {
                  filename = 'recording.ogg';
                }
              }
              print('✓ Web audio decoded from base64: ${audioBytes.length} bytes');
            } else {
              throw Exception('Invalid data URL format');
            }
          } else {
            throw Exception('Unsupported audio path format on web: $audioPath');
          }
        } catch (e) {
          print('✗ Web audio fetch error: $e');
          throw Exception('Failed to read web audio data: $e');
        }
      } else {
        // On mobile, it's a file path
        print('Processing mobile audio file...');
        final audioFile = File(audioPath);
        
        if (!await audioFile.exists()) {
          print('✗ File does not exist: $audioPath');
          throw Exception('Recording file not found at: $audioPath');
        }
        
        audioBytes = await audioFile.readAsBytes();
        contentType = 'audio/m4a';
        filename = 'recording.m4a';
        print('✓ Mobile audio loaded: ${audioBytes.length} bytes');
      }
      
      // Validate audio data
      if (audioBytes.isEmpty) {
        print('✗ Audio bytes are empty');
        throw Exception('Recording file is empty');
      }

      if (audioBytes.length < 1000) {
        print('✗ Audio too short: ${audioBytes.length} bytes');
        throw Exception('Recording too short (${audioBytes.length} bytes). Please speak for at least 1 second.');
      }

      print('✓ Audio validation passed');
      print('Preparing API request...');
      print('- Filename: $filename');
      print('- Content-Type: $contentType');
      print('- Size: ${audioBytes.length} bytes (${(audioBytes.length / 1024).toStringAsFixed(2)} KB)');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_elevenLabsApiUrl/speech-to-text'),
      );

      request.headers['xi-api-key'] = _elevenLabsApiKey;
      

      request.fields['model_id'] = 'scribe_v2';
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',  
          audioBytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      );
      
      print('✓ Model ID: scribe_v2');
      print('✓ File parameter added');

      print('Sending request to ElevenLabs...');
      print('URL: $_elevenLabsApiUrl/speech-to-text');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('=== TRANSCRIPTION DEBUG END ===');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcription = data['text'] ?? '';

        print('✓ Transcription successful: "$transcription"');

        if (transcription.isNotEmpty) {
          setState(() {
            _messageController.text = transcription;
            _isTranscribing = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '✓ "$transcription"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() {
            _isTranscribing = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No speech detected. Please speak clearly and try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // Handle error responses
        setState(() {
          _isTranscribing = false;
        });
        
        String errorMsg = 'Transcription failed (${response.statusCode})';
        String errorDetails = response.body;
        
        // Parse error response
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map) {
            errorDetails = errorData['detail']?.toString() ?? 
                          errorData['message']?.toString() ?? 
                          errorData['error']?.toString() ?? 
                          response.body;
          }
        } catch (e) {
          print('Could not parse error response: $e');
        }
        
        // Provide specific error messages
        if (response.statusCode == 401) {
          errorMsg = '🔑 Invalid API key';
          errorDetails = 'Please check your ElevenLabs API key is correct and active.';
        } else if (response.statusCode == 400) {
          errorMsg = '🎵 Invalid audio format';
          errorDetails = 'The audio format may not be supported. Try recording again.';
        } else if (response.statusCode == 413) {
          errorMsg = '📦 Audio file too large';
          errorDetails = 'Recording is too long. Please keep it under 25MB.';
        } else if (response.statusCode == 429) {
          errorMsg = '⏰ Rate limit exceeded';
          errorDetails = 'Too many requests. Please wait a moment and try again.';
        } else if (response.statusCode == 500 || response.statusCode == 502 || response.statusCode == 503) {
          errorMsg = '🔧 Server error';
          errorDetails = 'ElevenLabs service is temporarily unavailable. Try again in a moment.';
        }
        
        print('✗ Error: $errorMsg');
        print('✗ Details: $errorDetails');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errorMsg,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    errorDetails,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'COPY',
                textColor: Colors.white,
                onPressed: () {
                  // Copy error to clipboard for debugging
                  Clipboard.setData(ClipboardData(
                    text: 'Error $errorMsg: $errorDetails\n\nFull response: ${response.body}'
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error details copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }

      // Clean up the audio file (only on mobile)
      if (!kIsWeb) {
        try {
          final audioFile = File(audioPath);
          if (await audioFile.exists()) {
            await audioFile.delete();
            print('✓ Audio file cleaned up');
          }
        } catch (e) {
          print('⚠ Failed to delete audio file: $e');
        }
      }
    } catch (e, stackTrace) {
      print('✗ TRANSCRIPTION EXCEPTION: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        _isTranscribing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '❌ Transcription Error',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
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
      Map<String, dynamic> requestBody = {
        'model': 'gemini-2.5-flash',
        'input': text,
        'system_instruction': _systemInstruction,
      };

      if (_previousInteractionId != null) {
        requestBody['previous_interaction_id'] = _previousInteractionId;
      }

      final response = await http.post(
        Uri.parse('$_geminiApiUrl/interactions?key=$_geminiApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String botResponse = '';
        
        try {
          if (data.containsKey('id')) {
            _previousInteractionId = data['id'];
          }

          if (data.containsKey('outputs') && data['outputs'] is List) {
            for (var output in data['outputs'].reversed) {
              if (output['type'] == 'text' && output.containsKey('text')) {
                botResponse = output['text'];
                break;
              }
            }
          }

          if (botResponse.isEmpty) {
            botResponse = 'I apologize, but I couldn\'t generate a response. Please try again.';
          }
        } catch (e) {
          botResponse = 'Error parsing response: $e';
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
            errorMessage = 'Error: ${errorData['error']['message'] ?? errorData['error']}';
          } else {
            errorMessage = 'Error ${response.statusCode}: ${response.body}';
          }
        } catch (e) {
          errorMessage = 'Error ${response.statusCode}: ${response.body}';
        }
        
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

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _previousInteractionId = null;
      if (_startupsData != null) {
        _messages.add(
          ChatMessage(
            text: 'Hi! I\'m MIVI, your Toronto startup expert! 🚀\n\nI can help you:\n• Find local businesses nearby\n• Get personalized recommendations\n• Answer questions about startups\n\nYou can type or tap the mic to speak. What would you like to know?',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // AI Avatar
          Container(
            width: 36,
            height: 36,
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
            child: const Center(
              child: Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        final value = (_typingAnimationController.value - (index * 0.2)) % 1.0;
        final scale = value < 0.5 ? 1.0 + (value * 0.6) : 1.6 - ((value - 0.5) * 1.2);
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
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
            // AI Avatar in AppBar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.smart_toy,
                  color: Color(0xFF1565C0),
                  size: 24,
                ),
              ),
            ),
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
                            ? 'Online • ${_startupsData!['startups'].length} Startups' 
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
          Expanded(
            child: _startupsData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1565C0).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.smart_toy,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
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
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return _buildTypingIndicator();
                      }

                      final message = _messages[index];
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
                              // Bot Avatar
                              Container(
                                width: 36,
                                height: 36,
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
                                child: const Center(
                                  child: Icon(
                                    Icons.smart_toy,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
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
                                              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                                            ),
                                      color: isBot ? Colors.white : null,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20),
                                        topRight: const Radius.circular(20),
                                        bottomLeft: Radius.circular(isBot ? 4 : 20),
                                        bottomRight: Radius.circular(isBot ? 20 : 4),
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
                                        color: isBot ? Colors.black87 : Colors.white,
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                              // User Avatar
                              Container(
                                width: 36,
                                height: 36,
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
                                child: const Center(
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_isTranscribing)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                border: Border(
                  top: BorderSide(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.hearing, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
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
                  // Microphone button
                  Container(
                    decoration: BoxDecoration(
                      gradient: _isRecording 
                          ? const LinearGradient(
                              colors: [Colors.red, Colors.redAccent],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                            ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : const Color(0xFF1565C0))
                              .withOpacity(0.4),
                          blurRadius: _isRecording ? 15 : 10,
                          spreadRadius: _isRecording ? 3 : 0,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _isTranscribing ? null : _toggleRecording,
                      tooltip: _isRecording ? 'Stop recording' : 'Start recording',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Ask about startups...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _isLoading ? null : _sendMessage,
                      tooltip: 'Send message',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 2),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }
}

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