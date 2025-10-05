# Advanced Custom Fields Feature 🎯

## Overview
The advanced custom fields feature allows event organizers to collect complex information from participants beyond simple text inputs. This includes dropdowns, radio buttons, checkboxes, yes/no toggles, and file uploads.

## Supported Field Types

### 1. **Text Input** 📝
- Basic text entry
- Example: Comments, Additional Notes

### 2. **Number Input** 🔢
- Numeric values only
- Example: Age, Employee ID

### 3. **Email Input** 📧
- Email validation
- Example: Alternative Email, Office Email

### 4. **Phone Input** 📞
- Phone number format
- Example: Emergency Contact, WhatsApp Number

### 5. **Dropdown List** ⬇️
- Single selection from predefined options
- Example: T-Shirt Size (Small, Medium, Large, XL)
- **Configuration**: Requires comma-separated options

### 6. **Radio Buttons** 🔘
- Single selection from list (visually different from dropdown)
- Example: Meal Preference (Vegetarian, Non-Vegetarian, Vegan)
- **Configuration**: Requires comma-separated options

### 7. **Checkboxes** ☑️
- Multiple selections allowed
- Example: Interests (Sports, Music, Technology, Art)
- **Configuration**: Requires comma-separated options
- **Output**: Comma-separated selected values

### 8. **Yes/No Toggle** 🔀
- Simple boolean choice
- Example: "Need Accommodation?", "First Time Attendee?"
- **Output**: "Yes" or "No"

### 9. **File Upload** 📤
- Allows participants to upload files
- **Supported formats**: JPG, PNG, PDF, DOC, DOCX
- Example: Resume, ID Proof, Certificate
- **Note**: Currently stores filename; can be extended to upload to Firebase Storage

## Usage Guide

### For Event Organizers (Creating Events)

1. **Navigate to Create Event Screen**
2. **Fill Basic Event Details**
   - Event Name
   - Venue
   - Date & Time
   - Year, Branch, Division
   
3. **Add Custom Fields**
   - Click "Add Custom Field" button
   - Enter field name (e.g., "T-Shirt Size")
   - Select field type from dropdown
   - For dropdown/radio/checkbox: Enter comma-separated options
   - Check/uncheck "Required field"
   - Click "Add Field"

4. **Manage Custom Fields**
   - View all added fields in the list
   - Each field shows icon, name, and type
   - Can remove fields if needed

### For Participants (Checking In)

1. **Open Event Link**
2. **Enter Main Information** (Roll Number/Name/etc.)
3. **Fill Custom Fields**
   - Text/Number/Email/Phone: Type directly
   - Dropdown: Select from list
   - Radio: Choose one option
   - Checkbox: Select multiple options
   - Yes/No: Toggle switch
   - File Upload: Tap to choose file from device

4. **Submit Check-In**
   - All required fields must be filled
   - System validates before submission

### For Organizers (Viewing Responses)

#### Live View
- Participants list shows name/roll number
- Custom field values appear below each participant's name
- Example:
  ```
  John Doe (#101)
  T-Shirt Size: Large
  Meal Preference: Vegetarian
  Needs Accommodation: Yes
  ```

#### PDF Export
- When custom fields exist, PDF uses table format
- Columns: # | Main Field | Custom Field 1 | Custom Field 2 | ...
- Example:
  ```
  # | Roll No | T-Shirt | Meal     | Accommodation
  1 | 101     | Large   | Veg      | Yes
  2 | 102     | Medium  | Non-Veg  | No
  ```

## Data Structure

### Event Configuration
```json
{
  "event_name": "Tech Fest 2025",
  "custom_fields": [
    {
      "name": "T-Shirt Size",
      "type": "dropdown",
      "options": ["Small", "Medium", "Large", "XL"],
      "required": true
    },
    {
      "name": "Dietary Preference",
      "type": "radio",
      "options": ["Vegetarian", "Non-Vegetarian", "Vegan"],
      "required": true
    },
    {
      "name": "Interests",
      "type": "checkbox",
      "options": ["Sports", "Music", "Technology", "Art"],
      "required": false
    },
    {
      "name": "Need Accommodation",
      "type": "yesno",
      "required": true
    },
    {
      "name": "Resume",
      "type": "file",
      "required": false
    }
  ]
}
```

### Participant Response
```json
{
  "entry": "John Doe",
  "custom_fields": {
    "T-Shirt Size": "Large",
    "Dietary Preference": "Vegetarian",
    "Interests": "Sports, Technology",
    "Need Accommodation": "Yes",
    "Resume": "File: john_resume.pdf"
  }
}
```

## Implementation Details

### Files Modified/Created

1. **CreateEventScreen.dart**
   - Enhanced `_showAddCustomFieldDialog()` with all field types
   - Added field type icons and labels
   - Added validation for options in dropdown/radio/checkbox
   - Added required field checkbox

2. **custom_field_widgets.dart** (NEW)
   - `CustomFieldWidget` - Main stateful widget
   - Handles rendering for all field types
   - Manages state for each field type
   - Callbacks for value changes

