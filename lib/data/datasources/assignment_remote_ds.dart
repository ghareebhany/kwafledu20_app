import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/assignment_model.dart';
import 'dio_helpers.dart';

class AssignmentRemoteDataSource {
  AssignmentRemoteDataSource._();
  static final AssignmentRemoteDataSource instance =
      AssignmentRemoteDataSource._();

  Dio get _dio => DioClient.instance.dio;

  Object? _unwrap(Object? body) {
    if (body is Map<String, dynamic>) {
      if (body['success'] == true && body.containsKey('data')) {
        return body['data'];
      }
      if (body['status'] == 'success' && body.containsKey('data')) {
        return body['data'];
      }
    }
    return body;
  }

  Future<List<AssignmentModel>> getAssignments(int courseId) async {
    try {
      final res = await _dio.get(
        ApiConstants.assignmentsEndpoint,
        queryParameters: {'course_id': courseId},
      );
      final raw = _unwrap(res.data);
      if (raw == null) return [];
      final list = raw is List ? raw : [raw];
      return list
          .map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      return handleDioError(e, courseId: courseId);
    }
  }

  Future<AssignmentModel> getAssignment(int assignmentId) async {
    try {
      final res =
          await _dio.get(ApiConstants.assignmentDetailEndpoint(assignmentId));
      final raw = _unwrap(res.data);
      return AssignmentModel.fromJson(raw as Map<String, dynamic>);
    } on DioException catch (e) {
      return handleDioError(e);
    }
  }

  Future<AssignmentSubmissionModel> submitAssignment({
    required int assignmentId,
    required int courseId,
    String answer = '',
    List<File> files = const [],
  }) async {
    try {
      final formMap = <String, dynamic>{'answer': answer};
      if (files.isNotEmpty) {
        formMap['files[]'] = [
          for (final f in files)
            await MultipartFile.fromFile(f.path,
                filename: f.path.split('/').last),
        ];
      }
      final formData = FormData.fromMap(formMap);
      final res = await _dio.post(
        ApiConstants.assignmentSubmitEndpoint(assignmentId),
        data: formData,
      );
      final raw = _unwrap(res.data);
      return AssignmentSubmissionModel.fromJson(raw as Map<String, dynamic>);
    } on DioException catch (e) {
      return handleDioError(e, courseId: courseId);
    }
  }
}
