import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/register_field_model.dart';

class RegisterRemoteDataSource {
  RegisterRemoteDataSource._();
  static final RegisterRemoteDataSource instance = RegisterRemoteDataSource._();

  Dio get _dio => DioClient.instance.dio;

  /// جلب تعريفات الحقول المخصصة من WordPress/CUFM
  /// [role]: 'student' | 'instructor'
  Future<List<RegisterFieldModel>> fetchFields(String role) async {
    final res = await _dio.get(
      ApiConstants.registerFieldsEndpoint,
      queryParameters: {'role': role},
      options: Options(extra: {'skipAuth': true}),
    );
    final body = res.data as Map<String, dynamic>? ?? {};
    final list  = body['fields'] as List<dynamic>? ?? [];
    return list
        .map((e) => RegisterFieldModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// تسجيل مستخدم جديد مع الحقول المخصصة
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required Map<String, dynamic> customFields,
  }) async {
    await _dio.post(
      ApiConstants.registerEndpoint,
      data: {
        'email':    email,
        'password': password,
        'name':     name,
        'role':     role,
        ...customFields, // حقول CUFM مدمجة مباشرة
      },
      options: Options(
        extra: {'skipAuth': true},
      ),
    );
  }
}
