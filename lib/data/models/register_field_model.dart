/// نموذج يمثّل حقلاً مخصصاً مُعرَّفاً في إضافة CUFM على WordPress
/// يُستخدم لبناء فورم التسجيل ديناميكياً دون تعديل Flutter عند إضافة حقول جديدة
class RegisterFieldModel {
  final String key;
  final String label;
  final String type;       // text | number | select | textarea
  final bool required;
  final List<String> options; // للـ select فقط
  final String placeholder;
  final int order;

  const RegisterFieldModel({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
    required this.placeholder,
    required this.order,
  });

  factory RegisterFieldModel.fromJson(Map<String, dynamic> json) {
    return RegisterFieldModel(
      key:         json['key']         as String? ?? '',
      label:       json['label']       as String? ?? '',
      type:        json['type']        as String? ?? 'text',
      required:    json['required']    as bool?   ?? false,
      options:     (json['options']    as List<dynamic>? ?? [])
                       .map((e) => e.toString())
                       .toList(),
      placeholder: json['placeholder'] as String? ?? '',
      order:       json['order']       as int?    ?? 0,
    );
  }
}
