import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// Widget builder for different custom field types
class CustomFieldWidget extends StatefulWidget {
  final Map<String, dynamic> fieldConfig;
  final Function(String fieldName, dynamic value) onValueChanged;
  final bool enabled;

  const CustomFieldWidget({
    Key? key,
    required this.fieldConfig,
    required this.onValueChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  _CustomFieldWidgetState createState() => _CustomFieldWidgetState();
}

class _CustomFieldWidgetState extends State<CustomFieldWidget> {
  final TextEditingController _textController = TextEditingController();
  String? _selectedDropdownValue;
  String? _selectedRadioValue;
  List<String> _selectedCheckboxValues = [];
  bool _yesNoValue = false;
  String? _uploadedFileName;
  String? _uploadedFilePath;
  bool _isPickingFile = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Initialize yes/no to 'No' by default so it's never empty
    if (widget.fieldConfig['type'] == 'yesno') {
      widget.onValueChanged(widget.fieldConfig['name'], 'No');
    }
  }

  @override
  Widget build(BuildContext context) {
    String fieldName = widget.fieldConfig['name'];
    String fieldType = widget.fieldConfig['type'];
    bool isRequired = widget.fieldConfig['required'] ?? true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                fieldName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFieldWidget(fieldType),
        ],
      ),
    );
  }

  Widget _buildFieldWidget(String fieldType) {
    switch (fieldType) {
      case 'dropdown':
        return _buildDropdownField();
      case 'radio':
        return _buildRadioField();
      case 'checkbox':
        return _buildCheckboxField();
      case 'yesno':
        return _buildYesNoField();
      case 'file':
        return _buildFileUploadField();
      default:
        return _buildTextField(fieldType);
    }
  }

  Widget _buildTextField(String fieldType) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _textController,
        enabled: widget.enabled,
        onChanged: (value) {
          widget.onValueChanged(widget.fieldConfig['name'], value);
        },
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: ThemeHelper.getTextPrimary(context),
        ),
        decoration: InputDecoration(
          hintText: 'Enter ${widget.fieldConfig['name']}',
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: ThemeHelper.getTextTertiary(context),
          ),
          prefixIcon: Icon(
            _getIconForFieldType(fieldType),
            color: ThemeHelper.getPrimaryColor(context),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        keyboardType: _getKeyboardType(fieldType),
      ),
    );
  }

  Widget _buildDropdownField() {
    List<String> options = List<String>.from(widget.fieldConfig['options'] ?? []);
    
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDropdownValue,
          isExpanded: true,
          hint: Text(
            'Select ${widget.fieldConfig['name']}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: ThemeHelper.getTextTertiary(context),
            ),
          ),
          icon: Icon(
            Icons.arrow_drop_down_circle_rounded,
            color: ThemeHelper.getPrimaryColor(context),
          ),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: ThemeHelper.getTextPrimary(context),
          ),
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: widget.enabled
              ? (String? newValue) {
                  setState(() {
                    _selectedDropdownValue = newValue;
                  });
                  widget.onValueChanged(widget.fieldConfig['name'], newValue);
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildRadioField() {
    List<String> options = List<String>.from(widget.fieldConfig['options'] ?? []);
    
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: options.map((option) {
          return RadioListTile<String>(
            title: Text(
              option,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            value: option,
            groupValue: _selectedRadioValue,
            activeColor: ThemeHelper.getPrimaryColor(context),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: widget.enabled
                ? (String? value) {
                    setState(() {
                      _selectedRadioValue = value;
                    });
                    widget.onValueChanged(widget.fieldConfig['name'], value);
                  }
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCheckboxField() {
    List<String> options = List<String>.from(widget.fieldConfig['options'] ?? []);
    
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: options.map((option) {
          bool isSelected = _selectedCheckboxValues.contains(option);
          return CheckboxListTile(
            title: Text(
              option,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            value: isSelected,
            activeColor: ThemeHelper.getPrimaryColor(context),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: widget.enabled
                ? (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedCheckboxValues.add(option);
                      } else {
                        _selectedCheckboxValues.remove(option);
                      }
                    });
                    widget.onValueChanged(
                      widget.fieldConfig['name'],
                      _selectedCheckboxValues.join(', '),
                    );
                  }
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildYesNoField() {
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _yesNoValue ? 'Yes' : 'No',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ThemeHelper.getTextPrimary(context),
            ),
          ),
          Switch(
            value: _yesNoValue,
            activeColor: ThemeHelper.getSuccessColor(context),
            onChanged: widget.enabled
                ? (bool value) {
                    setState(() {
                      _yesNoValue = value;
                    });
                    widget.onValueChanged(
                      widget.fieldConfig['name'],
                      value ? 'Yes' : 'No',
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadField() {
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(
          color: _uploadedFileName != null
              ? ThemeHelper.getSuccessColor(context)
              : _isPickingFile
                  ? ThemeHelper.getPrimaryColor(context)
                  : ThemeHelper.getBorderColor(context),
          width: _isPickingFile ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.enabled && !_isPickingFile ? _pickFile : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _uploadedFileName != null
                      ? ThemeHelper.getSuccessColor(context).withOpacity(0.1)
                      : _isPickingFile
                          ? ThemeHelper.getPrimaryColor(context).withOpacity(0.2)
                          : ThemeHelper.getPrimaryColor(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isPickingFile
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ThemeHelper.getPrimaryColor(context),
                          ),
                        ),
                      )
                    : Icon(
                        _uploadedFileName != null
                            ? Icons.check_circle_rounded
                            : Icons.upload_file_rounded,
                        color: _uploadedFileName != null
                            ? ThemeHelper.getSuccessColor(context)
                            : ThemeHelper.getPrimaryColor(context),
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPickingFile
                          ? 'Selecting file...'
                          : _uploadedFileName ?? 'Choose file',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isPickingFile
                            ? ThemeHelper.getPrimaryColor(context)
                            : ThemeHelper.getTextPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPickingFile
                          ? 'Please wait...'
                          : _uploadedFileName != null
                              ? 'Tap to change file'
                              : 'Images, PDFs, or Documents',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _isPickingFile
                            ? ThemeHelper.getPrimaryColor(context).withOpacity(0.7)
                            : ThemeHelper.getTextTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isPickingFile)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: ThemeHelper.getTextTertiary(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    print('📁 Starting file picker...');
    
    // Show loading state immediately
    setState(() {
      _isPickingFile = true;
    });

    try {
      print('📱 Opening file picker dialog...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      print('📝 File picker result: ${result != null ? "Got result" : "null"}');
      
      if (result != null && result.files.isNotEmpty && result.files.single.name.isNotEmpty) {
        final fileName = result.files.single.name;
        // On web, path is not available, use bytes instead
        final fileBytes = result.files.single.bytes;
        final filePath = result.files.single.path; // This will be null on web
        
        print('🎉 File selected: $fileName');
        print('   Bytes available: ${fileBytes != null ? "Yes (${fileBytes.length} bytes)" : "No"}');
        print('   Path: ${filePath ?? "Not available (web platform)"}');
        
        final fieldName = widget.fieldConfig['name'];
        final valueToSend = 'File: $fileName';
        
        print('📤 Calling onValueChanged with:');
        print('   Field: $fieldName');
        print('   Value: $valueToSend');
        
        // CRITICAL: Call callback FIRST before setState
        widget.onValueChanged(fieldName, valueToSend);
        
        print('✅ Callback called successfully');
        
        // Then update local state
        setState(() {
          _uploadedFileName = fileName;
          _uploadedFilePath = filePath ?? fileName; // Use filename if path unavailable (web)
          _isPickingFile = false;
        });
        
        print('✅ File upload complete: $fileName');
      } else {
        // User cancelled or no file selected
        setState(() {
          _isPickingFile = false;
        });
        print('⚠️ File selection cancelled or no file selected');
      }
    } catch (e, stackTrace) {
      print('❌ Error picking file: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        _isPickingFile = false;
      });
      
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  IconData _getIconForFieldType(String type) {
    switch (type) {
      case 'number':
        return Icons.numbers_rounded;
      case 'email':
        return Icons.email_rounded;
      case 'phone':
        return Icons.phone_rounded;
      default:
        return Icons.text_fields_rounded;
    }
  }

  TextInputType _getKeyboardType(String type) {
    switch (type) {
      case 'number':
        return TextInputType.number;
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      default:
        return TextInputType.text;
    }
  }
}
