# Instant Data Collection - Quick Reference Guide

## 🎯 What is it?
A flexible system for teachers to create custom forms and collect responses from students via shareable links or QR codes.

---

## 📋 Key Features at a Glance

| Feature | Description |
|---------|-------------|
| **Custom Fields** | 9 field types: text, number, email, phone, dropdown, radio, checkbox, yes/no, file upload |
| **Sharing** | Generate link + QR code instantly |
| **Privacy** | Optional anonymous responses |
| **Real-time** | Live submission updates with timestamps |
| **Flexibility** | Allow multiple submissions per student |
| **Control** | Toggle session active/closed anytime |

---

## 🗂️ File Structure

```
lib/
└── screens/
    └── instant_data_collection/
        ├── create_instant_data_collection_screen.dart    # Teacher: Create
        ├── share_instant_data_collection_screen.dart     # Teacher: Share & View
        └── student_instant_data_collection_screen.dart   # Student: Submit
```

---

## 🔗 Routes

| Route | Purpose | User |
|-------|---------|------|
| `/instant-data/:sessionId` | Open form to submit | Student |
| `/instant-data-collection/share` | View submissions + share | Teacher |

---

## 💾 Firebase Collections

### `instant_data_collection/{sessionId}`
Main session document with configuration

### `instant_data_collection/{sessionId}/submissions/{submissionId}`
Student responses stored here

---

## 🎨 UI Components

### Teacher Screens:

#### Create Screen
- Title & Description inputs
- Settings toggles (name collection, multiple submissions)
- Custom field builder with dialog
- Field preview cards with delete

#### Share Screen
- Status banner (Active/Closed)
- Link display with copy button
- QR code modal
- Share button
- Live submission list (expandable cards)

### Student Screen:
- Loading state
- Session closed state
- Session not found state
- Name input (conditional)
- Dynamic custom fields
- Submit button
- Success screen with optional "Submit Again"

---

## 🔧 Custom Field Types

| Type | Input | Keyboard | Options |
|------|-------|----------|---------|
| `text` | Text field | Text | - |
| `number` | Text field | Numeric | - |
| `email` | Text field | Email | - |
| `phone` | Text field | Phone | - |
| `dropdown` | Dropdown | - | ✅ Required |
| `radio` | Radio buttons | - | ✅ Required |
| `checkbox` | Checkboxes | - | ✅ Required |
| `yesno` | Toggle switch | - | - |
| `file` | File picker | - | - |

---

## 🚀 Quick Implementation

### 1. Add to Navigation
```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateInstantDataCollectionScreen(),
      ),
    );
  },
  child: Text('Instant Data Collection'),
)
```

### 2. Create Session
```dart
// Teacher fills form, clicks "Create Session"
// Automatically navigates to share screen
```

### 3. Share Link
```dart
// Teacher copies link or shows QR code
// Example: https://attendo.app/instant-data/abc123
```

### 4. Student Opens Link
```dart
// Link opens StudentInstantDataCollectionScreen
// Dynamic form renders based on customFields
```

### 5. Submit Response
```dart
// Student fills form, clicks "Submit Response"
// Data saved to Firestore submissions subcollection
```

### 6. Teacher Views Submissions
```dart
// Real-time updates via StreamBuilder
// Expandable cards show all field responses
```

---

## 🔑 Key Code Snippets

### Create Custom Field
```dart
_customFields.add({
  'name': 'Student ID',
  'type': 'number',
  'required': true,
});
```

### Render Custom Field Widget
```dart
CustomFieldWidget(
  fieldConfig: customField,
  onValueChanged: (fieldName, value) {
    _fieldValues[fieldName] = value;
  },
)
```

### Generate Device Fingerprint
```dart
final deviceInfo = DeviceInfoPlugin();
if (kIsWeb) {
  final webInfo = await deviceInfo.webBrowserInfo;
  fingerprint = '${webInfo.browserName}_${webInfo.platform}';
} else if (Platform.isAndroid) {
  fingerprint = (await deviceInfo.androidInfo).id;
}
```

