# 🎯 LIVE QUIZ - QUICK START GUIDE

## ⚡ **IMMEDIATE TESTING**

### **Run the App**
```bash
cd /Users/abhishekshelar/StudioProjects/attendo
flutter run
```

---

## 📱 **TEACHER WORKFLOW**

### **1. Create Quiz**
```
Home Screen → Live Quiz Card → Create Quiz
```

**Fill Details:**
- Quiz Name
- Description
- Class Info (Year, Branch, Division)
- Date & Time
- Custom fields for students

**Choose Method:**
- **Manual:** Add questions one by one
- **AI:** Generate with Gemini (need API key)

### **2. Share Quiz**
```
After Creation → Share Screen
```
- Copy link
- Show QR code
- Share via WhatsApp/Email
- Click **"View Live Dashboard"**

### **3. Monitor Live**
```
Dashboard Screen (Real-time)
```
- See participants join
- Track progress
- View completion status
- End quiz when done

### **4. View Reports**
```
Dashboard → Report Icon (top-right)
```
- Full statistics
- Complete leaderboard
- Export to CSV
- Share report

### **5. Access History**
```
History Tab → Filter: Quizzes
```
- View all past quizzes
- Tap to open report
- See participant data

### **6. Check Analytics**
```
Analytics Tab → Quiz Analytics Section
```
- Total quizzes
- Average scores
- Participant trends

---

## 👨‍🎓 **STUDENT WORKFLOW**

### **1. Join Quiz**
- Open quiz link OR
- Scan QR code
→ Goes to Entry Screen

### **2. Fill Details**
- Enter Name
- Enter Student ID
- Fill custom fields
- Click "Join Quiz"

### **3. Take Quiz**
- Answer questions
- Click "Next"
- Review if needed
- Click "Submit Quiz"

### **4. View Results**
- See your score
- View your rank
- Check leaderboard
- See top 3 winners

---

## 🎨 **SCREEN NAVIGATION MAP**

```
HOME
  ↓
CREATE QUIZ
  ↓
QUIZ QUESTIONS / AI GENERATOR
  ↓
SHARE QUIZ ──────→ TEACHER DASHBOARD ──→ QUIZ REPORT
                         ↓
                    (Monitor Live)
                         ↓
                   (End Quiz Button)


STUDENT LINK
  ↓
ENTRY SCREEN
  ↓
QUIZ SCREEN
  ↓
RESULTS SCREEN (Leaderboard)


HISTORY TAB → Filter: Quizzes → Click Quiz → QUIZ REPORT

ANALYTICS TAB → Scroll to Quiz Analytics
```

---

## 🔧 **CONFIGURATION**

### **Gemini API Key (for AI)**
**File:** `lib/pages/AIQuizGeneratorScreen.dart`  
**Line:** 36

```dart
static const String GEMINI_API_KEY = 'YOUR_KEY_HERE';
```

Get key from: https://makersuite.google.com/app/apikey

### **Quiz URL (for sharing)**
**File:** `lib/pages/ShareQuizScreen.dart`  
**Line:** 38

```dart
quizUrl = 'https://YOUR-DOMAIN.web.app/#/quiz/${widget.quizId}';
```

---

## 📊 **KEY FEATURES**

### **Teacher**
✅ Create quizzes (Manual/AI)  
✅ Live monitoring dashboard  
✅ Detailed reports  
✅ CSV export  
✅ History tracking  
✅ Analytics  

### **Student**
✅ Easy quiz entry  
✅ Question navigation  
✅ Real-time submission  
✅ Instant results  
✅ Leaderboard  

### **Admin**
✅ Real-time sync  
✅ Progress tracking  
✅ End quiz control  
✅ Data export  
✅ Historical records  

---

## 🎯 **FILE LOCATIONS**

### **Main Screens**
```
lib/pages/
├── CreateQuizScreen.dart          # Quiz creation
├── QuizQuestionsScreen.dart       # Manual questions
├── AIQuizGeneratorScreen.dart     # AI generation
├── ShareQuizScreen.dart           # Share & Dashboard link
├── TeacherQuizDashboard.dart      # Live monitoring ✨ NEW
├── QuizReportScreen.dart          # Reports & Export ✨ NEW
├── StudentQuizEntryScreen.dart    # Student join
├── StudentQuizScreen.dart         # Take quiz
└── QuizResultsScreen.dart         # Leaderboard
```

### **Enhanced Screens**
```
lib/pages/
├── history_tab.dart               # Quiz history ✨ UPDATED
└── analytics_tab.dart             # Quiz analytics ✨ UPDATED
```

---

## 🚀 **TESTING CHECKLIST**

- [ ] Run `flutter pub get`
- [ ] Run `flutter run`
- [ ] Create a test quiz
- [ ] Monitor on dashboard
- [ ] Have a friend join (or use another device)
- [ ] See real-time updates
- [ ] Complete quiz as student
- [ ] Check results/leaderboard
- [ ] View report
- [ ] Export to CSV
- [ ] Check history tab
- [ ] Check analytics tab

---

## 💡 **QUICK TIPS**

1. **For AI Questions:** Add Gemini API key first
2. **For Testing:** Use multiple devices/browsers
3. **For Real Use:** Update the quiz URL domain
4. **For Records:** Export CSV after each quiz
5. **For Analytics:** Check Analytics tab regularly

---

## 🐛 **TROUBLESHOOTING**

### **Quiz Link Not Working**
- Check Firebase Hosting is deployed
- Verify URL in ShareQuizScreen
- Test deep linking configuration

### **AI Not Generating**
- Add Gemini API key
- Check internet connection
- Verify API key is valid

### **Dashboard Not Updating**
- Check Firebase Realtime Database rules
- Verify internet connection
- Pull to refresh

### **Export Not Working**
- Check file permissions
- Verify csv package is installed
- Run `flutter pub get`

---

## 📞 **SUPPORT**

If you encounter issues:
1. Check `QUIZ_FEATURE_FINAL_SUMMARY.md` for details
2. Review `LIVE_QUIZ_COMPLETE.md` for architecture
3. Run `flutter analyze` to check for errors
4. Check Firebase Console for data

---

## 🎊 **YOU'RE ALL SET!**

The Live Quiz feature is **100% complete** and ready to use!

**Happy Quizzing! 🎯**

---

*Last Updated: January 2025*
