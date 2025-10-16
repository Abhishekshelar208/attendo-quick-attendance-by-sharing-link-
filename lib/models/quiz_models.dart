class QuizQuestion {
  String question;
  List<String> options;
  int correctAnswerIndex;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correct_answer': correctAnswerIndex,
    };
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswerIndex: json['correct_answer'] ?? 0,
    );
  }
}

class CustomField {
  String name;
  bool required;

  CustomField({
    required this.name,
    this.required = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'required': required,
    };
  }

  factory CustomField.fromJson(Map<String, dynamic> json) {
    return CustomField(
      name: json['name'] ?? '',
      required: json['required'] ?? true,
    );
  }
}

class QuizParticipant {
  String participantId;
  Map<String, dynamic> customFieldValues; // {fieldName: value}
  List<int> answers; // Array of selected answer indices
  int score;
  String? completedAt;
  int rank;

  QuizParticipant({
    required this.participantId,
    required this.customFieldValues,
    this.answers = const [],
    this.score = 0,
    this.completedAt,
    this.rank = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'participant_id': participantId,
      'custom_field_values': customFieldValues,
      'answers': answers,
      'score': score,
      'completed_at': completedAt,
      'rank': rank,
    };
  }

  factory QuizParticipant.fromJson(String id, Map<String, dynamic> json) {
    return QuizParticipant(
      participantId: id,
      customFieldValues: Map<String, dynamic>.from(json['custom_field_values'] ?? {}),
      answers: List<int>.from(json['answers'] ?? []),
      score: json['score'] ?? 0,
      completedAt: json['completed_at'],
      rank: json['rank'] ?? 0,
    );
  }
}

class QuizSession {
  String quizId;
  String quizName;
  String description;
  String year;
  String branch;
  String division;
  String date;
  String time;
  String quizType; // 'MCQ', 'True/False', etc.
  String status; // 'active', 'ended'
  String createdAt;
  String creatorUid;
  String creatorName;
  String creatorEmail;
  String generationMethod; // 'manual' or 'ai'
  bool showLeaderboard; // Whether students can see full leaderboard
  List<CustomField> customFields;
  List<QuizQuestion> questions;
  Map<String, QuizParticipant> participants;

  QuizSession({
    required this.quizId,
    required this.quizName,
    required this.description,
    required this.year,
    required this.branch,
    required this.division,
    required this.date,
    required this.time,
    required this.quizType,
    this.status = 'active',
    required this.createdAt,
    required this.creatorUid,
    required this.creatorName,
    required this.creatorEmail,
    this.generationMethod = 'manual',
    this.showLeaderboard = true,
    this.customFields = const [],
    this.questions = const [],
    this.participants = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'quiz_name': quizName,
      'description': description,
      'year': year,
      'branch': branch,
      'division': division,
      'date': date,
      'time': time,
      'quiz_type': quizType,
      'status': status,
      'created_at': createdAt,
      'creator_uid': creatorUid,
      'creator_name': creatorName,
      'creator_email': creatorEmail,
      'generation_method': generationMethod,
      'show_leaderboard': showLeaderboard,
      'custom_fields': customFields.map((f) => f.toJson()).toList(),
      'questions': questions.map((q) => q.toJson()).toList(),
      'participants': participants.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  factory QuizSession.fromJson(String id, Map<String, dynamic> json) {
    Map<String, QuizParticipant> participants = {};
    if (json['participants'] != null) {
      (json['participants'] as Map<dynamic, dynamic>).forEach((key, value) {
        participants[key.toString()] = QuizParticipant.fromJson(
          key.toString(),
          Map<String, dynamic>.from(value),
        );
      });
    }

    return QuizSession(
      quizId: id,
      quizName: json['quiz_name'] ?? '',
      description: json['description'] ?? '',
      year: json['year'] ?? '',
      branch: json['branch'] ?? '',
      division: json['division'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      quizType: json['quiz_type'] ?? 'MCQ',
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] ?? '',
      creatorUid: json['creator_uid'] ?? '',
      creatorName: json['creator_name'] ?? '',
      creatorEmail: json['creator_email'] ?? '',
      generationMethod: json['generation_method'] ?? 'manual',
      showLeaderboard: json['show_leaderboard'] ?? true,
      customFields: (json['custom_fields'] as List<dynamic>?)
              ?.map((f) => CustomField.fromJson(Map<String, dynamic>.from(f)))
              .toList() ??
          [],
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => QuizQuestion.fromJson(Map<String, dynamic>.from(q)))
              .toList() ??
          [],
      participants: participants,
    );
  }
}
