import 'base_view_model.dart';
import '../services/api_service.dart';
import '../services/url_services.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';
import '../models/api_response.dart';
import '../models/chat_session.dart';
import '../models/book.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? aiType; // 'medi_ai' or 'common_ai' or null for user messages
  // Optional web search payload to render in UI
  final List<Map<String, dynamic>>? webResults;
  final Map<String, dynamic>? webMeta;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.aiType,
    this.webResults,
    this.webMeta,
  });
}

class ChatViewModel extends BaseViewModel {
  final List<ChatMessage> _messages = [];
  bool _mediAiMode = true;
  String? _sessionId;
  final List<ChatSession> _sessions = [];
  final List<Book> _books = [];
  final List<String> _selectedBooks = [];
  final List<Book> _filteredBooks = [];
  String _searchQuery = '';
  bool _webSearchEnabled = false;

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get mediAiMode => _mediAiMode;
  String? get sessionId => _sessionId;
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  List<Book> get books => List.unmodifiable(_filteredBooks);
  List<String> get selectedBooks => List.unmodifiable(_selectedBooks);
  String get searchQuery => _searchQuery;
  bool get webSearchEnabled => _webSearchEnabled;

  // Toggle web search
  void toggleWebSearch() {
    _webSearchEnabled = !_webSearchEnabled;
    notifyListeners();
    logger.i('Web search toggled: $_webSearchEnabled');
  }

  // Add a message
  void addMessage(String message,
      {bool isUser = true,
      String? aiType,
      List<Map<String, dynamic>>? webResults,
      Map<String, dynamic>? webMeta}) {
    logger.i(
        'Adding message: isUser=$isUser, aiType=$aiType, length=${message.length}');
    logger.d(
        'Message content: "${message.substring(0, message.length > 100 ? 100 : message.length)}${message.length > 100 ? '...' : ''}"');

    if (message.trim().isNotEmpty) {
      _messages.add(ChatMessage(
        text: message,
        isUser: isUser,
        timestamp: DateTime.now(),
        aiType: aiType,
        webResults: webResults,
        webMeta: webMeta,
      ));
      logger
          .i('Message added successfully. Total messages: ${_messages.length}');
      notifyListeners();
    } else {
      logger.w('Message was empty after trimming, not adding to list');
    }
  }

  // Remove typing indicator
  void _removeTypingIndicator() {
    _messages.removeWhere(
        (message) => message.text == 'typing...' && !message.isUser);
    notifyListeners();
  }

  // Clear all messages
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  // Start a new chat session
  // Creates a new session using /session/new and stores the session_id
  // Deletes old session if exists to maintain clean session lifecycle
  Future<void> startNewSession() async {
    setLoading(true);
    clearError();

    try {
      // Delete old session if exists (per Medibook API reference)
      // Sessions are only deleted when resetting the chat
      if (_sessionId != null && _sessionId!.isNotEmpty) {
        logger.i('Deleting old session before creating new one: $_sessionId');
        await ApiService.deleteSession(_sessionId!);
      }

      final response = await ApiService.startNewSession();

      if (response.status && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Update session ID and AI mode from response
        _sessionId = data['session_id'];
        _mediAiMode = data['medi_ai_mode'] ?? data['medical_mode'] ?? false;

        // Clear existing messages
        _messages.clear();

        notifyListeners();
        logger.i(
            'New session started successfully: session_id=$_sessionId, medi_ai_mode=$_mediAiMode');
      } else {
        // Handle specific error cases
        if (response.code == 401) {
          setError('Please login again to start a new session.');
          // Clear invalid token
          final storage = await StorageService.getInstance();
          await storage.clearUserData();
        } else {
          setError(response.message);
        }
        logger.e('Failed to start new session: ${response.message}');
      }
    } catch (e) {
      setError('Failed to start new session. Please try again.');
      logger.e('Start new session error: $e');
    } finally {
      setLoading(false);
    }
  }

  // Start a new chat session with a specific book
  // Creates a new session using /session/new and stores the session_id
  // Deletes old session if exists to maintain clean session lifecycle
  Future<void> startNewSessionWithBook(
      String bookName, String bookTitle) async {
    setLoading(true);
    clearError();

    try {
      // Delete old session if exists (per Medibook API reference)
      // Sessions are only deleted when resetting the chat
      if (_sessionId != null && _sessionId!.isNotEmpty) {
        logger.i('Deleting old session before creating new one: $_sessionId');
        await ApiService.deleteSession(_sessionId!);
      }

      // Clear any existing selected books and set the new one
      _selectedBooks.clear();
      _selectedBooks.add(bookTitle);

      // Start a new session
      final response = await ApiService.startNewSession();

      if (response.status && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Update session ID and AI mode from response
        _sessionId = data['session_id'];
        _mediAiMode = data['medi_ai_mode'] ?? data['medical_mode'] ?? false;

        // Clear existing messages
        _messages.clear();

        // Select the book for chat context
        await selectBooks();

        notifyListeners();
        logger.i(
            'New session started with book "$bookName": session_id=$_sessionId, medi_ai_mode=$_mediAiMode');
      } else {
        // Handle specific error cases
        if (response.code == 401) {
          setError('Please login again to start a new session.');
          // Clear invalid token
          final storage = await StorageService.getInstance();
          await storage.clearUserData();
        } else {
          setError(response.message);
        }
        logger.e('Failed to start new session with book: ${response.message}');
      }
    } catch (e) {
      setError('Failed to start new session with book. Please try again.');
      logger.e('Start new session with book error: $e');
    } finally {
      setLoading(false);
    }
  }

  // Check server connectivity
  // Check server connectivity - simplified to avoid blocking chat flow
  Future<bool> _checkServerConnectivity() async {
    try {
      // Skip detailed connectivity check if we already have a valid session
      // This avoids unnecessary network calls that can cause timeouts
      if (_sessionId != null && _sessionId!.isNotEmpty) {
        logger.i('Skipping connectivity check - session exists');
        return true;
      }

      // Quick check with shorter timeout for new sessions
      final response = await ApiService.get(
        endpoint: 'api/health',
        params: {},
        useAuth: false,
      ).timeout(const Duration(seconds: 5));

      // Consider 404 as server reachable
      if (response.code == 404) {
        return true;
      }

      return response.isSuccess || response.code == 200;
    } catch (e) {
      logger.w('Server connectivity check failed: $e');
      // Don't block chat flow - assume server is available
      // The actual API call will handle the error if server is truly unavailable
      return true;
    }
  }

