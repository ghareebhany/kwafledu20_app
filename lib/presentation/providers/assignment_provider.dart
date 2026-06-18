import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/assignment_remote_ds.dart';
import '../../domain/entities/assignment.dart';

/// قائمة واجبات الكورس.
final assignmentsProvider =
    FutureProvider.family<List<Assignment>, int>((ref, courseId) async {
  return AssignmentRemoteDataSource.instance.getAssignments(courseId);
});

/// تفاصيل واجب واحد (مع تسليم المستخدم).
final assignmentDetailProvider =
    FutureProvider.family<Assignment, int>((ref, assignmentId) async {
  return AssignmentRemoteDataSource.instance.getAssignment(assignmentId);
});

/// حالة إرسال التسليم.
class SubmitAssignmentState {
  final bool loading;
  final String? error;
  const SubmitAssignmentState({this.loading = false, this.error});
}

class SubmitAssignmentNotifier extends StateNotifier<SubmitAssignmentState> {
  final Ref _ref;
  SubmitAssignmentNotifier(this._ref) : super(const SubmitAssignmentState());

  Future<bool> submit({
    required int assignmentId,
    required int courseId,
    String answer = '',
    List<File> files = const [],
  }) async {
    state = const SubmitAssignmentState(loading: true);
    try {
      await AssignmentRemoteDataSource.instance.submitAssignment(
        assignmentId: assignmentId,
        courseId: courseId,
        answer: answer,
        files: files,
      );
      state = const SubmitAssignmentState();
      _ref.invalidate(assignmentDetailProvider(assignmentId));
      _ref.invalidate(assignmentsProvider(courseId));
      return true;
    } catch (e) {
      state = SubmitAssignmentState(error: e.toString());
      return false;
    }
  }
}

final submitAssignmentProvider =
    StateNotifierProvider<SubmitAssignmentNotifier, SubmitAssignmentState>(
  (ref) => SubmitAssignmentNotifier(ref),
);

