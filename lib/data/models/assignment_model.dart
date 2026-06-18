import '../../domain/entities/assignment.dart';

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? 0;
}

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

class AssignmentAttachmentModel extends AssignmentAttachment {
  const AssignmentAttachmentModel({required super.name, required super.url});

  factory AssignmentAttachmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentAttachmentModel(
      name: (json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
    );
  }
}

class AssignmentSubmissionModel extends AssignmentSubmission {
  const AssignmentSubmissionModel({
    super.submitted,
    super.submissionId,
    super.answer,
    super.attachments,
    super.submittedDate,
    super.isEvaluated,
    super.mark,
    super.instructorNote,
  });

  factory AssignmentSubmissionModel.fromJson(Map<String, dynamic> json) {
    final rawAtt = json['attachments'];
    final atts = rawAtt is List
        ? rawAtt
            .map((e) =>
                AssignmentAttachmentModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : const <AssignmentAttachment>[];
    return AssignmentSubmissionModel(
      submitted: json['submitted'] == true,
      submissionId: _toInt(json['submission_id']),
      answer: (json['answer'] ?? '').toString(),
      attachments: atts,
      submittedDate: (json['submitted_date'] ?? '').toString(),
      isEvaluated: json['is_evaluated'] == true,
      mark: _toDoubleOrNull(json['mark']),
      instructorNote: (json['instructor_note'] ?? '').toString(),
    );
  }
}

class AssignmentModel extends Assignment {
  const AssignmentModel({
    required super.id,
    required super.title,
    super.topicId,
    super.courseId,
    super.totalMark,
    super.passMark,
    super.filesLimit,
    super.sizeLimitMb,
    super.isSubmitted,
    super.isEvaluated,
    super.mark,
    super.content,
    super.submission,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    final rawSub = json['submission'];
    return AssignmentModel(
      id: _toInt(json['id']),
      title: (json['title'] ?? '').toString(),
      topicId: _toInt(json['topic_id']),
      courseId: _toInt(json['course_id']),
      totalMark: _toInt(json['total_mark']),
      passMark: _toInt(json['pass_mark']),
      filesLimit: json['files_limit'] == null ? 1 : _toInt(json['files_limit']),
      sizeLimitMb:
          json['size_limit_mb'] == null ? 2 : _toInt(json['size_limit_mb']),
      isSubmitted: json['is_submitted'] == true,
      isEvaluated: json['is_evaluated'] == true,
      mark: _toDoubleOrNull(json['mark']),
      content: (json['content'] ?? '').toString(),
      submission: rawSub is Map<String, dynamic>
          ? AssignmentSubmissionModel.fromJson(rawSub)
          : null,
    );
  }
}
