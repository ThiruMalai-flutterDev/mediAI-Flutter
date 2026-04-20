import 'package:provider/provider.dart';
import '../viewmodels/login_view_model.dart';
import '../viewmodels/chat_view_model.dart';
import '../viewmodels/book_view_model.dart';
// import '../viewmodels/lesson_plan_view_model.dart';
import '../viewmodels/ai_question_builder_view_model.dart';

/// List of all providers used in the app
class AppProviders {
  static List<ChangeNotifierProvider> get providers => [
    ChangeNotifierProvider<LoginViewModel>(create: (_) => LoginViewModel()),
    ChangeNotifierProvider<ChatViewModel>(create: (_) => ChatViewModel()),
    ChangeNotifierProvider<BookViewModel>(create: (_) => BookViewModel()),
    ChangeNotifierProvider<AIQuestionBuilderViewModel>(create: (_) => AIQuestionBuilderViewModel()),
    // ChangeNotifierProvider<LessonPlanViewModel>(create: (_) => LessonPlanViewModel()),
  ];

  /// Get all providers as a list for MultiProvider
  static List<ChangeNotifierProvider> get allProviders => providers;
}
