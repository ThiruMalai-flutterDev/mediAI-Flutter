import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../viewmodels/chat_view_model.dart';

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const ChatInputField({
    Key? key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Text Input Field with AI Mode Toggle and Send Button
          Expanded(
            child: Consumer<ChatViewModel>(
              builder: (context, chatViewModel, child) {
                return Container(
                  padding: EdgeInsets.all(1.2.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4.w),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // First Row: Text Field + Send Button
                      Row(
                        children: [
                          // Text Field
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                hintText: chatViewModel.selectedBooks.isNotEmpty
                                    ? 'Ask about the selected book...'
                                    : chatViewModel.mediAiMode
                                        ? 'Ask about medical topics...'
                                        : 'Ask me anything...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 4.w,
                                ),
                                border: InputBorder.none,
                                filled: false,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 2.5.w,
                                  vertical: 3.5.h,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 4.w,
                                color: AppColors.primaryPurple,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => onSend(),
                            ),
                          ),

                          SizedBox(width: 1.5.w),

                          // Send Button - Inside the Text Field
                          GestureDetector(
                            onTap: isLoading
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    onSend();
                                  },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.all(1.5.w),
                              decoration: BoxDecoration(
                                color: isLoading
                                    ? Colors.grey[300]
                                    : AppColors.primaryPurple,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: isLoading
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppColors.primaryPurple
                                              .withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: isLoading
                                  ? SizedBox(
                                      width: 4.w,
                                      height: 4.w,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.grey[600],
                                      ),
                                    )
                                  : Icon(
                                      Icons.send_rounded,
                                      color: AppColors.white,
                                      size: 4.5.w,
                                    ),
                            ),
                          ),
                        ],
                      ),

                      // Second Row: AI Mode Toggle and Web Search Toggle
                      // SizedBox(height: 1.h),
                      // Row(
                      //   children: [
                      //     SizedBox(width: 4.w),
                      //     // AI mode toggle (hidden if a book is selected)
                      //     if (chatViewModel.selectedBooks.isEmpty)
                      //       Container(
                      //         padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.8.h),
                      //         decoration: BoxDecoration(
                      //           color: Colors.white,
                      //           borderRadius: BorderRadius.circular(4),
                      //           boxShadow: [
                      //             BoxShadow(
                      //               color: Colors.grey.withOpacity(0.15),
                      //               blurRadius: 4,
                      //               offset: Offset(0, 1),
                      //             ),
                      //           ],
                      //         ),
                      //         child: Row(
                      //           mainAxisSize: MainAxisSize.min,
                      //           children: [
                      //             GestureDetector(
                      //               onTap: () {
                      //                 if (!chatViewModel.mediAiMode) {
                      //                   chatViewModel.toggleAiMode();
                      //                 }
                      //               },
                      //               child: Container(
                      //                 padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.6.h),
                      //                 decoration: BoxDecoration(
                      //                   color: chatViewModel.mediAiMode ? AppColors.primaryPurple : Colors.transparent,
                      //                   borderRadius: BorderRadius.circular(3),
                      //                 ),
                      //                 child: Text(
                      //                   'MediAI',
                      //                   style: TextStyle(
                      //                     fontSize: 2.2.w,
                      //                     fontWeight: FontWeight.w600,
                      //                     color: chatViewModel.mediAiMode ? Colors.white : Colors.grey[600],
                      //                   ),
                      //                 ),
                      //               ),
                      //             ),
                      //             SizedBox(width: 0.3.w),
                      //             GestureDetector(
                      //               onTap: () {
                      //                 if (chatViewModel.mediAiMode) {
                      //                   chatViewModel.toggleAiMode();
                      //                 }
                      //               },
                      //               child: Container(
                      //                 padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
                      //                 decoration: BoxDecoration(
                      //                   color: !chatViewModel.mediAiMode ? AppColors.primaryPurple : Colors.transparent,
                      //                   borderRadius: BorderRadius.circular(3),
                      //                 ),
                      //                 child: Text(
                      //                   'General',
                      //                   style: TextStyle(
                      //                     fontSize: 2.2.w,
                      //                     fontWeight: FontWeight.w600,
                      //                     color: !chatViewModel.mediAiMode ? Colors.white : Colors.grey[600],
                      //                   ),
                      //                 ),
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //       ),
                      //     if (chatViewModel.selectedBooks.isNotEmpty) Spacer(),
                      //     if (chatViewModel.selectedBooks.isEmpty) SizedBox(width: 1.5.w) else SizedBox(width: 0),
                      //     // Globe Icon - Web Search Toggle (always visible)
                      //     GestureDetector(
                      //       onTap: () {
                      //         HapticFeedback.lightImpact();
                      //         chatViewModel.toggleWebSearch();
                      //       },
                      //       child: Container(
                      //         padding: EdgeInsets.all(1.w),
                      //         decoration: BoxDecoration(
                      //           color: chatViewModel.webSearchEnabled ? AppColors.primaryPurple.withOpacity(0.1) : Colors.white,
                      //           borderRadius: BorderRadius.circular(4),
                      //           border: chatViewModel.webSearchEnabled ? Border.all(color: AppColors.primaryPurple, width: 1.5) : null,
                      //           boxShadow: [
                      //             BoxShadow(
                      //               color: chatViewModel.webSearchEnabled ? AppColors.primaryPurple.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
                      //               blurRadius: 4,
                      //               offset: Offset(0, 1),
                      //             ),
                      //           ],
                      //         ),
                      //         child: Icon(
                      //           Icons.language_outlined,
                      //           size: 5.5.w,
                      //           color: chatViewModel.webSearchEnabled ? AppColors.primaryPurple : Colors.grey[600],
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
