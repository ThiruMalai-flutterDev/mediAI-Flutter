import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_input_field.dart';
import '../viewmodels/chat_view_model.dart';

/// Chat screen with ASIRVATHAM SPECIALITY HOSPITAL branding
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Initialize AI mode when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatViewModel = context.read<ChatViewModel>();
      chatViewModel.initializeAiMode();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false, // Don't add bottom padding since we're in a tab view
        child: Stack(
          children: [
            Column(
              children: [
                // Chat Messages Area
                Expanded(
                  child: _buildChatContent(),
                ),

                // Chat Input (now includes AI toggle inside)
                _buildChatInput(),
              ],
            ),
            // Floating Action Button positioned above submit button
            Positioned(
              right: 4.w,
              bottom: 23.h, // Position above the text container
              child: _buildNewChatFAB(),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      // Add haptic feedback for better UX
      HapticFeedback.lightImpact();

      context.read<ChatViewModel>().sendMessage(message);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 4.w),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 3.w),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showClearBookConfirmationDialog(ChatViewModel chatViewModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3.w),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                color: Colors.orange[600],
                size: 5.w,
              ),
              SizedBox(width: 2.w),
              Text(
                'Clear Selected Book',
                style: TextStyle(
                  fontSize: 4.w,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to clear the selected book and start a new chat? This will remove the book context from your current conversation.',
            style: TextStyle(
              fontSize: 3.w,
              color: Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 3.w,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearSelectedBookAndStartNewChat(chatViewModel);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2.w),
                ),
              ),
              child: Text(
                'Clear & New Chat',
                style: TextStyle(
                  fontSize: 3.w,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearSelectedBookAndStartNewChat(
      ChatViewModel chatViewModel) async {
    try {
      // Clear the selected books
      chatViewModel.clearSelectedBooks();

      // Start a new chat session
      await chatViewModel.startNewSession();

      // Clear any existing messages
      _messageController.clear();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 4.w),
              SizedBox(width: 2.w),
              Text(
                'Book cleared and new chat started',
                style: TextStyle(fontSize: 3.w),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryPurple,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar(
          'Failed to clear book and start new chat. Please try again.');
      print('Error clearing book and starting new chat: $e');
    }
  }

  // Build chat content
  Widget _buildChatContent() {
    return Consumer<ChatViewModel>(
      builder: (context, chatViewModel, child) {
        // Auto-scroll to bottom after messages update so newest messages are visible
        if (chatViewModel.messages.isNotEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
        // Show error message if there's an error
        if (chatViewModel.hasError && chatViewModel.errorMessage.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showErrorSnackBar(chatViewModel.errorMessage);
            chatViewModel.clearError();
          });
        }

        return chatViewModel.isLoading && chatViewModel.messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primaryPurple,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Loading messages...',
                      style: TextStyle(
                        fontSize: 3.5.w,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Selected book header - always show when book is selected
                  if (chatViewModel.selectedBooks.isNotEmpty)
                    _buildSelectedBookHeader(chatViewModel),

                  // Messages list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        // Refresh the current session without creating a new one
                        // await chatViewModel.refreshCurrentSession();
                      },
                      color: AppColors.primaryPurple,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(4.w),
                        itemCount: chatViewModel.messages.isEmpty
                            ? 1 // Show empty state as first item
                            : chatViewModel.messages.length,
                        itemBuilder: (context, index) {
                          // Show empty state if no messages
                          if (chatViewModel.messages.isEmpty) {
                            return _buildEmptyState();
                          }
                          // Show message bubble
                          final message = chatViewModel.messages[index];
                          return _buildMessageBubble(message);
                        },
                      ),
                    ),
                  ),
                ],
              );
      },
    );
  }

  // Build chat input
  Widget _buildChatInput() {
    return Consumer<ChatViewModel>(
      builder: (context, chatViewModel, child) {
        return ChatInputField(
          controller: _messageController,
          onSend: _sendMessage,
          isLoading: chatViewModel.isLoading,
        );
      },
    );
  }

  // Build new chat floating action button
  Widget _buildNewChatFAB() {
    return Consumer<ChatViewModel>(
      builder: (context, chatViewModel, child) {
        return FloatingActionButton(
          onPressed: () {
            // Add haptic feedback
            HapticFeedback.lightImpact();

            // Start a new chat session
            chatViewModel.startNewSession();

            // Clear any existing messages
            _messageController.clear();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.chat, color: Colors.white, size: 4.w),
                    SizedBox(width: 2.w),
                    Text(
                      'New chat started',
                      style: TextStyle(fontSize: 3.w),
                    ),
                  ],
                ),
                backgroundColor: AppColors.primaryPurple,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          },
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          mini: true, // Make it smaller since it's positioned above input
          child: Icon(
            Icons.add_comment,
            size: 5.w,
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    // Determine AI type and styling
    bool isMediAI = message.aiType == 'medi_ai';
    bool isCommonAI = message.aiType == 'common_ai';
    bool isFallback = message.text.contains('temporarily unavailable') ||
        message.text.contains('found some') ||
        message.text.contains('might help');
    bool isError = message.text.startsWith('Error:');
    bool isTyping = message.text == 'typing...';

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 2.h),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 4.w,
              backgroundColor: isError
                  ? Colors.red.withOpacity(0.1)
                  : isMediAI
                      ? AppColors.primaryPurple.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
              child: Icon(
                isError
                    ? Icons.error_outline
                    : isMediAI
                        ? Icons.medical_services
                        : Icons.smart_toy,
                size: 4.w,
                color: isError
                    ? Colors.red
                    : isMediAI
                        ? AppColors.primaryPurple
                        : Colors.blue,
              ),
            ),
            SizedBox(width: 2.w),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: message.isUser
                    ? AppColors.primaryPurple
                    : isError
                        ? Colors.red[50]
                        : isMediAI
                            ? AppColors.primaryPurple.withOpacity(0.1)
                            : Colors.blue[50],
                border: !message.isUser && isError
                    ? Border.all(color: Colors.red.withOpacity(0.5), width: 2)
                    : !message.isUser
                        ? Border.all(
                            color: Colors.grey.withOpacity(0.2), width: 1)
                        : null,
                boxShadow: !message.isUser && !isError
                    ? [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.w),
                  topRight: Radius.circular(4.w),
                  bottomLeft: message.isUser
                      ? Radius.circular(4.w)
                      : Radius.circular(1.w),
                  bottomRight: message.isUser
                      ? Radius.circular(1.w)
                      : Radius.circular(4.w),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Type Badge
                  if (!message.isUser && (isMediAI || isCommonAI)) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMediAI ? Icons.healing : Icons.psychology,
                          size: 3.5.w,
                          color:
                              isMediAI ? AppColors.primaryPurple : Colors.blue,
                        ),
                        SizedBox(width: 1.5.w),
                        Text(
                          isMediAI ? 'Medical AI' : 'General AI',
                          style: TextStyle(
                            fontSize: 3.w,
                            fontWeight: FontWeight.w600,
                            color: isMediAI
                                ? AppColors.primaryPurple
                                : Colors.blue,
                          ),
                        ),
                        // Add fallback indicator if message contains fallback text
                        if (message.text.contains('temporarily unavailable') ||
                            message.text.contains('found some') ||
                            message.text.contains('might help')) ...[
                          SizedBox(width: 1.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 1.w, vertical: 0.2.h),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  size: 2.5.w,
                                  color: Colors.orange[700],
                                ),
                                SizedBox(width: 0.5.w),
                                Text(
                                  'Fallback',
                                  style: TextStyle(
                                    fontSize: 2.w,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 1.5.h),
                  ],

                  // Message Text
                  if (isFallback) ...[
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                      margin: EdgeInsets.only(bottom: 1.h),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 3.w,
                            color: Colors.orange[700],
                          ),
                          SizedBox(width: 1.w),
                          Expanded(
                            child: Text(
                              'This response is from a fallback service due to temporary unavailability.',
                              style: TextStyle(
                                fontSize: 2.5.w,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Message Text or Typing Indicator
                  if (isTyping)
                    _buildTypingIndicator()
                  else ...[
                    Text(
                      message.isUser
                          ? message.text
                          : _removeSymbols(message.text),
                      style: TextStyle(
                        fontSize: 3.5.w,
                        color:
                            message.isUser ? AppColors.white : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    // Optional Web Search results rendering
                    if (!message.isUser &&
                        message.webResults != null &&
                        message.webResults!.isNotEmpty) ...[
                      SizedBox(height: 1.5.h),
                      _buildWebResultsSection(message),
                    ],
                  ],
                  SizedBox(height: 0.5.h),

                  // Timestamp
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 2.2.w,
                      color: message.isUser
                          ? AppColors.white.withOpacity(0.7)
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: 2.w),
            CircleAvatar(
              radius: 4.w,
              backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
              child: Icon(
                Icons.person,
                size: 4.w,
                color: AppColors.primaryPurple,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  String _removeSymbols(String text) {
    return text
        .replaceAll(RegExp(r'#+'), '') // Remove # symbols
        .replaceAll(RegExp(r'\*+'), '') // Remove * symbols
        .replaceAll(RegExp(r'`+'), '') // Remove ` symbols
        .replaceAll(RegExp(r'~+'), '') // Remove ~ symbols
        .replaceAll(RegExp(r'_+'), '') // Remove _ symbols
        .replaceAll(RegExp(r'\|+'), '') // Remove | symbols
        .replaceAll(RegExp(r'\[|\]'), '') // Remove [ ] symbols
        .replaceAll(RegExp(r'\(|\)'), '') // Remove ( ) symbols
        .replaceAll(RegExp(r'\{|\}'), '') // Remove { } symbols
        .replaceAll(RegExp(r'<|>'), '') // Remove < > symbols
        .replaceAll(RegExp(r'!+'), '') // Remove ! symbols
        .replaceAll(RegExp(r'@+'), '') // Remove @ symbols
        .replaceAll(RegExp(r'%+'), '') // Remove % symbols
        .replaceAll(RegExp(r'\^+'), '') // Remove ^ symbols
        .replaceAll(RegExp(r'&+'), '') // Remove & symbols
        .replaceAll(RegExp(r'\++'), '') // Remove + symbols
        .replaceAll(RegExp(r'=+'), '') // Remove = symbols
        .replaceAll(RegExp(r'\\+'), '') // Remove \ symbols
        .replaceAll(RegExp(r'/+'), '') // Remove / symbols
        .replaceAll(
            RegExp(r'\\s+'), ' ') // Replace multiple spaces with single space
        .trim();
  }

  Widget _buildWebResultsSection(ChatMessage message) {
    final results = message.webResults ?? const [];
    final meta = message.webMeta ?? const {};
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.w),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language_outlined,
                  size: 4.w, color: AppColors.primaryPurple),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Relevant resources',
                  style: TextStyle(
                    fontSize: 3.2.w,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            SizedBox(height: 0.5.h),
            Text(
              '${meta['query'] != null ? 'Query: ${meta['query']}   ' : ''}${meta['total_results'] != null ? '(${meta['total_results']} results)' : ''}',
              style: TextStyle(fontSize: 2.4.w, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 1.h),
          Column(
            children: results.map((r) {
              final title = (r['title'] ?? 'Source').toString();
              final snippet = (r['snippet'] ?? '').toString();
              final link = (r['link'] ?? '').toString();
              final source = (r['source'] ?? '').toString();
              final score = r['medical_relevance_score'];
              return Container(
                margin: EdgeInsets.only(bottom: 1.h),
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(1.5.w),
                  border:
                      Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 3.w,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (snippet.isNotEmpty) ...[
                      SizedBox(height: 0.4.h),
                      Text(
                        snippet,
                        style:
                            TextStyle(fontSize: 2.6.w, color: Colors.black87),
                      ),
                    ],
                    SizedBox(height: 0.4.h),
                    Row(
                      children: [
                        if (source.isNotEmpty) ...[
                          Icon(Icons.source,
                              size: 2.8.w, color: Colors.grey[700]),
                          SizedBox(width: 1.w),
                          Flexible(
                            child: Text(
                              source,
                              style: TextStyle(
                                  fontSize: 2.4.w, color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (score != null) ...[
                          SizedBox(width: 2.w),
                          Icon(Icons.star_rate_rounded,
                              size: 3.w, color: Colors.amber[700]),
                          SizedBox(width: 0.5.w),
                          Text('Relevance: $score',
                              style: TextStyle(
                                  fontSize: 2.4.w, color: Colors.grey[700])),
                        ],
                      ],
                    ),
                    if (link.isNotEmpty) ...[
                      SizedBox(height: 0.6.h),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: link));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Link copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Text(
                          link,
                          style: TextStyle(
                            fontSize: 2.4.w,
                            color: AppColors.primaryPurple,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AI is typing',
          style: TextStyle(
            fontSize: 3.5.w,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        SizedBox(width: 2.w),
        _buildTypingDots(),
      ],
    );
  }

  Widget _buildTypingDots() {
    return SizedBox(
      width: 8.w,
      height: 2.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600),
            builder: (context, value, child) {
              // Create a wave effect with different phases for each dot
              final phase = (value + index * 0.3) % 1.0;
              final bounceValue = (sin(phase * 2 * 3.14159) + 1) / 2;

              return Transform.translate(
                offset: Offset(0, -bounceValue * 0.3.h),
                child: Container(
                  width: 1.5.w,
                  height: 1.5.w,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple
                        .withOpacity(0.3 + bounceValue * 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
            onEnd: () {
              // Restart animation
              if (mounted) {
                setState(() {});
              }
            },
          );
        }),
      ),
    );
  }

  // Build empty state
  Widget _buildSelectedBookHeader(ChatViewModel chatViewModel) {
    return Container(
      margin: EdgeInsets.all(4.w),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.book,
            color: AppColors.primaryPurple,
            size: 4.w,
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Book for Context',
                  style: TextStyle(
                    fontSize: 3.5.w,
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  chatViewModel.selectedBooks.first,
                  style: TextStyle(
                    fontSize: 3.w,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showClearBookConfirmationDialog(chatViewModel);
            },
            icon: Icon(
              Icons.clear,
              size: 3.w,
              color: Colors.red[600],
            ),
            label: Text(
              'Clear',
              style: TextStyle(
                fontSize: 2.5.w,
                color: Colors.red[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2.w),
                side: BorderSide(color: Colors.red[200]!, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Consumer<ChatViewModel>(
      builder: (context, chatViewModel, child) {
        return Container(
          width: double.infinity,
          color: AppColors.white,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 15.w,
                        color: AppColors.primaryPurple.withOpacity(0.3),
                      ),
                    );
                  },
                ),
                SizedBox(height: 2.h),
                Text(
                  'What can I help you with?',
                  style: TextStyle(
                    fontSize: 5.w,
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  chatViewModel.selectedBooks.isNotEmpty
                      ? 'Ask me anything about the selected book'
                      : 'Ask me anything about medical topics',
                  style: TextStyle(
                    fontSize: 3.2.w,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
