import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/login_view_model.dart';
import 'viewmodels/chat_view_model.dart';
import 'viewmodels/book_view_model.dart';
import 'viewmodels/ai_question_builder_view_model.dart';
import 'viewmodels/lesson_plan_view_model.dart';
import 'viewmodels/exam_view_model.dart';

void main() {
  // Initialize API service
  ApiService.init();
  
  // Uncomment the line below to debug all endpoints on app startup
  // ApiService.debugAllEndpoints();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LoginViewModel>(create: (_) => LoginViewModel()),
        ChangeNotifierProvider<ChatViewModel>(create: (_) => ChatViewModel()),
        ChangeNotifierProvider<BookViewModel>(create: (_) => BookViewModel()),
        ChangeNotifierProvider<AIQuestionBuilderViewModel>(create: (_) => AIQuestionBuilderViewModel()),
        ChangeNotifierProvider<ExamViewModel>(create: (_) => ExamViewModel()),
        ChangeNotifierProvider<LessonPlanViewModel>(create: (_) => LessonPlanViewModel()),
      ],
      child: MaterialApp(
        title: 'Dr jebasingh onco ai',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: Sizer(
          builder: (context, orientation, deviceType) {
            return const SplashScreen();
          },
        ),
      ),
    );
  }
}
