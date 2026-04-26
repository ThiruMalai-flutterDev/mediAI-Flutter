/// URL services for API endpoints
class UrlServices {
  // Base URL - Your actual API base URL
  static const String BASE_URL = 'https://drjebasingh.in';

  // CORS Proxy for development (uncomment to use)
  // static const String BASE_URL = 'https://cors-anywhere.herokuapp.com/https://drjebasingh.in';

  // Authentication endpoints
  static const String LOGIN = 'api/api/login'; // Primary login endpoint
  static const String LOGIN_ALT = 'api/login'; // Alternative login endpoint
  static const String LOGIN_AUTH = 'auth/login'; // Auth prefix login
  static const String LOGIN_V1 = 'api/v1/login'; // Versioned API login
  static const String REGISTER = 'auth/register';
  static const String LOGOUT = 'auth/logout';
  static const String REFRESH_TOKEN = 'auth/refresh';
  static const String FORGOT_PASSWORD = 'auth/forgot-password';
  static const String RESET_PASSWORD = 'auth/reset-password';

  // User endpoints
  static const String USER_PROFILE = 'api/user/profile';
  static const String UPDATE_PROFILE = 'api/user/update';
  static const String CHANGE_PASSWORD = 'api/user/change-password';

  // Media endpoints
  static const String UPLOAD_SINGLE_FILE = 'api/media/upload';
  static const String UPLOAD_MULTIPLE_FILES = 'api/media/upload-multiple';
  static const String GET_MEDIA = 'api/media/list';
  static const String DELETE_MEDIA = 'api/media/delete';

  // Social login endpoints
  static const String GOOGLE_LOGIN = 'api/auth/google';
  static const String FACEBOOK_LOGIN = 'api/auth/facebook';
  static const String APPLE_LOGIN = 'api/auth/apple';

  // Books endpoints
  static const String BOOKS = 'ai/books'; // Primary books endpoint
  static const String BOOKS_API = 'api/books'; // API books endpoint
  static const String BOOKS_V1 = 'api/v1/books'; // Versioned books endpoint
  static const String BOOKS_LIST = 'ai/api/books'; // Simple books endpoint
  static const String BOOKS_LIST_CATEGORIZED =
      'ai/books-list'; // Categorized books (chapter vs non-chapter)
  static const String BOOKS_CHAPTER = 'ai/books/chapter'; // Chapter-wise books
  static const String BOOKS_NON_CHAPTER =
      'ai/books/non-chapter'; // Non-chapter books
  static const String AI_BOOK = 'ai/book'; // Base for specific book routes
  static const String AI_BOOKS =
      'ai/books'; // Base for specific book routes (plural)

  // Exams / Question generation
  static const String EXAMS = 'api/exams';
  static const String GENERATE_QUESTIONS = 'ai/api/exam/generate-exam';
  static const String LIST_USER_EXAMS = 'ai/books/names/all-collections';
  static const String GET_EXAM = 'ai/exam';

  // Search endpoints
  static const String SEARCH_BOOKS = 'ai/search'; // Search books endpoint

  // Chat endpoints
  static const String CHAT =
      'ai/api/chat/'; // Chat with AI endpoint (with trailing slash)
  static const String NEW_SESSION =
      'ai/api/session/new'; // Start new chat session (POST)
  static const String SESSION_HISTORY =
      'ai/api/session/{session_id}/history'; // Get session history (GET)
  static const String DELETE_SESSION =
      'ai/api/session/{session_id}'; // Delete session (DELETE)
  static const String SESSIONS = 'ai/api/sessions'; // Get chat sessions history
  static const String SESSION_MESSAGES =
      'ai/api/session'; // Get messages for specific session
  static const String SELECT_BOOKS =
      'ai/api/select_books'; // Select books for chat context
  static const String TOGGLE_BOOKS_MODE =
      'ai/api/toggle_books_mode'; // Toggle chapter/non-chapter mode

  // Lesson Plan endpoints
  static const String LESSON_PLAN_GENERATE =
      'ai/api/lessons/generate-lesson-plan'; // AI generation endpoint
  static const String LESSON_PLAN_PDF =
      'api/lessons/generate-lesson-plan/pdf'; // Lesson plan PDF generation
  static const String LESSON_PLANS =
      'api/lesson-plans'; // CRUD endpoint for lesson plans
  static const String LESSON_PLANS_RANGE =
      'api/lesson-plans'; // Get lesson plans by date range

  // Other endpoints
  static const String HEALTH_CHECK = 'api/health';
  static const String APP_VERSION = 'api/app/version';
  static const String NOTIFICATIONS = 'api/notifications';
  static const String SETTINGS = 'api/settings';
}
