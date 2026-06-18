import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/qna_model.dart';
import 'dio_helpers.dart';

class QnaRemoteDataSource {
  QnaRemoteDataSource._();
  static final QnaRemoteDataSource instance = QnaRemoteDataSource._();

  Dio get _dio => DioClient.instance.dio;

  Object? _unwrap(Object? body) {
    if (body is Map<String, dynamic>) {
      if (body['success'] == true && body.containsKey('data')) return body['data'];
      if (body['status'] == 'success' && body.containsKey('data')) return body['data'];
    }
    return body;
  }

  Future<List<QnaModel>> getQna(int courseId, {int page = 1}) async {
    try {
      final res = await _dio.get(
        ApiConstants.qnaEndpoint,
        queryParameters: {'course_id': courseId, 'page': page},
      );
      final raw = _unwrap(res.data);
      if (raw == null) return [];
      final list = raw is List ? raw : [raw];
      return list
          .map((e) => QnaModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      return handleDioError(e, courseId: courseId);
    }
  }

  Future<bool> postQna({
    required int courseId,
    required String content,
    int parentId = 0,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.qnaEndpoint,
        data: {
          'course_id': courseId,
          'content': content,
          'parent_id': parentId,
        },
      );
      final raw = _unwrap(res.data);
      if (raw is Map) return raw['id'] != null;
      return (res.statusCode ?? 0) < 300;
    } on DioException catch (e) {
      return handleDioError(e, courseId: courseId);
    }
  }
}