### Real-time Submissions Stream
```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('instant_data_collection')
    .doc(sessionId)
    .collection('submissions')
    .orderBy('submittedAt', descending: true)
    .snapshots(),
  builder: (context, snapshot) {
    // Build submission cards
  },
)
```

---

## 🎯 Use Cases

- **Quick Surveys** - Collect feedback after lectures
- **Workshop Registration** - Gather participant details on-the-fly
- **Exit Tickets** - End-of-class check-ins
- **Event Check-In** - Lightweight alternative to full event attendance
- **Anonymous Feedback** - Collect honest opinions without names
- **Data Collection** - Any structured information gathering

---

## ⚙️ Configuration Options

### Session Settings:
```dart
{
  'collectName': true,              // Show name field?
  'allowMultipleSubmissions': false, // Can students submit multiple times?
  'status': 'active',               // 'active' or 'closed'
}
```

### Field Settings:
```dart
{
  'name': 'Field Label',
  'type': 'dropdown',
  'required': true,
  'options': ['Option 1', 'Option 2'],
}
```

---

## 🔒 Privacy Features

- **Anonymous Mode**: Disable name collection
- **Device Tracking**: Fingerprint stored (not shown to students)
- **Session Control**: Close session to stop submissions
- **Validation**: Required fields prevent incomplete data

---

## 📊 Data Access

### Teacher View:
- Total submission count (live badge)
- Expandable submission cards
- All field responses visible
- Student names or "Anonymous"
- Relative timestamps ("5m ago")

### Export Options (Future):
- CSV download
- Excel export
- PDF reports
- Analytics dashboard

---

## 🎨 Design Tokens

### Colors:
- Primary: `ThemeHelper.getPrimaryColor(context)`
- Success: `ThemeHelper.getSuccessColor(context)`
- Card: `ThemeHelper.getCardColor(context)`
- Border: `ThemeHelper.getBorderColor(context)`

### Typography:
- All text uses `GoogleFonts.poppins()`
- Code blocks use `GoogleFonts.robotoMono()`

### Spacing:
- Card padding: `16px`
- Section spacing: `24px`
- Button padding: `12px vertical, 16px horizontal`

---

## 🐛 Common Issues & Solutions

### Issue: "Session Not Found"
**Solution:** Check sessionId is correct and session document exists in Firestore

### Issue: Fields not rendering
**Solution:** Ensure `customFields` array is properly structured with `name`, `type`, `required`

### Issue: Dropdown/radio shows empty
**Solution:** Verify `options` array is populated for choice-based fields

### Issue: Device fingerprint errors
**Solution:** Add proper platform checks (`kIsWeb`, `Platform.isAndroid`, etc.)

### Issue: Submissions not appearing
**Solution:** Check Firestore rules allow read/write to `instant_data_collection` collection

---

## ✅ Testing Checklist

- [ ] Create session with all 9 field types
- [ ] Share link via copy and native share
- [ ] Show QR code modal
- [ ] Open link on student device
- [ ] Submit response with all fields filled
- [ ] Verify real-time update in teacher view
- [ ] Test required field validation
- [ ] Test session close/reopen
- [ ] Test anonymous mode (collectName: false)
- [ ] Test multiple submissions (allowMultipleSubmissions: true)
- [ ] Test device fingerprint generation
- [ ] Test form reset after submission

---

## 📖 Related Documentation

- Full implementation: `INSTANT_DATA_COLLECTION_SUMMARY.md`
- Custom field widgets: `/lib/widgets/custom_field_widgets.dart`
- Theme helpers: `/lib/utils/theme_helper.dart`
- Firebase setup: Project Firebase Console

---

## 🎉 Quick Start Command

```bash
# Navigate to Instant Data Collection in app
# Or directly:
Navigator.pushNamed(context, '/instant-data-collection/create');
```

---

**Last Updated:** [Current Date]  
**Version:** 1.0.0  
**Status:** ✅ Production Ready
