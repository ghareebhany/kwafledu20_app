import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/qna.dart';
import '../../data/datasources/qna_remote_ds.dart';

// ── Q&A list (Tutor-native via app/v1/qna) ─────────────────────────────────

final qnaProvider = FutureProvider.autoDispose.family<List<QnaItem>, int>(
  (ref, courseId) async {
    return QnaRemoteDataSource.instance.getQna(courseId);
  },
);

// ── Post question / answer ────────────────────────────────────────────────

class PostQnaState {
  final bool isLoading;
  final bool success;
  final String? error;
  const PostQnaState({this.isLoading = false, this.success = false, this.error});
}

class PostQnaNotifier extends StateNotifier<PostQnaState> {
  final Ref _ref;
  PostQnaNotifier(this._ref) : super(const PostQnaState());

  Future<bool> post({
    required int courseId,
    required String content,
    int parentId = 0,
  }) async {
    state = const PostQnaState(isLoading: true);
    try {
      final ok = await QnaRemoteDataSource.instance.postQna(
        courseId: courseId,
        content: content,
        parentId: parentId,
      );
      if (ok) {
        state = const PostQnaState(success: true);
        _ref.invalidate(qnaProvider(courseId));
        return true;
      }
      state = const PostQnaState(error: 'تعذر الإرسال');
      return false;
    } catch (e) {
      state = PostQnaState(error: e.toString());
      return false;
    }
  }

  void reset() => state = const PostQnaState();
}

final postQnaProvider = StateNotifierProvider<PostQnaNotifier, PostQnaState>(
  (ref) => PostQnaNotifier(ref),
);

