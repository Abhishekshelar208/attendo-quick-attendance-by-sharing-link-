# 🎯 Live Quiz Feature - Implementation Guide

## ✅ **COMPLETED COMPONENTS** (Teacher Side - 50%)

### 1. ✅ **quiz_models.dart** - Data Models
- `QuizQuestion` - Question with options and correct answer
- `CustomField` - Dynamic student fields
- `QuizParticipant` - Student participation data
- `QuizSession` - Complete quiz session model

### 2. ✅ **CreateQuizScreen.dart** - Step 1: Basic Info
**Features:**
- Quiz name, description
- Year, Branch, Division selection
- Date & Time pickers
- Dynamic custom fields (Name, Student ID, etc.)
- Quiz type selection (MCQ enabled, others "Soon")
- Two creation methods: Manual & AI

### 3. ✅ **QuizQuestionsScreen.dart** - Manual Question Builder
**Features:**
- Add/Remove questions dynamically
- 2-6 options per question
- Mark correct answer with radio buttons
- Real-time question counter
- Validation before quiz generation
- Save to Firebase & navigate to ShareQuizScreen

### 4. ✅ **AIQuizGeneratorScreen.dart** - AI-Powered Quiz Generation
**Features:**
- Subject/Domain input
- Topic description
- Number of questions (1-20)
- Difficulty level (Easy/Medium/Hard)
- **Gemini API integration**
- Edit/Delete generated questions
- Regenerate option
- Save to Firebase with `generation_method: 'ai'`

**⚠️ IMPORTANT:** Add your Gemini API Key in `AIQuizGeneratorScreen.dart` line 36:
```dart
static const String GEMINI_API_KEY = 'YOUR_API_KEY_HERE';
```
Get it from: https://makersuite.google.com/app/apikey

---

## 🚧 **REMAINING COMPONENTS TO BUILD**

### **TEACHER SIDE** (50% remaining)

