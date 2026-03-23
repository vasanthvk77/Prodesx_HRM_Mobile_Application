import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_config.dart';

final faceServiceProvider = Provider((ref) => FaceService());

class FaceService {
  final Dio _dio = Dio();
  
  // Use "localhost" for Web (Antigravity) and "10.0.2.2" for Android Emulator
  static const String pythonUrl = "http://localhost:8000"; 
  static const String dotnetUrl = "http://localhost:5217/api/FaceAttendance";

  Future<Map<String, dynamic>> registerFace({
    required String employeeId,
    required String role,
    required List<List<int>> images,
    int? userId,
  }) async {
    try {
      // 1. Get embedding from Python for each image (taking the first successful one for simplicity)
      // In a real app, you might average them on the server or client.
      // Our new Python /get-embedding takes one file at a time.
      
      List<double>? finalEmbedding;
      
      for (var bytes in images) {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: 'reg.jpg'),
        });
        
        final pyResponse = await _dio.post("$pythonUrl/get-embedding", data: formData);
        if (pyResponse.data['status'] == 'success') {
          finalEmbedding = List<double>.from(pyResponse.data['embedding']);
          break; // Use the first good one
        }
      }

      if (finalEmbedding == null) {
        return {'status': 'error', 'message': 'Could not generate face embedding from images.'};
      }

      // 2. Send to .NET for storage
      final dotnetResponse = await _dio.post(
        "$dotnetUrl/register-embedding", 
        data: {
          'EmployeeId': employeeId,
          'Role': role,
          'Embedding': finalEmbedding,
          'UserId': userId
        }
      );
      
      return dotnetResponse.data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyFace(List<List<int>> images) async {
    try {
      // 1. Get embedding from the current frame via Python
      if (images.isEmpty) return {'status': 'error', 'message': 'No images captured'};
      
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(images.last, filename: 'verify.jpg'),
      });

      final pyResponse = await _dio.post("$pythonUrl/get-embedding", data: formData);
      if (pyResponse.data['status'] != 'success') {
        return pyResponse.data;
      }

      List<double> queryEmbedding = List<double>.from(pyResponse.data['embedding']);

      // 2. Match via .NET
      final matchResponse = await _dio.post(
        "$dotnetUrl/match-embedding",
        data: { 'QueryEmbedding': queryEmbedding }
      );

      return matchResponse.data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markAttendance({
    required String employeeId,
    required String role,
    int? userId,
  }) async {
    try {
      final response = await _dio.post(
        "$dotnetUrl/mark", 
        data: {
          'EmployeeId': employeeId,
          'Role': role,
          'PunchedInType': 'face',
          'UserId': userId
        }
      );
      return response.data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> detectPose(List<int> imageBytes) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(imageBytes, filename: 'pose.jpg'),
      });

      final response = await _dio.post(
        '$pythonUrl/detect-pose',
        data: formData,
      );

      return response.data;
    } catch (e) {
      return {'pose': 'None', 'error': e.toString()};
    }
  }
}
