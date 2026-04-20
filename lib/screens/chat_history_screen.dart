import 'package:dr_jebasingh_onco_ai/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../viewmodels/chat_view_model.dart';
import '../models/chat_session.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  final VoidCallback? onSessionSelected;

  const ChatHistoryScreen({super.key, this.onSessionSelected});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load chat sessions when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatViewModel>().loadSessions();
    });
  }

  // Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(
      ChatSession session, ChatViewModel chatViewModel) async {
    final confirmed = await showDialog<bool>(
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
                'Delete Chat',
                style: TextStyle(
                  fontSize: 4.w,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this chat session? This action cannot be undone.',
            style: TextStyle(
              fontSize: 3.w,
              color: Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 3.w,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2.w),
                ),
              ),
              child: Text(
                'Delete',
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

    if (confirmed == true) {
      final success = await chatViewModel.deleteSession(session.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 4.w),
                SizedBox(width: 2.w),
                Text(
                  'Chat session deleted',
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false, // Don't add bottom padding since we're in a tab view
        child: Container(
          padding: EdgeInsets.all(4.w),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              SizedBox(height: 2.h),

              // Sessions List
              Expanded(
                child: Consumer<ChatViewModel>(
                  builder: (context, chatViewModel, child) {
                    return chatViewModel.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryPurple,
                            ),
                          )
                        : chatViewModel.sessions.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: () =>
                                    chatViewModel.refreshSessions(),
                                color: AppColors.primaryPurple,
                                child: ListView.builder(
                                  itemCount: chatViewModel.sessions.length,
                                  itemBuilder: (context, index) {
                                    final session =
                                        chatViewModel.sessions[index];
                                    return _buildSessionItem(
                                        session, chatViewModel);
                                  },
                                ),
                              );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.history,
          size: 5.w,
          color: AppColors.primaryPurple,
        ),
        SizedBox(width: 2.w),
        Text(
          'Chat History',
          style: TextStyle(
            fontSize: 4.w,
            color: AppColors.primaryPurple,
            fontWeight: FontWeight.w600,
          ),
        ),
        Spacer(),
        Consumer<ChatViewModel>(
          builder: (context, chatViewModel, child) {
            return IconButton(
              onPressed: () => chatViewModel.refreshSessions(),
              icon: Icon(
                Icons.refresh,
                color: AppColors.primaryPurple,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 15.w,
            color: Colors.grey[400],
          ),
          SizedBox(height: 2.h),
          Text(
            'No chat history yet',
            style: TextStyle(
              fontSize: 4.w,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Start a conversation to see it here',
            style: TextStyle(
              fontSize: 3.w,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 3.h),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to chat screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChatScreen(),
                ),
              );
            },
            icon: Icon(Icons.chat),
            label: Text('Start Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(ChatSession session, ChatViewModel chatViewModel) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: session.id == chatViewModel.sessionId
              ? AppColors.primaryPurple
              : Colors.grey[200]!,
          width: session.id == chatViewModel.sessionId ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        leading: CircleAvatar(
          backgroundColor: session.mediAiMode
              ? AppColors.primaryPurple.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
          child: Icon(
            session.mediAiMode ? Icons.medical_services : Icons.smart_toy,
            color: session.mediAiMode ? AppColors.primaryPurple : Colors.blue,
            size: 5.w,
          ),
        ),
        title: Text(
          session.title,
          style: TextStyle(
            fontSize: 3.5.w,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 0.5.h),
            Text(
              session.lastMessagePreview,
              style: TextStyle(
                fontSize: 2.8.w,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 0.5.h),
            Row(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.3.h),
                  decoration: BoxDecoration(
                    color: session.mediAiMode
                        ? AppColors.primaryPurple.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.aiModeText,
                    style: TextStyle(
                      fontSize: 2.2.w,
                      color: session.mediAiMode
                          ? AppColors.primaryPurple
                          : Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                Text(
                  session.formattedDate,
                  style: TextStyle(
                    fontSize: 2.2.w,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (session.id == chatViewModel.sessionId)
              Icon(
                Icons.check_circle,
                color: AppColors.primaryPurple,
                size: 5.w,
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 4.w,
              ),
            SizedBox(width: 1.w),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red[400],
                size: 5.w,
              ),
              onPressed: () => _showDeleteConfirmation(session, chatViewModel),
              tooltip: 'Delete session',
            ),
          ],
        ),
        onTap: () {
          if (session.id != chatViewModel.sessionId) {
            chatViewModel.loadSession(session.id);
            // Switch to chat tab using callback
            if (widget.onSessionSelected != null) {
              widget.onSessionSelected!();
            }
          }
        },
      ),
    );
  }
}