#### 5. ⏳ **ShareQuizScreen.dart** - Share & Monitor
**Required Features:**
- Display QR Code
- Shareable link (https://your-app.web.app/#/quiz/{quizId})
- Copy link button
- Share via WhatsApp/Email buttons
- Quiz details card
- "View Live Results" button → TeacherQuizDashboard
- "End Quiz" button

**Implementation:**
```dart
// Similar to ShareAttendanceScreen.dart and ShareEventScreen.dart
// Use qr_flutter package (already in pubspec.yaml)
// Use share_plus package (already in pubspec.yaml)
```

#### 6. ⏳ **TeacherQuizDashboard.dart** - Live Monitoring
**Required Features:**
- Real-time participant count
- List of participants who joined
- Live progress tracking
- "End Quiz" button (updates status to 'ended')
- Navigate to QuizReportScreen

**Firebase Listeners:**
```dart
_dbRef.child('quiz_sessions/$quizId/participants').onValue.listen((event) {
  // Update participant list in real-time
});
```

#### 7. ⏳ **QuizReportScreen.dart** - Final Report
**Required Features:**
- Quiz details header
- All participants with scores (sorted high → low)
- Top 3 winners highlighted 🏆🥈🥉
- Export to PDF (use `pdf` package)
- Export to Excel (use `archive` package)
- Share report functionality

---

### **STUDENT SIDE** (100% remaining)

#### 8. ⏳ **StudentQuizEntryScreen.dart** - Join Quiz
**Required Features:**
- Fetch quiz details from Firebase using quizId
- Display quiz name, description
- Dynamic form based on custom fields
- Validate all required fields
- Save participant data to Firebase
- Navigate to StudentQuizScreen

**Deep Link Handling in main.dart:**
```dart
// Add quiz route handler in onGenerateRoute:
if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'quiz') {
  String quizId = uri.pathSegments[1];
  return MaterialPageRoute(
    builder: (context) => StudentQuizEntryScreen(quizId: quizId),
  );
}
```

#### 9. ⏳ **StudentQuizScreen.dart** - Take Quiz
**Required Features:**
- Display current question number (e.g., "Question 2/10")
- Show question text
- Radio buttons for options
- "Next Question" button
- "Previous Question" button (optional)
- Auto-save answers to Firebase
- Listen for quiz end status (teacher ends quiz)
- Auto-redirect to QuizResultsScreen when complete or ended

**State Management:**
```dart
int currentQuestionIndex = 0;
List<int> selectedAnswers = List.filled(totalQuestions, -1);

void _saveAnswer(int answerIndex) {
  selectedAnswers[currentQuestionIndex] = answerIndex;
  // Save to Firebase in real-time
}
```

#### 10. ⏳ **QuizResultsScreen.dart** - Leaderboard
**Required Features:**
- Fetch all participants from Firebase
- Calculate scores (compare answers with correct answers)
- Sort by score (high → low)
- Assign ranks
- Highlight current student
- Show top 3 with winner badges
- Real-time updates if more students complete

**Scoring Logic:**
```dart
int calculateScore(List<int> studentAnswers, List<QuizQuestion> questions) {
  int score = 0;
  for (int i = 0; i < questions.length; i++) {
    if (studentAnswers[i] == questions[i].correctAnswerIndex) {
      score++;
    }
  }
  return score;
}
```

---

## 🔧 **FIREBASE REALTIME DATABASE STRUCTURE**

```javascript
quiz_sessions/
  └─ {quizId}/
     ├─ quiz_name: "Math Quiz"
     ├─ description: "Chapter 5"
     ├─ year: "3rd Year"
     ├─ branch: "CO"
     ├─ division: "A"
     ├─ date: "15 Jan 2025"
     ├─ time: "10:00 AM"
     ├─ quiz_type: "MCQ"
     ├─ status: "active" | "ended"
     ├─ created_at: "ISO timestamp"
     ├─ creator_uid: "xxx"
     ├─ creator_name: "Teacher Name"
     ├─ creator_email: "teacher@example.com"
     ├─ generation_method: "manual" | "ai"
     ├─ custom_fields: [
     │   {name: "Name", required: true},
     │   {name: "Student ID", required: true}
     │ ]
     ├─ questions: [
     │   {
     │     question: "What is 2+2?",
     │     options: ["2", "3", "4", "5"],
     │     correct_answer: 2
     │   }
     │ ]
     └─ participants: {
         {participantId}: {
           participant_id: "xxx",
           custom_field_values: {
             "Name": "John Doe",
             "Student ID": "12345"
           },
           answers: [2, 0, 1, 3, 2],  // Selected answer indices
           score: 4,
           completed_at: "timestamp",
           rank: 3
         }
       }
```

---

## 🔗 **DEEP LINK URL FORMAT**

### Web:
```
https://attendo-312ea.web.app/#/quiz/{quizId}
```

### Mobile:
```
yourapp://quiz/{quizId}
```

---

## 📱 **INTEGRATION WITH EXISTING SCREENS**

### 1. Update `home_tab.dart`:
```dart
// Change line 274:
'available': true,  // Change from false to true

// Add navigation (around line 372):
if (label.contains('Quiz')) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CreateQuizScreen(),
    ),
  );
}
```

### 2. Update `history_tab.dart`:
Add quiz sessions to history:
```dart
// Fetch quiz sessions similar to attendance/events
final quizSnapshot = await _dbRef.child('quiz_sessions').get();
// Filter by creator_uid and status == 'ended'
// Add to history items with type: 'quiz'
```

### 3. Update `main.dart`:
Add quiz route in `onGenerateRoute`:
```dart
if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'quiz') {
  String quizId = uri.pathSegments[1];
  return MaterialPageRoute(
    builder: (context) => StudentQuizEntryScreen(quizId: quizId),
  );
}
```

---

## 🎨 **UI/UX GUIDELINES**

### Colors:
- **Quiz Primary:** Purple (`0xff8b5cf6`)
- **AI Features:** Deep Purple gradient
- **Correct Answer:** Green
- **Selected Option:** Blue
- **Winner Badges:** Gold 🏆, Silver 🥈, Bronze 🥉

### Icons:
- Quiz: `Icons.quiz_rounded`
- AI: `Icons.auto_awesome_rounded`
- Manual: `Icons.edit_rounded`
- Questions: `Icons.help_outline_rounded`
- Correct: `Icons.check_circle_rounded`
- Leaderboard: `Icons.leaderboard_rounded`

---

## 🚀 **NEXT STEPS TO COMPLETE FEATURE**

1. **Create ShareQuizScreen.dart** (Copy ShareAttendanceScreen, modify for quiz)
2. **Create StudentQuizEntryScreen.dart**
3. **Create StudentQuizScreen.dart** (Most complex - question navigation)
4. **Create QuizResultsScreen.dart** (Leaderboard with scoring)
5. **Create TeacherQuizDashboard.dart**
6. **Create QuizReportScreen.dart** (PDF/Excel export)
7. **Update main.dart** with quiz route
8. **Update home_tab.dart** to enable quiz feature
9. **Update history_tab.dart** to show quiz history
10. **Add Gemini API key** in AIQuizGeneratorScreen.dart
11. **Test complete flow**

---

## 📝 **TESTING CHECKLIST**

### Teacher Flow:
- [ ] Create quiz manually
- [ ] Create quiz with AI
- [ ] Edit AI-generated questions
- [ ] Generate quiz successfully
- [ ] View QR code and link
- [ ] Share quiz via link
- [ ] Monitor live participants
- [ ] End quiz
- [ ] View report
- [ ] Export to PDF/Excel

### Student Flow:
- [ ] Open quiz link
- [ ] Fill entry form
- [ ] Take quiz (answer all questions)
- [ ] Navigate between questions
- [ ] Auto-redirect when quiz ends
- [ ] View results/leaderboard
- [ ] See own rank and score

### Integration:
- [ ] Quiz appears in history after ending
- [ ] Home screen quiz feature enabled
- [ ] Deep links work on web
- [ ] Real-time sync works
- [ ] Multiple students can take quiz simultaneously

---

## 🔒 **SECURITY CONSIDERATIONS**

1. **Validate quiz access** - Check if quiz exists and is active
2. **Prevent duplicate entries** - Check if student already participated
3. **Rate limiting** - Prevent spam quiz creation
4. **Secure API keys** - Use environment variables for Gemini API
5. **Data validation** - Sanitize all user inputs

---

## 💡 **FUTURE ENHANCEMENTS**

- Timer per question
- Randomize question order
- Randomize option order
- Image-based questions
- Multiple correct answers
- Fill-in-the-blank questions
- Essay questions with manual grading
- Quiz templates library
- Recurring quizzes
- Quiz analytics dashboard

---

**Total Progress: 33% Complete (5/15 screens built)**

Good luck completing the remaining screens! 🚀