3. **StudentEventCheckInScreen.dart** (To be updated)
   - Replace simple TextField loop with CustomFieldWidget
   - Handle validation for all field types
   - Store responses appropriately

4. **ShareEventScreen.dart** (Already updated)
   - Display custom fields in participants list
   - Export custom fields in PDF table format

5. **pubspec.yaml**
   - Added `file_picker: ^8.1.6` dependency

## Field Type Implementation

### Text-based Fields
```dart
TextField(
  controller: _textController,
  keyboardType: appropriate_type,
  onChanged: (value) => callback(fieldName, value),
)
```

### Dropdown
```dart
DropdownButton<String>(
  items: options.map(...).toList(),
  onChanged: (value) => callback(fieldName, value),
)
```

### Radio Buttons
```dart
Column(
  children: options.map((option) =>
    RadioListTile<String>(
      value: option,
      groupValue: selectedValue,
      onChanged: (value) => callback(fieldName, value),
    )
  ).toList(),
)
```

### Checkboxes
```dart
Column(
  children: options.map((option) =>
    CheckboxListTile(
      value: selectedValues.contains(option),
      onChanged: (checked) => callback(fieldName, joinedValues),
    )
  ).toList(),
)
```

### Yes/No Toggle
```dart
Switch(
  value: boolValue,
  onChanged: (value) => callback(fieldName, value ? 'Yes' : 'No'),
)
```

### File Upload
```dart
InkWell(
  onTap: () async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(...);
    callback(fieldName, 'File: ${result.files.single.name}');
  },
)
```

## Validation

### Required Fields
- All fields marked as required must have a value
- Empty text fields trigger error
- Unselected dropdowns/radios trigger error
- Yes/No always has a value (defaults to No)

### Field-Specific Validation
- **Email**: Standard email format validation
- **Phone**: Numeric keyboard, format validation
- **Number**: Only numeric input allowed
- **File**: File type restrictions (jpg, png, pdf, doc, docx)

## UI/UX Features

### Visual Indicators
- Required fields show red asterisk (*)
- Field type icons for easy identification
- Consistent styling across all field types
- Success state for file uploads (green border + checkmark)

### User Experience
- Smooth animations
- Clear error messages
- Disabled state during submission
- Helper text for dropdown/radio/checkbox options
- File upload shows selected filename

## Future Enhancements

### Priority 1
- [ ] Firebase Storage integration for file uploads
- [ ] Download link for uploaded files in PDF
- [ ] Date/Time picker field types
- [ ] URL field type with validation

### Priority 2
- [ ] Conditional fields (show field based on previous answer)
- [ ] Field duplication/cloning
- [ ] Field reordering (drag & drop)
- [ ] Field templates (save common field sets)

### Priority 3
- [ ] Multi-language support for field labels
- [ ] Field-level validation rules (min/max length, regex)
- [ ] Rich text editor for long-text fields
- [ ] Image preview for uploaded images
- [ ] Bulk edit participant custom field values

## Testing Checklist

### Event Creation
- [ ] Add all field types successfully
- [ ] Edit field after creation
- [ ] Remove field
- [ ] Save event with custom fields
- [ ] Load event with custom fields

### Participant Check-In
- [ ] Fill text/number/email/phone fields
- [ ] Select from dropdown
- [ ] Choose radio option
- [ ] Select multiple checkboxes
- [ ] Toggle yes/no switch
- [ ] Upload file (all supported types)
- [ ] Submit with all fields filled
- [ ] Validate required field errors

### Data Display
- [ ] View custom fields in live list
- [ ] Export PDF with table format
- [ ] Verify all field values in PDF
- [ ] Handle long text/multiple selections properly

## Known Limitations

1. **File Upload**: Currently only stores filename; actual file not uploaded to server
2. **File Size**: No size limit validation yet
3. **Checkbox Display**: Long option lists may overflow on small screens
4. **PDF Table**: Too many custom fields may cause layout issues in PDF

## Support

For issues or feature requests related to advanced custom fields:
1. Check existing field type supports your use case
2. Verify data structure matches documentation
3. Test validation rules
4. Review console logs for errors

## Examples

### Example 1: Conference Registration
```
Custom Fields:
- Organization (Text)
- Job Title (Text)
- Years of Experience (Number)
- T-Shirt Size (Dropdown: S, M, L, XL, XXL)
- Dietary Restrictions (Checkbox: None, Vegetarian, Vegan, Gluten-Free)
- Attending Dinner (Yes/No)
```

### Example 2: Workshop Enrollment
```
Custom Fields:
- College Name (Text)
- Branch (Dropdown: CS, IT, EC, ME)
- Semester (Number)
- Experience Level (Radio: Beginner, Intermediate, Advanced)
- Laptop Available (Yes/No)
- ID Card (File Upload)
```

### Example 3: Sports Event
```
Custom Fields:
- Emergency Contact (Phone)
- Blood Group (Dropdown: A+, A-, B+, B-, O+, O-, AB+, AB-)
- Sports (Checkbox: Cricket, Football, Basketball, Badminton)
- Previous Participation (Yes/No)
- Medical Certificate (File Upload)
```
