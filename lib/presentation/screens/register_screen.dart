import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../data/datasources/register_remote_ds.dart';
import '../../data/models/register_field_model.dart';

// ── Provider: يجلب تعريفات الحقول حسب الدور ────────────────────────────
final _registerFieldsProvider =
    FutureProvider.family<List<RegisterFieldModel>, String>((ref, role) async {
  return RegisterRemoteDataSource.instance.fetchFields(role);
});

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  // controllers للحقول المخصصة — تُنشأ ديناميكياً
  final Map<String, TextEditingController> _customCtrl  = {};
  // قيم select المختارة
  final Map<String, String>               _selectValues = {};

  bool   _obscure1  = true;
  bool   _obscure2  = true;
  bool   _isLoading = false;
  String _role      = 'student'; // student | instructor

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    for (final c in _customCtrl.values) c.dispose();
    super.dispose();
  }

  // ── إرسال الفورم ─────────────────────────────────────────────────────────
  Future<void> _submit(List<RegisterFieldModel> fields) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // جمع قيم الحقول المخصصة
      final Map<String, dynamic> customFields = {};
      for (final field in fields) {
        if (field.type == 'select') {
          final val = _selectValues[field.key] ?? '';
          if (val.isNotEmpty) customFields[field.key] = val;
        } else {
          final val = _customCtrl[field.key]?.text.trim() ?? '';
          if (val.isNotEmpty) customFields[field.key] = val;
        }
      }

      await RegisterRemoteDataSource.instance.register(
        email:        _emailCtrl.text.trim(),
        password:     _passwordCtrl.text,
        name:         _nameCtrl.text.trim(),
        role:         _role,
        customFields: customFields,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الحساب بنجاح. يمكنك تسجيل الدخول الآن.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        context.go('/login');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map)
          ? (data['message'] as String? ?? 'فشل إنشاء الحساب')
          : 'فشل إنشاء الحساب، يرجى المحاولة مرة أخرى';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── بناء حقل مخصص ────────────────────────────────────────────────────────
  Widget _buildCustomField(RegisterFieldModel field) {
    // أنشئ controller إن لم يوجد
    _customCtrl.putIfAbsent(field.key, () => TextEditingController());

    final cs = Theme.of(context).colorScheme;
    final decoration = InputDecoration(
      labelText: field.label + (field.required ? ' *' : ''),
      labelStyle: const TextStyle(),
      hintText: field.placeholder.isNotEmpty ? field.placeholder : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
    );

    String? Function(String?)? validator = field.required
        ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل إلزامي' : null
        : null;

    switch (field.type) {
      // ── Select ──────────────────────────────────────────────────────────
      case 'select':
        return DropdownButtonFormField<String>(
          value: _selectValues[field.key],
          decoration: decoration,
          hint: Text('اختر ${field.label}'),
          items: field.options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _selectValues[field.key] = v ?? ''),
          validator: field.required
              ? (v) => (v == null || v.isEmpty) ? 'هذا الحقل إلزامي' : null
              : null,
        );

      // ── Textarea ─────────────────────────────────────────────────────────
      case 'textarea':
        return TextFormField(
          controller: _customCtrl[field.key],
          textDirection: TextDirection.rtl,
          maxLines: 3,
          decoration: decoration,
          validator: validator,
        );

      // ── Number ───────────────────────────────────────────────────────────
      case 'number':
        return TextFormField(
          controller: _customCtrl[field.key],
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: decoration,
          validator: (v) {
            if (field.required && (v == null || v.trim().isEmpty)) {
              return 'هذا الحقل إلزامي';
            }
            if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
              return 'يجب أن يكون رقماً';
            }
            return null;
          },
        );

      // ── Text (الافتراضي) ─────────────────────────────────────────────────
      default:
        return TextFormField(
          controller: _customCtrl[field.key],
          textDirection: TextDirection.rtl,
          decoration: decoration,
          validator: validator,
        );
    }
  }

  // ── الحقول الأساسية ───────────────────────────────────────────────────────
  Widget _buildBaseFields() {
    final cs = Theme.of(context).colorScheme;

    InputDecoration decor(String label, IconData icon) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(),
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
          filled: true,
          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        );

    return Column(
      children: [
        // الاسم
        TextFormField(
          controller: _nameCtrl,
          textDirection: TextDirection.rtl,
          decoration: decor('الاسم الكامل *', Icons.person_outline),
          validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال اسمك' : null,
        ),
        const SizedBox(height: 16),

        // البريد
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: decor('البريد الإلكتروني *', Icons.email_outlined),
          validator: (v) => !v!.contains('@') ? 'بريد إلكتروني غير صحيح' : null,
        ),
        const SizedBox(height: 16),

        // كلمة المرور
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscure1,
          textDirection: TextDirection.ltr,
          decoration: decor('كلمة المرور *', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscure1
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure1 = !_obscure1),
            ),
          ),
          validator: (v) =>
              v!.length < 8 ? 'كلمة المرور 8 أحرف على الأقل' : null,
        ),
        const SizedBox(height: 16),

        // تأكيد كلمة المرور
        TextFormField(
          controller: _confirmCtrl,
          obscureText: _obscure2,
          textDirection: TextDirection.ltr,
          decoration: decor('تأكيد كلمة المرور *', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscure2
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure2 = !_obscure2),
            ),
          ),
          validator: (v) =>
              v != _passwordCtrl.text ? 'كلمتا المرور غير متطابقتين' : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(_registerFieldsProvider(_role));

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── اختيار نوع الحساب ──────────────────────────────────────
                _buildRoleSelector(),
                const SizedBox(height: 24),

                // ── الحقول الأساسية ────────────────────────────────────────
                _buildBaseFields(),
                const SizedBox(height: 24),

                // ── الحقول المخصصة (ديناميكية) ────────────────────────────
                fieldsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (fields) {
                    if (fields.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'بيانات إضافية',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ...fields.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildCustomField(f),
                            )),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 8),

                // ── زر الإرسال ────────────────────────────────────────────
                fieldsAsync.maybeWhen(
                  data: (fields) => FilledButton(
                    onPressed: _isLoading ? null : () => _submit(fields),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('إنشاء الحساب',
                            style: TextStyle(fontSize: 16)),
                  ),
                  orElse: () => FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('إنشاء الحساب',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _roleTab('طالب', 'student', Icons.school_outlined),
          _roleTab('معلم', 'instructor', Icons.cast_for_education_outlined),
        ],
      ),
    );
  }

  Widget _roleTab(String label, String value, IconData icon) {
    final cs       = Theme.of(context).colorScheme;
    final selected = _role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_role != value) {
            setState(() {
              _role = value;
              _selectValues.clear();
              for (final c in _customCtrl.values) c.clear();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? cs.onPrimary : cs.onSurface),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: selected ? cs.onPrimary : cs.onSurface,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
