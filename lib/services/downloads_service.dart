import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Model for tracking downloaded files
class DownloadedFile {
  final String id;
  final String fileName;
  final String filePath;
  final String originalUrl;
  final int fileSize;
  final DateTime downloadedAt;
  final String title;
  final String? bookName;
  final String? chapterName;

  DownloadedFile({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.originalUrl,
    required this.fileSize,
    required this.downloadedAt,
    required this.title,
    this.bookName,
    this.chapterName,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'filePath': filePath,
    'originalUrl': originalUrl,
    'fileSize': fileSize,
    'downloadedAt': downloadedAt.toIso8601String(),
    'title': title,
    'bookName': bookName,
    'chapterName': chapterName,
  };

  /// Create from JSON
  factory DownloadedFile.fromJson(Map<String, dynamic> json) => DownloadedFile(
    id: json['id'] as String,
    fileName: json['fileName'] as String,
    filePath: json['filePath'] as String,
    originalUrl: json['originalUrl'] as String,
    fileSize: json['fileSize'] as int,
    downloadedAt: DateTime.parse(json['downloadedAt'] as String),
    title: json['title'] as String,
    bookName: json['bookName'] as String?,
    chapterName: json['chapterName'] as String?,
  );

  /// Check if file still exists on device
  Future<bool> exists() async {
    return await File(filePath).exists();
  }

  /// Get file size in MB
  double get fileSizeInMB => fileSize / (1024 * 1024);
}

/// Service for managing PDF downloads
class DownloadsService {
  static DownloadsService? _instance;
  late Directory _downloadsDir;
  late File _downloadsListFile;
  List<DownloadedFile> _downloadsList = [];
  bool _initialized = false;

  // Private constructor
  DownloadsService._();

  /// Get singleton instance
  static DownloadsService getInstance() {
    _instance ??= DownloadsService._();
    return _instance!;
  }

  /// Initialize the downloads service
  Future<void> init() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _downloadsDir = Directory('${appDir.path}/PDFs');

      // Create downloads directory if it doesn't exist
      if (!await _downloadsDir.exists()) {
        await _downloadsDir.create(recursive: true);
      }

      _downloadsListFile = File('${appDir.path}/downloads_list.json');

      // Load existing downloads list
      await _loadDownloadsList();
      _initialized = true;
    } catch (e) {
      print('Error initializing downloads service: $e');
    }
  }

  /// Load downloads list from storage
  Future<void> _loadDownloadsList() async {
    try {
      if (await _downloadsListFile.exists()) {
        final jsonString = await _downloadsListFile.readAsString();
        final jsonData = jsonDecode(jsonString) as List;
        _downloadsList = jsonData
            .map((item) => DownloadedFile.fromJson(item as Map<String, dynamic>))
            .toList();

        // Remove entries for files that no longer exist
        _downloadsList.removeWhere((file) => !File(file.filePath).existsSync());
        await _saveDownloadsList();
      }
    } catch (e) {
      print('Error loading downloads list: $e');
      _downloadsList = [];
    }
  }

  /// Save downloads list to storage
  Future<void> _saveDownloadsList() async {
    try {
      final jsonList = _downloadsList.map((file) => file.toJson()).toList();
      await _downloadsListFile.writeAsString(
        jsonEncode(jsonList),
        flush: true,
      );
    } catch (e) {
      print('Error saving downloads list: $e');
    }
  }

  /// Save PDF bytes to disk and add to downloads list
  Future<String?> savePdf(
    List<int> bytes,
    String fileName,
    String bookId,
  ) async {
    if (!_initialized) await init();

    try {
      final filePath = '${_downloadsDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      await addDownload(
        fileName: fileName,
        filePath: filePath,
        originalUrl: '', // Not known here
        fileSize: bytes.length,
        title: fileName.replaceAll('.pdf', '').replaceAll('_', ' '),
        bookName: bookId,
      );

      return filePath;
    } catch (e) {
      print('Error saving PDF: $e');
      return null;
    }
  }

  /// Add a downloaded file to the list
  Future<void> addDownload({
    required String fileName,
    required String filePath,
    required String originalUrl,
    required int fileSize,
    required String title,
    String? bookName,
    String? chapterName,
  }) async {
    final download = DownloadedFile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      filePath: filePath,
      originalUrl: originalUrl,
      fileSize: fileSize,
      downloadedAt: DateTime.now(),
      title: title,
      bookName: bookName,
      chapterName: chapterName,
    );

    _downloadsList.add(download);
    await _saveDownloadsList();
  }

  /// Get all downloads
  List<DownloadedFile> getAllDownloads() {
    return List.from(_downloadsList);
  }

  /// Get downloads by book
  List<DownloadedFile> getDownloadsByBook(String bookName) {
    return _downloadsList
        .where((file) => file.bookName == bookName)
        .toList();
  }

  /// Get a specific download by ID
  DownloadedFile? getDownloadById(String id) {
    try {
      return _downloadsList.firstWhere((file) => file.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete a download
  Future<bool> deleteDownload(String id) async {
    try {
      final download = getDownloadById(id);
      if (download != null) {
        final file = File(download.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        _downloadsList.removeWhere((file) => file.id == id);
        await _saveDownloadsList();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting download: $e');
      return false;
    }
  }

  /// Get downloads directory path
  String get downloadsDirPath => _downloadsDir.path;

  /// Get total downloads count
  int get downloadsCount => _downloadsList.length;

  /// Get total size of all downloads in MB
  double get totalSizeInMB {
    return _downloadsList.fold(
      0.0,
      (sum, file) => sum + file.fileSizeInMB,
    );
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    try {
      for (final download in _downloadsList) {
        final file = File(download.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _downloadsList.clear();
      await _saveDownloadsList();
    } catch (e) {
      print('Error clearing downloads: $e');
    }
  }

  /// Get storage info
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final dirSize = await _getDirectorySize(_downloadsDir);
      return {
        'downloadsCount': _downloadsList.length,
        'totalSize': dirSize,
        'totalSizeInMB': dirSize / (1024 * 1024),
        'downloadsPath': _downloadsDir.path,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Calculate directory size recursively
  Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (final file in dir.list(recursive: true)) {
          if (file is File) {
            size += await file.length();
          }
        }
      }
    } catch (e) {
      print('Error calculating directory size: $e');
    }
    return size;
  }
}