  // Send message to AI
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    logger.i('Attempting to send message. Current session ID: $_sessionId');
    logger.i('Available sessions: ${_sessions.map((s) => s.id).toList()}');

    // Log detailed session state for debugging
    logSessionState();

    // Ensure we have a valid session ID before sending message
    if (!_isValidSession(_sessionId)) {
      logger.w(
          'No valid session ID found when sending message, starting new session first');
      await startNewSession();
      if (!_isValidSession(_sessionId)) {
        setError('Failed to create session. Please try again.');
        return;
      }
    }

    logger.i('Sending message to session: $_sessionId');

    // Add user message
    addMessage(message, isUser: true);

    // Add typing indicator
    addMessage('typing...',
        isUser: false, aiType: _mediAiMode ? 'medi_ai' : 'common_ai');

    setLoading(true);
    clearError();

    // Check server connectivity first
    final isServerAvailable = await _checkServerConnectivity();
    if (!isServerAvailable) {
      setError('Server is currently unavailable. Please try again later.');
      _removeTypingIndicator();
      addMessage(
          'Error: Server is currently unavailable. Please try again later.',
          isUser: false,
          aiType: _mediAiMode ? 'medi_ai' : 'common_ai');
      setLoading(false);
      return;
    }

    try {
      // Get authentication token
      final storage = await StorageService.getInstance();
      final token = storage.getUserToken();

      if (token == null || token.isEmpty) {
        setError('Authentication token not found. Please login again.');
        _removeTypingIndicator();
        addMessage('Error: Please login again to use the chat feature.',
            isUser: false, aiType: _mediAiMode ? 'medi_ai' : 'common_ai');
        return;
      }

      // Prepare request payload for the direct chat API
      // Based on API reference: https://drjebasingh.in/ai/api/chat/
      // Without memory: {"question": "..."}
      // With memory: {"session_id": "...", "question": "..."}
      final payload = {
        'question': message,
        'use_mistral_only':
            !_mediAiMode, // If MediAI mode is ON, use_mistral_only should be false
      };

      // Add session ID to ensure messages are saved to the correct session (for memory)
      if (_sessionId != null && _sessionId!.isNotEmpty) {
        payload['session_id'] = _sessionId!;
        logger
            .i('Including session_id in chat payload for memory: $_sessionId');
        logger.i('Full payload being sent: $payload');
      } else {
        logger.w('WARNING: No session_id available to include in payload!');
      }

      // Add selected books context if available
      if (_selectedBooks.isNotEmpty) {
        payload['selected_books'] = _selectedBooks.toString();
        logger.i('Including selected books in chat context: $_selectedBooks');
      }

      logger.i('Sending chat message: $message');

      // Store web search results and metadata
      List<Map<String, dynamic>> webSearchResults = [];
      Map<String, dynamic>? webSearchMetadata;

      // Perform web search if enabled
      if (_webSearchEnabled) {
        try {
          logger.i('Web search is enabled, performing search...');
          final webSearchResponse = await ApiService.post(
            endpoint: 'ai/web-search',
            json: {
              'query': message,
              'search_type': _mediAiMode ? 'medical' : 'general',
              'max_results': 10,
            },
            useAuth: true,
          );

          if (webSearchResponse.isSuccess && webSearchResponse.data != null) {
            logger.i('Web search completed successfully');
            final data = webSearchResponse.data as Map<String, dynamic>;

            // Store metadata (query, total_results, etc.)
            webSearchMetadata = {
              'query': data['query'] ?? message,
              'total_results': data['total_results'] ?? 0,
            };

            if (data.containsKey('results') && data['results'] is List) {
              webSearchResults =
                  List<Map<String, dynamic>>.from(data['results']);
              logger
                  .i('Web search returned ${webSearchResults.length} results');
              if (webSearchResults.isNotEmpty) {
                logger.i('First web search result: ${webSearchResults.first}');
                // Do not add a separate message; results will be merged into the AI reply
              }
            } else {
              logger.w(
                  'Web search response missing results key or results is not a list');
            }
          } else {
            logger.w(
                'Web search response not successful: isSuccess=${webSearchResponse.isSuccess}');
          }
        } catch (e) {
          logger.w('Web search failed: $e');
          // Continue with regular chat even if web search fails
        }
      } else {
        logger.i('Web search is disabled');
      }

      // Make API call with retry mechanism for Mistral failures
      logger.i(
          'About to send chat request. Web search results count: ${webSearchResults.length}');
      ApiResponse response;
      int retryCount = 0;
      const maxRetries = 2;

      do {
        response = await ApiService.post(
          endpoint: UrlServices.CHAT,
          json: payload,
          useAuth: true,
        );

        // Check if response indicates Mistral failure
        if (response.isSuccess && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          if (data.containsKey('messages') && data['messages'] is List) {
            final messages = data['messages'] as List;
            if (messages.isNotEmpty) {
              final lastMessage = messages.last;
              if (lastMessage is Map<String, dynamic> &&
                  lastMessage['role'] == 'assistant' &&
                  lastMessage.containsKey('content')) {
                final content = lastMessage['content'];
                if (content is Map<String, dynamic>) {
                  final mediAiContent = content['medi_ai']?.toString() ?? '';
                  final commonAiContent =
                      content['common_ai']?.toString() ?? '';

                  // If both AI services are failing, retry
                  if (mediAiContent.contains('No reply from Mistral') &&
                      commonAiContent.contains('No reply from Mistral') &&
                      retryCount < maxRetries) {
                    retryCount++;
                    logger.w(
                        'Mistral AI not responding, retrying... (attempt $retryCount/$maxRetries)');
                    await Future.delayed(
                        Duration(seconds: 2)); // Wait 2 seconds before retry
                    continue;
                  }
                }
              }
            }
          }
        }
        break; // Exit retry loop if successful or max retries reached
      } while (retryCount < maxRetries);

      if (response.isSuccess) {
        // Extract response message
        String aiResponse =
            'I apologize, but I couldn\'t process your request at the moment.';

        logger.i('Processing chat response - isSuccess: ${response.isSuccess}');
        logger.i('Response data type: ${response.data.runtimeType}');

        if (response.data != null) {
          if (response.data is Map<String, dynamic>) {
            final data = response.data as Map<String, dynamic>;
            logger.i('Response data keys: ${data.keys.toList()}');

            // Handle the new API response format (from https://drjebasingh.in/ai/api/chat/)
            // Response: {"answer": "...", "sources": [...], "found_relevant_content": true, "session_id": "...", "total_turns": 2}
            if (data.containsKey('answer') && data['answer'] != null) {
              final answer = data['answer'].toString().trim();
              logger.i(
                  'Using new API format - answer: "${answer.length > 100 ? answer.substring(0, 100) + '...' : answer}"');

              // Update session_id from response if available
              if (data.containsKey('session_id') &&
                  data['session_id'] != null) {
                _sessionId = data['session_id'].toString();
                logger.i('Updated session_id from response: $_sessionId');
              }

              // Get sources if available
              List<Map<String, dynamic>> sources = [];
              if (data.containsKey('sources') && data['sources'] is List) {
                sources = List<Map<String, dynamic>>.from(data['sources']);
                logger.i('Found ${sources.length} sources in response');
              }

              _removeTypingIndicator();

              // Build final message with sources
              String finalMessage = answer;

              if (sources.isNotEmpty) {
                String sourcesSection = '\n\n---\n### Sources:\n\n';
                for (var source in sources) {
                  if (source['preview'] != null) {
                    sourcesSection += '• ${source['preview']}\n';
                  }
                  if (source['score'] != null) {
                    sourcesSection += '  Score: ${source['score']}\n';
                  }
                  sourcesSection += '\n';
                }
                finalMessage += sourcesSection;
              }

              addMessage(finalMessage,
                  isUser: false, aiType: _mediAiMode ? 'medi_ai' : 'common_ai');
              logger.i('Added response from new API format');
            }
            // Handle the old response format with messages array
            else if (data.containsKey('messages') && data['messages'] is List) {
              final messages = data['messages'] as List;
              logger.i('Found ${messages.length} messages in response');

              if (messages.isNotEmpty) {
                // Search through all assistant messages to find the most recent working response
                String mediAiContent = '';
                String commonAiContent = '';
                bool foundWorkingResponse = false;

                // Search from newest to oldest to find the most recent working response
                for (int i = messages.length - 1; i >= 0; i--) {
                  final message = messages[i];

                  if (message is Map<String, dynamic> &&
                      message['role'] == 'assistant' &&
                      message.containsKey('content')) {
                    final content = message['content'];
                    logger.i('Checking message $i: ${content.runtimeType}');

                    if (content is Map<String, dynamic>) {
                      final msgMediAi = content['medi_ai']?.toString() ?? '';
                      final msgCommonAi =
                          content['common_ai']?.toString() ?? '';

                      // Check if this message has working content
                      if ((msgMediAi.isNotEmpty &&
                              !msgMediAi.contains('No reply from Mistral')) ||
                          (msgCommonAi.isNotEmpty &&
                              !msgCommonAi.contains('No reply from Mistral'))) {
                        // Use the first working response we find (most recent)
                        if (msgMediAi.isNotEmpty &&
                            !msgMediAi.contains('No reply from Mistral')) {
                          mediAiContent = msgMediAi.trim();
                        }
                        if (msgCommonAi.isNotEmpty &&
                            !msgCommonAi.contains('No reply from Mistral')) {
                          commonAiContent = msgCommonAi.trim();
                        }

                        foundWorkingResponse = true;
                        logger.i('Found working response in message $i');
                        break; // Use the most recent working response
                      }
                    }
                  }
                }

                // If no working response found, check the last message for error details
                if (!foundWorkingResponse && messages.isNotEmpty) {
                  final lastMessage = messages.last;
                  logger.i('Last message: $lastMessage');

                  if (lastMessage is Map<String, dynamic> &&
                      lastMessage['role'] == 'assistant' &&
                      lastMessage.containsKey('content')) {
                    final content = lastMessage['content'];
                    if (content is Map<String, dynamic>) {
                      mediAiContent = content['medi_ai']?.toString() ?? '';
                      commonAiContent = content['common_ai']?.toString() ?? '';
                    }
                  }
                }

                // Clean up the content (remove excessive whitespace)
                mediAiContent = mediAiContent.trim();
                commonAiContent = commonAiContent.trim();

                // Show response based on toggle mode
                logger.i(
                    'MediAI content: "${mediAiContent.length > 100 ? mediAiContent.substring(0, 100) + '...' : mediAiContent}"');
                logger.i('Common AI content: "$commonAiContent"');
                logger.i(
                    'Current AI mode: ${_mediAiMode ? "MediAI" : "General AI"}');
                logger.i('Found working response: $foundWorkingResponse');

                // Log web search results status
                logger
                    .i('Web search results count: ${webSearchResults.length}');
                if (webSearchResults.isNotEmpty) {
                  logger
                      .i('First web search result: ${webSearchResults.first}');
                }

                if (_mediAiMode) {
                  // MediAI mode is ON - show only MediAI response
                  _removeTypingIndicator();

                  if (mediAiContent.isNotEmpty &&
                      !mediAiContent.contains('No reply from Mistral')) {
                    String finalMessage = mediAiContent;

                    // Add web search results if available
                    if (webSearchResults.isNotEmpty) {
                      logger.i(
                          'Adding web search results to MediAI response. Results count: ${webSearchResults.length}');
                      String webSearchSection =
                          '\n\n---\n### Relevant Resources:\n\n';

                      // Add metadata if available
                      if (webSearchMetadata != null) {
                        webSearchSection +=
                            '**Search Query:** ${webSearchMetadata['query']}\n';
                        webSearchSection +=
                            '**Total Results Found:** ${webSearchMetadata['total_results']}\n\n';
                      }

                      for (var result in webSearchResults) {
                        webSearchSection +=
                            '• **${result['title'] ?? 'Source'}**\n';
                        if (result['snippet'] != null) {
                          webSearchSection += '  ${result['snippet']}\n';
                        }
                        if (result['link'] != null) {
                          webSearchSection += '  Link: ${result['link']}\n';
                        }
                        if (result['source'] != null) {
                          webSearchSection += '  Source: ${result['source']}\n';
                        }
                        if (result['medical_relevance_score'] != null) {
                          webSearchSection +=
                              '  Relevance Score: ${result['medical_relevance_score']}\n';
                        }
                        webSearchSection += '\n';
                      }
                      finalMessage += webSearchSection;
                      logger.i('Web search section added to final message');
                    } else {
                      logger
                          .i('No web search results to add to MediAI response');
                    }

                    addMessage(finalMessage,
                        isUser: false,
                        aiType: 'medi_ai',
                        webResults: webSearchResults.isNotEmpty
                            ? webSearchResults
                            : null,
                        webMeta: webSearchMetadata);
                    logger.i('Using MediAI response (MediAI mode)');
                  } else {
                    // MediAI failed, but check if Common AI has content as fallback
                    if (commonAiContent.isNotEmpty &&
                        !commonAiContent.contains('No reply from Mistral')) {
                      addMessage(
                          'MediAI is temporarily unavailable, but here\'s some general information that might help:\n\n$commonAiContent',
                          isUser: false,
                          aiType: 'common_ai');
                      logger.i(
                          'Using Common AI content as fallback for MediAI mode');
                    } else {
                      // Check if it's specifically a Mistral error
                      if (mediAiContent.contains('No reply from Mistral')) {
                        addMessage(
                            'MediAI is currently experiencing technical difficulties. The Mistral AI service is temporarily unavailable. Please try again in a few moments or contact support if the issue persists.',
                            isUser: false,
                            aiType: 'medi_ai');
                      } else {
                        addMessage(
                            'I apologize, but MediAI couldn\'t process your request at the moment. Please try again.',
                            isUser: false,
                            aiType: 'medi_ai');
                      }
                      logger.w(
                          'No valid MediAI response found - Content: "$mediAiContent"');
                    }
                  }
                } else {
                  // General AI mode is ON - show both General AI and MediAI responses
                  _removeTypingIndicator();

                  // Add General AI response if available
                  if (commonAiContent.isNotEmpty &&
                      !commonAiContent.contains('No reply from Mistral')) {
                    String finalCommonMessage = commonAiContent;

                    // Add web search results if available
                    if (webSearchResults.isNotEmpty) {
                      String webSearchSection =
                          '\n\n---\n### Relevant Resources:\n\n';

                      // Add metadata if available
                      if (webSearchMetadata != null) {
                        webSearchSection +=
                            '**Search Query:** ${webSearchMetadata['query']}\n';
                        webSearchSection +=
                            '**Total Results Found:** ${webSearchMetadata['total_results']}\n\n';
                      }

                      for (var result in webSearchResults) {
                        webSearchSection +=
                            '• **${result['title'] ?? 'Source'}**\n';
                        if (result['snippet'] != null) {
                          webSearchSection += '  ${result['snippet']}\n';
                        }
                        if (result['link'] != null) {
                          webSearchSection += '  Link: ${result['link']}\n';
                        }
                        if (result['source'] != null) {
                          webSearchSection += '  Source: ${result['source']}\n';
                        }
                        if (result['medical_relevance_score'] != null) {
                          webSearchSection +=
                              '  Relevance Score: ${result['medical_relevance_score']}\n';
                        }
                        webSearchSection += '\n';
                      }
                      finalCommonMessage += webSearchSection;
                    }

                    addMessage(finalCommonMessage,
                        isUser: false,
                        aiType: 'common_ai',
                        webResults: webSearchResults.isNotEmpty
                            ? webSearchResults
                            : null,
                        webMeta: webSearchMetadata);
                    logger.i('Added General AI response (General AI mode)');
                  } else {
                    // General AI failed
                    if (commonAiContent.contains('No reply from Mistral')) {
                      addMessage(
                          'General AI is currently experiencing technical difficulties. The Mistral AI service is temporarily unavailable.',
                          isUser: false,
                          aiType: 'common_ai');
                    } else {
                      addMessage(
                          'General AI couldn\'t process your request at the moment.',
                          isUser: false,
                          aiType: 'common_ai');
                    }
                    logger.w(
                        'No valid General AI response found - Content: "$commonAiContent"');
                  }

                  // Add MediAI response if available
                  if (mediAiContent.isNotEmpty &&
                      !mediAiContent.contains('No reply from Mistral')) {
                    String finalMediMessage = mediAiContent;

                    // Add web search results if available
                    if (webSearchResults.isNotEmpty) {
                      String webSearchSection =
                          '\n\n---\n### Relevant Resources:\n\n';

                      // Add metadata if available
                      if (webSearchMetadata != null) {
                        webSearchSection +=
                            '**Search Query:** ${webSearchMetadata['query']}\n';
                        webSearchSection +=
                            '**Total Results Found:** ${webSearchMetadata['total_results']}\n\n';
                      }

                      for (var result in webSearchResults) {
                        webSearchSection +=
                            '• **${result['title'] ?? 'Source'}**\n';
                        if (result['snippet'] != null) {
                          webSearchSection += '  ${result['snippet']}\n';
                        }
                        if (result['link'] != null) {
                          webSearchSection += '  Link: ${result['link']}\n';
                        }
                        if (result['source'] != null) {
                          webSearchSection += '  Source: ${result['source']}\n';
                        }
                        if (result['medical_relevance_score'] != null) {
                          webSearchSection +=
                              '  Relevance Score: ${result['medical_relevance_score']}\n';
                        }
                        webSearchSection += '\n';
                      }
                      finalMediMessage += webSearchSection;
                    }

                    addMessage(finalMediMessage,
                        isUser: false,
                        aiType: 'medi_ai',
                        webResults: webSearchResults.isNotEmpty
                            ? webSearchResults
                            : null,
                        webMeta: webSearchMetadata);
                    logger.i('Added MediAI response (General AI mode)');
                  } else {
                    // MediAI failed
                    if (mediAiContent.contains('No reply from Mistral')) {
                      addMessage(
                          'MediAI is currently experiencing technical difficulties. The Mistral AI service is temporarily unavailable.',
                          isUser: false,
                          aiType: 'medi_ai');
                    } else {
                      addMessage(
                          'MediAI couldn\'t process your request at the moment.',
                          isUser: false,
                          aiType: 'medi_ai');
                    }
                    logger.w(
                        'No valid MediAI response found - Content: "$mediAiContent"');
                  }
                }

                return; // Exit early since we added the message(s)
              } else {
                logger.w('Messages array is empty');
              }
            } else {
              // Fallback to old format
              logger.i(
                  'Using fallback format - looking for response/message/detail');
              aiResponse = data['response'] ??
                  data['message'] ??
                  data['detail'] ??
                  aiResponse;
              logger.i('Fallback response: $aiResponse');
              _removeTypingIndicator();

              String finalMessage = aiResponse;

              // Add web search results if available
              if (webSearchResults.isNotEmpty) {
                String webSearchSection =
                    '\n\n---\n### Relevant Resources:\n\n';

                // Add metadata if available
                if (webSearchMetadata != null) {
                  webSearchSection +=
                      '**Search Query:** ${webSearchMetadata['query']}\n';
                  webSearchSection +=
                      '**Total Results Found:** ${webSearchMetadata['total_results']}\n\n';
                }

                for (var result in webSearchResults) {
                  webSearchSection += '• **${result['title'] ?? 'Source'}**\n';
                  if (result['snippet'] != null) {
                    webSearchSection += '  ${result['snippet']}\n';
                  }
                  if (result['link'] != null) {
                    webSearchSection += '  Link: ${result['link']}\n';
                  }
                  if (result['source'] != null) {
                    webSearchSection += '  Source: ${result['source']}\n';
                  }
                  if (result['medical_relevance_score'] != null) {
                    webSearchSection +=
                        '  Relevance Score: ${result['medical_relevance_score']}\n';
                  }
                  webSearchSection += '\n';
                }
                finalMessage += webSearchSection;
              }

              if (_mediAiMode) {
                addMessage(finalMessage,
                    isUser: false,
                    aiType: 'medi_ai',
                    webResults:
                        webSearchResults.isNotEmpty ? webSearchResults : null,
                    webMeta: webSearchMetadata);
              } else {
                // General AI mode - show both responses
                addMessage(finalMessage,
                    isUser: false,
                    aiType: 'common_ai',
                    webResults:
                        webSearchResults.isNotEmpty ? webSearchResults : null,
                    webMeta: webSearchMetadata);
                addMessage('MediAI response not available in this format.',
                    isUser: false, aiType: 'medi_ai');
              }
            }
          } else if (response.data is String) {
            aiResponse = response.data as String;
            logger.i('Using string response data: $aiResponse');
            _removeTypingIndicator();

            String finalMessage = aiResponse;

            // Add web search results if available
            if (webSearchResults.isNotEmpty) {
              String webSearchSection = '\n\n---\n### Relevant Resources:\n\n';

              // Add metadata if available
              if (webSearchMetadata != null) {
                webSearchSection +=
                    '**Search Query:** ${webSearchMetadata['query']}\n';
                webSearchSection +=
                    '**Total Results Found:** ${webSearchMetadata['total_results']}\n\n';
              }

              for (var result in webSearchResults) {
                webSearchSection += '• **${result['title'] ?? 'Source'}**\n';
                if (result['snippet'] != null) {
                  webSearchSection += '  ${result['snippet']}\n';
                }
                if (result['link'] != null) {
                  webSearchSection += '  Link: ${result['link']}\n';
                }
                if (result['source'] != null) {
                  webSearchSection += '  Source: ${result['source']}\n';
                }
                if (result['medical_relevance_score'] != null) {
                  webSearchSection +=
                      '  Relevance Score: ${result['medical_relevance_score']}\n';
                }
                webSearchSection += '\n';
              }
              finalMessage += webSearchSection;
            }

            if (_mediAiMode) {
              addMessage(finalMessage,
                  isUser: false,
                  aiType: 'medi_ai',
                  webResults:
                      webSearchResults.isNotEmpty ? webSearchResults : null,
                  webMeta: webSearchMetadata);
            } else {
              // General AI mode - show both responses
              addMessage(finalMessage,
                  isUser: false,
                  aiType: 'common_ai',
                  webResults:
                      webSearchResults.isNotEmpty ? webSearchResults : null,
                  webMeta: webSearchMetadata);
              addMessage('MediAI response not available in this format.',
                  isUser: false, aiType: 'medi_ai');
            }
          }
        } else {
          logger.w('Response data is null');
          _removeTypingIndicator();

          String finalMessage = aiResponse;

          // Add web search results if available
          if (webSearchResults.isNotEmpty) {
            String webSearchSection = '\n\n---\n### Relevant Resources:\n\n';

            // Add metadata if available
            if (webSearchMetadata != null) {
              webSearchSection +=
                  '**Search Query:** ${webSearchMetadata['query']}\n';
              webSearchSection +=
                  '**Total Results Found:** ${webSearchMetadata['total_results']}\n\n';
            }

            for (var result in webSearchResults) {
              webSearchSection += '• **${result['title'] ?? 'Source'}**\n';
              if (result['snippet'] != null) {
                webSearchSection += '  ${result['snippet']}\n';
              }
              if (result['link'] != null) {
                webSearchSection += '  Link: ${result['link']}\n';
              }
              if (result['source'] != null) {
                webSearchSection += '  Source: ${result['source']}\n';
              }
              if (result['medical_relevance_score'] != null) {
                webSearchSection +=
                    '  Relevance Score: ${result['medical_relevance_score']}\n';
              }
              webSearchSection += '\n';
            }
            finalMessage += webSearchSection;
          }

          if (_mediAiMode) {
            addMessage(finalMessage,
                isUser: false,
                aiType: 'medi_ai',
                webResults:
                    webSearchResults.isNotEmpty ? webSearchResults : null,
                webMeta: webSearchMetadata);
          } else {
            // General AI mode - show both responses
            addMessage(finalMessage,
                isUser: false,
                aiType: 'common_ai',
                webResults:
                    webSearchResults.isNotEmpty ? webSearchResults : null,
                webMeta: webSearchMetadata);
            addMessage('MediAI response not available in this format.',
                isUser: false, aiType: 'medi_ai');
          }
        }

        logger.i('Chat response received successfully');
      } else {
        String errorMessage = response.message;

        // Handle specific error cases
        if (response.message.contains('Token decode error')) {
          errorMessage = 'Authentication error. Please login again.';
          // Clear invalid token
          await storage.clearUserData();
        } else if (response.message.contains('Not enough segments')) {
          errorMessage = 'Invalid authentication token. Please login again.';
          await storage.clearUserData();
        } else if (response.message.contains('Server error')) {
          errorMessage =
              'Server is temporarily unavailable. Please try again in a few moments.';
        } else if (response.code >= 500) {
          errorMessage = 'Server error. Please try again later.';
        } else if (response.code == 401) {
          errorMessage = 'Authentication required. Please login again.';
          await storage.clearUserData();
        } else if (response.code == 403) {
          errorMessage = 'Access denied. Please check your permissions.';
        } else if (response.code == 404) {
          errorMessage = 'Chat service not available. Please try again later.';
        } else if (response.message.contains('Unexpected response format')) {
          errorMessage =
              'Server returned an unexpected response format. Please try again.';
        }

        setError(errorMessage);
        _removeTypingIndicator();
        addMessage('Error: $errorMessage',
            isUser: false, aiType: _mediAiMode ? 'medi_ai' : 'common_ai');
        logger
            .e('Chat API error: ${response.message} (Code: ${response.code})');
      }
    } catch (e) {
      String errorMessage =
          'Network error. Please check your connection and try again.';
      setError(errorMessage);
      _removeTypingIndicator();
      addMessage('Error: $errorMessage',
          isUser: false, aiType: _mediAiMode ? 'medi_ai' : 'common_ai');
      logger.e('Chat error: $e');
    } finally {
      setLoading(false);
    }
  }

  // Get last message
  ChatMessage? get lastMessage => _messages.isNotEmpty ? _messages.last : null;

  // Check if last message is from user
  bool get isLastMessageFromUser => lastMessage?.isUser ?? false;

  // Toggle AI mode
  Future<void> toggleAiMode() async {
    setLoading(true);
    clearError();

    try {
      final response = await ApiService.toggleAiMode(!_mediAiMode);

      if (response.status && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        _mediAiMode = data['medi_ai_mode'] ?? false;
        _sessionId = data['session_id'];
        notifyListeners();
        logger.i('AI mode toggled successfully: medi_ai_mode=$_mediAiMode');
      } else {
        // Handle specific error cases
        if (response.code == 401) {
          setError('Please login again to use this feature.');
          // Clear invalid token
          final storage = await StorageService.getInstance();
          await storage.clearUserData();
        } else {
          setError(response.message);
        }
        logger.e('Failed to toggle AI mode: ${response.message}');
      }
    } catch (e) {
      setError('Failed to toggle AI mode. Please try again.');
      logger.e('Toggle AI mode error: $e');
    } finally {
      setLoading(false);
    }
  }

  // Initialize AI mode
  // Initialize AI mode when chat screen loads
  // Creates a new session using /session/new and stores the session_id
  // This is called when the user first opens the chat screen
  Future<void> initializeAiMode() async {
    try {
      // Check if user is logged in before initializing
      final storage = await StorageService.getInstance();
      final token = storage.getUserToken();

      if (token == null || token.isEmpty) {
        logger.w(
            'No authentication token found, skipping AI mode initialization');
        return;
      }

      // Create a new session using the proper endpoint
      // This calls POST /ai/api/session/new to get a session_id
      final response = await ApiService.startNewSession();

      if (response.status && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Store the session_id from the response
        _sessionId = data['session_id'];
        _mediAiMode = data['medi_ai_mode'] ?? data['medical_mode'] ?? true;

        notifyListeners();
        logger.i(
            'AI mode initialized with new session: session_id=$_sessionId, medi_ai_mode=$_mediAiMode');
      } else if (response.code == 401) {
        logger.w('Authentication failed during AI mode initialization');
      } else {
        logger.w('Failed to initialize session: ${response.message}');
      }
    } catch (e) {
      logger.e('Failed to initialize AI mode: $e');
    }
  }

  // Check AI service status
  Future<Map<String, bool>> checkAiServiceStatus() async {
    try {
      // Send a test message to check AI service status
      final testPayload = {
        'message': 'test',
        'use_mistral_only': false,
      };

      // Add session ID if available
      if (_sessionId != null && _sessionId!.isNotEmpty) {
        testPayload['session_id'] = _sessionId!;
      }

      final response = await ApiService.post(
        endpoint: UrlServices.CHAT,
        json: testPayload,
        useAuth: true,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('messages') && data['messages'] is List) {
          final messages = data['messages'] as List;
          if (messages.isNotEmpty) {
            final lastMessage = messages.last;
            if (lastMessage is Map<String, dynamic> &&
                lastMessage['role'] == 'assistant' &&
                lastMessage.containsKey('content')) {
              final content = lastMessage['content'];
              if (content is Map<String, dynamic>) {
                final mediAiContent = content['medi_ai']?.toString() ?? '';
                final commonAiContent = content['common_ai']?.toString() ?? '';

                return {
                  'medi_ai_available':
                      !mediAiContent.contains('No reply from Mistral'),
                  'common_ai_available':
                      !commonAiContent.contains('No reply from Mistral'),
                };
              }
            }
          }
        }
      }

      return {'medi_ai_available': false, 'common_ai_available': false};
    } catch (e) {
      logger.e('Failed to check AI service status: $e');
      return {'medi_ai_available': false, 'common_ai_available': false};
    }
  }

  // Load chat sessions history
  Future<void> loadSessions() async {
    setLoading(true);
    clearError();

    try {
      final response = await ApiService.getChatSessions();

      if (response.status && response.data != null) {
        final sessionsData = response.data as List;
        _sessions.clear();

        for (var sessionData in sessionsData) {
          if (sessionData is Map<String, dynamic>) {
            _sessions.add(ChatSession.fromJson(sessionData));
          }
        }

        notifyListeners();
        logger.i('Loaded ${_sessions.length} chat sessions');
      } else {
        setError(response.message);
        logger.e('Failed to load sessions: ${response.message}');
      }
    } catch (e) {
      setError('Failed to load chat history. Please try again.');
      logger.e('Load sessions error: $e');
    } finally {
      setLoading(false);
    }
  }

  // Delete a chat session
  /// DELETE https://drjebasingh.in/ai/api/session/{session_id}
  Future<bool> deleteSession(String sessionId) async {
    setLoading(true);
    clearError();

    try {
      final response = await ApiService.deleteSession(sessionId);

      if (response.status) {
        // Remove from local sessions list
        _sessions.removeWhere((s) => s.id == sessionId);

        // If this was the current session, clear it
        if (_sessionId == sessionId) {
          _sessionId = null;
          _messages.clear();
        }

        notifyListeners();
        logger.i('Deleted session: $sessionId');
        return true;
      } else {
        setError(response.message);
        logger.e('Failed to delete session: ${response.message}');
        return false;
      }
    } catch (e) {
      setError('Failed to delete session. Please try again.');
      logger.e('Delete session error: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // Load a specific session
  Future<void> loadSession(String sessionId) async {
    setLoading(true);
    clearError();

    logger.i('Loading session with ID: $sessionId');
    logger.i('Current session ID before loading: $_sessionId');
    logger.i(
        'Available sessions: ${_sessions.map((s) => '${s.id} (${s.title})').toList()}');

    try {
      // First, try to find the session in our current list
      ChatSession? session;
      try {
        session = _sessions.firstWhere((s) => s.id == sessionId);
        logger.i('Found session in current list: ${session.title}');
      } catch (e) {
        logger.w(
            'Session not found in current list, refreshing sessions list...');
        // If session not found in current list, refresh the sessions list
        await loadSessions();

        // Try to find it again after refresh
        try {
          session = _sessions.firstWhere((s) => s.id == sessionId);
          logger.i('Found session after refresh: ${session.title}');
        } catch (e2) {
          logger.e('Session still not found after refresh: $sessionId');
          throw Exception('Session not found: $sessionId');
        }
      }

      // Update current session info
      _sessionId = session.id;
      _mediAiMode = session.mediAiMode;
      logger.i(
          'Successfully loaded session: ${session.id} (${session.title}), mediAiMode: $_mediAiMode');

      // Clear current messages
      _messages.clear();
      logger.i('Cleared existing messages, starting to load session messages');

      // Load messages for this session
      await _loadSessionMessages(sessionId);

      notifyListeners();
      logger.i('Loaded session: ${session.title}');
    } catch (e) {
      setError('Failed to load session. Please try again.');
      logger.e('Load session error: $e');
    } finally {
      setLoading(false);
    }
  }

  // Ensure session is valid and prevent accidental session switching
  bool _isValidSession(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return false;

    // If we have a current session ID set, it's valid (it was loaded from the server)
    if (_sessionId == sessionId) return true;

    // Check if session exists in our sessions list
    bool existsInList = _sessions.any((session) => session.id == sessionId);

    // If session exists in our list, it's valid
    if (existsInList) return true;

    // If session doesn't exist in our list but we have a session ID set,
    // it might be a valid session that we loaded directly from the server
    // In this case, we should trust that it's valid if it's not empty
    return sessionId.isNotEmpty;
  }

  // Load messages for a specific session
  /// New API format: {"session_id": "...", "history": [{"role": "user", "content": "..."}], "total_messages": 4}
  Future<void> _loadSessionMessages(String sessionId) async {
    try {
      final response = await ApiService.getSessionMessages(sessionId);

      if (response.status && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        logger.i('Session data keys: ${data.keys.toList()}');

        // Handle the new API response format with "history" array
        if (data.containsKey('history') && data['history'] is List) {
          final historyData = data['history'] as List;
          logger.i('Found ${historyData.length} messages in session history');

          for (int i = 0; i < historyData.length; i++) {
            final messageData = historyData[i];
            logger.i('Processing message $i: $messageData');

            if (messageData is Map<String, dynamic>) {
              final role = messageData['role'] as String?;
              final content = messageData['content'];
              logger.i(
                  'Message $i - Role: $role, Content type: ${content.runtimeType}');

              if (role == 'user' && content is String) {
                // User message
                logger.i('Adding user message: $content');
                addMessage(content, isUser: true);
              } else if (role == 'assistant' && content is String) {
                // AI message - simple string content
                logger.i('Adding assistant message with string content');
                addMessage(content,
                    isUser: false,
                    aiType: _mediAiMode ? 'medi_ai' : 'common_ai');
              } else if (role == 'assistant' &&
                  content is Map<String, dynamic>) {
                // AI message - extract the appropriate content based on current mode
                logger.i(
                    'Processing assistant message. Current mediAiMode: $_mediAiMode');
                logger.i('Content keys: ${content.keys.toList()}');

                String messageText = '';
                String aiType = 'common_ai';

                if (_mediAiMode) {
                  messageText = content['medi_ai']?.toString() ?? '';
                  aiType = 'medi_ai';
                  logger.i(
                      'MediAI mode - extracted medi_ai content length: ${messageText.length}');
                } else {
                  messageText = content['common_ai']?.toString() ?? '';
                  aiType = 'common_ai';
                  logger.i(
                      'General AI mode - extracted common_ai content length: ${messageText.length}');
                }

                // If the selected AI mode has no content or shows Mistral error, try the other one
                if (messageText.isEmpty ||
                    messageText.contains('No reply from Mistral')) {
                  if (_mediAiMode &&
                      content['common_ai']?.toString().isNotEmpty == true &&
                      !content['common_ai']
                          .toString()
                          .contains('No reply from Mistral')) {
                    messageText = content['common_ai'].toString();
                    aiType = 'common_ai';
                  } else if (!_mediAiMode &&
                      content['medi_ai']?.toString().isNotEmpty == true &&
                      !content['medi_ai']
                          .toString()
                          .contains('No reply from Mistral')) {
                    messageText = content['medi_ai'].toString();
                    aiType = 'medi_ai';
                  }
                }

                // If still no valid content, show an appropriate message
                if (messageText.isEmpty ||
                    messageText.contains('No reply from Mistral')) {
                  if (_mediAiMode) {
                    messageText =
                        'MediAI is currently experiencing technical difficulties. The Mistral AI service is temporarily unavailable.';
                    aiType = 'medi_ai';
                  } else {
                    messageText =
                        'The AI service is currently experiencing technical difficulties. The Mistral AI service is temporarily unavailable.';
                    aiType = 'common_ai';
                  }
                }

                logger.i(
                    'Final message text length: ${messageText.length}, aiType: $aiType');
                addMessage(messageText, isUser: false, aiType: aiType);
              }
            }
          }
        }

        logger.i('Loaded ${_messages.length} messages for session $sessionId');
      } else {
        logger
            .w('No messages found for session $sessionId: ${response.message}');
      }
    } catch (e) {
      logger.e('Failed to load messages for session $sessionId: $e');
      // Don't throw error here, just log it - session switching should still work
    }
  }

  // Refresh sessions list
  Future<void> refreshSessions() async {
    await loadSessions();
  }

  // Refresh current session (reload messages without creating new session)
  Future<void> refreshCurrentSession() async {
    if (_sessionId != null && _isValidSession(_sessionId)) {
      logger.i('Refreshing current session: $_sessionId');
      await loadSession(_sessionId!);
    } else {
      logger.w(
          'No valid current session to refresh, loading sessions list instead');
      await loadSessions();
    }
  }

  // Debug method to log current session state
  void logSessionState() {
    logger.i('=== SESSION STATE DEBUG ===');
    logger.i('Current session ID: $_sessionId');
    logger.i('MediAI Mode: $_mediAiMode');
    logger.i('Number of loaded sessions: ${_sessions.length}');
    logger.i('Number of messages: ${_messages.length}');
    logger.i('Session IDs: ${_sessions.map((s) => s.id).toList()}');
    logger.i('Session titles: ${_sessions.map((s) => s.title).toList()}');
    logger.i('Is current session valid: ${_isValidSession(_sessionId)}');
    logger.i('========================');
  }

  // Debug method to manually set session ID (for testing)
  void setSessionIdForTesting(String sessionId) {
    logger.i('Manually setting session ID for testing: $sessionId');
    _sessionId = sessionId;
    notifyListeners();
  }

  // Load books for selection
  Future<void> loadBooks() async {
    setLoading(true);
    clearError();

    try {
      // List of books endpoints to try (in order of preference)
      final booksEndpoints = [
        UrlServices.BOOKS, // /ai/books (primary)
        UrlServices.BOOKS_API, // /api/books (fallback)
        UrlServices.BOOKS_V1, // /api/v1/books (fallback)
        UrlServices.BOOKS_LIST, // /books (fallback)
      ];

      for (final endpoint in booksEndpoints) {
        try {
          logger.i('Trying books endpoint: $endpoint');
          final response = await ApiService.getBooks(
            endpoint: endpoint,
            params: {},
            useAuth: false,
          );

          if (response.status && response.data != null) {
            final bookListResponse = BookListResponse.fromJson(response.data);
            _books.clear();
            _books.addAll(bookListResponse.books);
            _filterBooks(); // Initialize filtered books
            logger.i(
                'Loaded ${_books.length} books successfully from endpoint: $endpoint');
            setLoading(false);
            notifyListeners();
            return; // Success, exit completely
          } else if (response.code == 404) {
            // If 404, try next endpoint
            logger.w('Endpoint $endpoint not found (404), trying next...');
            continue;
          } else {
            // Other errors, show error message
            setError(response.message);
            logger
                .e('Failed to load books from $endpoint: ${response.message}');
            setLoading(false);
            return; // Exit completely
          }
        } catch (e) {
          logger.w('Error with endpoint $endpoint: $e');
          if (endpoint == booksEndpoints.last) {
            // This was the last endpoint, show error
            final errorMessage =
                'Failed to load books. All endpoints unavailable. Please check your internet connection and try again.';
            setError(errorMessage);
            logger.e('All books endpoints failed: $e');
            setLoading(false);
            return; // Exit completely
          }
          // Continue to next endpoint
        }
      }

      // If we get here, all endpoints failed - load mock data for development
      logger.w('Failed to fetch books');
      // logger.w('All books endpoints failed, loading mock data for development');
      // _loadMockBooks();
      setLoading(false);
      notifyListeners();
    } catch (e) {
      setError('Failed to load books. Please try again.');
      logger.e('Load books error: $e');
      setLoading(false);
    }
  }

  // Load mock books for development/testing
  void _loadMockBooks() {
    _books.clear();
    _books.addAll([
      Book(
        bookName: 'ESMO Handbook',
        title: 'ESMO Handbook of Clinical Oncology',
        totalPages: 450,
      ),
      Book(
        bookName: 'Gynecologic Oncology',
        title: 'Gynecologic Oncology Handbook',
        totalPages: 320,
      ),
      Book(
        bookName: 'medical_anatomy_101',
        title: 'Medical Anatomy 101',
        totalPages: 450,
      ),
      Book(
        bookName: 'pharmacology_guide',
        title: 'Complete Pharmacology Guide',
        totalPages: 320,
      ),
      Book(
        bookName: 'surgery_basics',
        title: 'Surgery Basics and Procedures',
        totalPages: 280,
      ),
      Book(
        bookName: 'diagnosis_manual',
        title: 'Clinical Diagnosis Manual',
        totalPages: 380,
      ),
      Book(
        bookName: 'emergency_medicine',
        title: 'Emergency Medicine Handbook',
        totalPages: 420,
      ),
      Book(
        bookName: 'cardiology_essentials',
        title: 'Cardiology Essentials',
        totalPages: 350,
      ),
    ]);
    _filterBooks(); // Initialize filtered books
    logger.i('Loaded ${_books.length} mock books for development');
  }

  // Toggle book selection
  void toggleBookSelection(String bookName) {
    if (_selectedBooks.contains(bookName)) {
      _selectedBooks.remove(bookName);
    } else {
      _selectedBooks.add(bookName);
    }
    notifyListeners();
    logger.i(
        'Book selection toggled: $bookName, selected: ${_selectedBooks.length}');
  }

  // Check if book is selected
  bool isBookSelected(String bookName) {
    return _selectedBooks.contains(bookName);
  }

  // Clear all selected books
  void clearSelectedBooks() {
    _selectedBooks.clear();
    notifyListeners();
    logger.i('Cleared all selected books');
  }

  // Select books for chat session
  Future<void> selectBooks() async {
    if (_selectedBooks.isEmpty) {
      setError('Please select at least one book to continue.');
      return;
    }

    setLoading(true);
    clearError();

    try {
      logger.i('Selecting books for chat: $_selectedBooks');

      final response = await ApiService.selectBooks(
        selectedBooks: _selectedBooks,
      );

      if (response.status) {
        logger.i('Books selected successfully via API');
        // Switch to new chat tab after successful selection
        // This will be handled by the UI
      } else if (response.code == 404) {
        // Endpoint not available, use local fallback
        logger.w(
            'Select books endpoint not available (404), using local fallback');
        _storeSelectedBooksLocally();
        logger.i('Books stored locally for chat context');
      } else {
        setError(response.message);
        logger.e('Failed to select books: ${response.message}');
      }
    } catch (e) {
      // If API fails completely, use local fallback
      logger.w('Select books API failed, using local fallback: $e');
      _storeSelectedBooksLocally();
      logger.i('Books stored locally for chat context');
    } finally {
      setLoading(false);
    }
  }

  // Store selected books locally as fallback
  void _storeSelectedBooksLocally() {
    // Store selected books in local storage for chat context
    // This ensures the chat knows which books are selected even if API is not available
    logger.i('Storing ${_selectedBooks.length} books locally: $_selectedBooks');
    // The selected books are already stored in _selectedBooks list
    // This will be used by the chat to provide context
  }

  // Get selected books titles for display
  List<String> getSelectedBooksTitles() {
    return _selectedBooks.map((bookName) {
      final book = _books.firstWhere(
        (b) => b.bookName == bookName,
        orElse: () => Book(bookName: bookName, title: bookName, totalPages: 0),
      );
      return book.title;
    }).toList();
  }

  // Search books by query
  void searchBooks(String query) {
    _searchQuery = query.trim();
    _filterBooks();
    notifyListeners();
    logger.i(
        'Searching books with query: "$_searchQuery", found ${_filteredBooks.length} results');
  }

  // Clear search query
  void clearSearch() {
    _searchQuery = '';
    _filterBooks();
    notifyListeners();
    logger.i('Search cleared, showing all ${_books.length} books');
  }

  // Filter books based on search query
  void _filterBooks() {
    if (_searchQuery.isEmpty) {
      _filteredBooks.clear();
      _filteredBooks.addAll(_books);
    } else {
      _filteredBooks.clear();
      _filteredBooks.addAll(_books.where((book) =>
          book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.bookName.toLowerCase().contains(_searchQuery.toLowerCase())));
    }
  }

  // Check if search is active
  bool get isSearchActive => _searchQuery.isNotEmpty;

  // Get search results count
  int get searchResultsCount => _filteredBooks.length;
}
