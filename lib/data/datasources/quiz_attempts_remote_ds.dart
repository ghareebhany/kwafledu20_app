import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/quiz_attempt_model.dart';
import 'dio_helpers.dart';

class QuizAttemptsRemoteDataSource {
  QuizAttemptsRemoteDataSource._();
  static final QuizAttemptsRemoteDataSource instance =
      QuizAttemptsRemoteDataSource._();

  Dio get _dio => DioClient.instance.dio;

  Object? _unwrap(Object? body) {
    if (body is Map<String, dynamic>) {
      if (body['success'] == true && body.containsKey('data')) return body['data'];
      if (body['status'] == 'success' && body.containsKey('data')) return body['data'];
    }
    return body;
  }

  Future<List<QuizAttemptModel>> getAttempts(int courseId) async {
    try {
      final res = await _dio.get(
        ApiConstants.quizAttemptsEndpoint,
        queryParameters: {'course_id': courseId},
      );
      final raw = _unwrap(res.data);
      if (raw == null) return [];
      final list = raw is List ? raw : [raw];
      return list
          .map((e) => QuizAttemptModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      return handleDioError(e, courseId: courseId);
    }
  }
}
