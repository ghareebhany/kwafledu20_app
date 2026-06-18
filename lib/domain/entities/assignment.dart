import 'package:equatable/equatable.dart';

/// مرفق واحد ضمن تسليم الواجب.
class AssignmentAttachment extends Equatable {
  final String name;
  final String url;

  const AssignmentAttachment({required this.name, required this.url});

  @override
  List<Object?> get props => [name, url];
}

/// حالة تسليم المستخدم لواجب.
class AssignmentSubmission extends Equatable {
  final bool submitted;
  final int submissionId;
  final String answer;
  final List<AssignmentAttachment> attachments;
  final String submittedDate;
  final bool isEvaluated;
  final double? mark;
  final String instructorNote;

  const AssignmentSubmission({
    this.submitted = false,
    this.submissionId = 0,
    this.answer = '',
    this.attachments = const [],
    this.submittedDate = '',
    this.isEvaluated = false,
    this.mark,
    this.instructorNote = '',
  });

  @override
  List<Object?> get props =>
      [submitted, submissionId, answer, attachments, isEvaluated, mark];
}

/// واجب (Assignment) داخل كورس.
class Assignment extends Equatable {
  final int id;
  final String title;
  final int topicId;
  final int courseId;
  final int totalMark;
  final int passMark;
  final int filesLimit;
  final int sizeLimitMb;

  /// متوفّر في القائمة فقط
  final bool isSubmitted;
  final bool isEvaluated;
  final double? mark;

  /// متوفّر في التفاصيل فقط
  final String content;
  final AssignmentSubmission? submission;

  const Assignment({
    required this.id,
    required this.title,
    this.topicId = 0,
    this.courseId = 0,
    this.totalMark = 0,
    this.passMark = 0,
    this.filesLimit = 1,
    this.sizeLimitMb = 2,
    this.isSubmitted = false,
    this.isEvaluated = false,
    this.mark,
    this.content = '',
    this.submission,
  });

  @override
  List<Object?> get props =>
      [id, title, isSubmitted, isEvaluated, mark, submission];
}
