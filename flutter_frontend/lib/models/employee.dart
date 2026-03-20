import 'dart:convert';

class Employee {
  final int id;
  final int? userId;
  final int organizationId;
  final String? employeeCode;
  final String? salutation;
  final String name;
  final String email;
  final String? designation;
  final String? gender;
  final String? mobile;
  final DateTime? joiningDate;
  final DateTime? dateOfBirth;
  final String? profilePictureUrl;
  final String status;
  final String? fatherOrSpouse;
  final String? presentAddress;
  final String? permanentAddress;
  final String? employeePfNo;
  final String? employeeEsicNo;
  final String? employeeAadharNo;
  final DateTime? days80ServiceCompletionDate;
  final DateTime? permanentAppointmentDate;
  final int? periodOfSuspension;
  final String? signatureImageUrl;
  final String? thumbImpressionImageUrl;
  final DateTime? dateOfExit;
  final String? reasonForExit;
  final String? remarks;
  final String? role;
  final String? department;
  final int? departmentId;
  final int? designationId;
  final Map<String, dynamic> customFields;
  final EmployeeBankDetails? bankDetails;

  Employee({
    required this.id,
    this.userId,
    required this.organizationId,
    this.employeeCode,
    this.salutation,
    required this.name,
    required this.email,
    this.designation,
    this.gender,
    this.mobile,
    this.joiningDate,
    this.dateOfBirth,
    this.profilePictureUrl,
    this.status = 'Active',
    this.fatherOrSpouse,
    this.presentAddress,
    this.permanentAddress,
    this.employeePfNo,
    this.employeeEsicNo,
    this.employeeAadharNo,
    this.days80ServiceCompletionDate,
    this.permanentAppointmentDate,
    this.periodOfSuspension,
    this.signatureImageUrl,
    this.thumbImpressionImageUrl,
    this.dateOfExit,
    this.reasonForExit,
    this.remarks,
    this.role,
    this.department,
    this.departmentId,
    this.designationId,
    this.customFields = const {},
    this.bankDetails,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> customFs = {};
    final customFieldsJson = json['customFieldsJson'] ?? json['custom_fields_json'] ?? json['CustomFieldsJson'];
    if (customFieldsJson != null && customFieldsJson.toString().isNotEmpty) {
      try {
        customFs = jsonDecode(customFieldsJson);
      } catch (e) {
        print('Error decoding customFieldsJson: $e');
      }
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value == null || value == "") return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return Employee(
      id: parseInt(json['id'] ?? json['Id']) ?? 0,
      userId: parseInt(json['userId'] ?? json['user_id'] ?? json['UserId']),
      organizationId: parseInt(json['organizationId'] ?? json['organization_id'] ?? json['OrganizationId']) ?? 0,
      employeeCode: (json['employeeCode'] ?? json['employee_code'] ?? json['EmployeeCode'])?.toString(),
      salutation: (json['salutation'] ?? json['Salutation'])?.toString(),
      name: (json['name'] ?? json['Name'])?.toString() ?? '',
      email: (json['email'] ?? json['Email'])?.toString() ?? '',
      designation: (json['designation'] ?? json['Designation'])?.toString(),
      gender: (json['gender'] ?? json['Gender'])?.toString(),
      mobile: (json['mobile'] ?? json['Mobile'])?.toString(),
      joiningDate: parseDate(json['joiningDate'] ?? json['joining_date'] ?? json['JoiningDate']),
      dateOfBirth: parseDate(json['dateOfBirth'] ?? json['date_of_birth'] ?? json['DateOfBirth']),
      profilePictureUrl: (json['profilePictureUrl'] ?? json['profile_picture_url'] ?? json['ProfilePictureUrl'])?.toString(),
      status: (json['status'] ?? json['Status'])?.toString() ?? 'Active',
      fatherOrSpouse: (json['fatherOrSpouse'] ?? json['father_or_spouse'] ?? json['FatherOrSpouse'])?.toString(),
      presentAddress: (json['presentAddress'] ?? json['present_address'] ?? json['PresentAddress'])?.toString(),
      permanentAddress: (json['permanentAddress'] ?? json['permanent_address'] ?? json['PermanentAddress'])?.toString(),
      employeePfNo: (json['employeePfNo'] ?? json['employee_pf_no'] ?? json['EmployeePfNo'])?.toString(),
      employeeEsicNo: (json['employeeEsicNo'] ?? json['employee_esic_no'] ?? json['EmployeeEsicNo'])?.toString(),
      employeeAadharNo: (json['employeeAadharNo'] ?? json['employee_aadhar_no'] ?? json['EmployeeAadharNo'])?.toString(),
      days80ServiceCompletionDate: parseDate(json['days80ServiceCompletionDate'] ?? json['days_80_service_completion_date'] ?? json['Days80ServiceCompletionDate']),
      permanentAppointmentDate: parseDate(json['permanentAppointmentDate'] ?? json['permanent_appointment_date'] ?? json['PermanentAppointmentDate']),
      periodOfSuspension: parseInt(json['periodOfSuspension'] ?? json['period_of_suspension'] ?? json['PeriodOfSuspension']),
      signatureImageUrl: (json['signatureImageUrl'] ?? json['signature_image_url'] ?? json['SignatureImageUrl'])?.toString(),
      thumbImpressionImageUrl: (json['thumbImpressionImageUrl'] ?? json['thumb_impression_image_url'] ?? json['ThumbImpressionImageUrl'])?.toString(),
      dateOfExit: parseDate(json['dateOfExit'] ?? json['date_of_exit'] ?? json['DateOfExit']),
      reasonForExit: (json['reasonForExit'] ?? json['reason_for_exit'] ?? json['ReasonForExit'])?.toString(),
      remarks: (json['remarks'] ?? json['Remarks'])?.toString(),
      role: (json['role'] ?? json['Role'])?.toString(),
      department: (json['department'] ?? json['Department'])?.toString(),
      departmentId: parseInt(json['departmentId'] ?? json['department_id'] ?? json['DepartmentId']),
      designationId: parseInt(json['designationId'] ?? json['designation_id'] ?? json['DesignationId']),
      customFields: customFs,
      bankDetails: json['bankDetails'] != null ? EmployeeBankDetails.fromJson(json['bankDetails']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'organizationId': organizationId,
      'employeeCode': employeeCode,
      'salutation': salutation,
      'name': name,
      'email': email,
      'designation': designation,
      'gender': gender,
      'mobile': mobile,
      'joiningDate': joiningDate?.toIso8601String(),
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'profilePictureUrl': profilePictureUrl,
      'status': status,
      'fatherOrSpouse': fatherOrSpouse,
      'presentAddress': presentAddress,
      'permanentAddress': permanentAddress,
      'employeePfNo': employeePfNo,
      'employeeEsicNo': employeeEsicNo,
      'employeeAadharNo': employeeAadharNo,
      'days80ServiceCompletionDate': days80ServiceCompletionDate?.toIso8601String(),
      'permanentAppointmentDate': permanentAppointmentDate?.toIso8601String(),
      'periodOfSuspension': periodOfSuspension,
      'signatureImageUrl': signatureImageUrl,
      'thumbImpressionImageUrl': thumbImpressionImageUrl,
      'dateOfExit': dateOfExit?.toIso8601String(),
      'reasonForExit': reasonForExit,
      'remarks': remarks,
      'role': role,
      'department': department,
      'departmentId': departmentId,
      'designationId': designationId,
      'customFieldsJson': customFields.isNotEmpty ? jsonEncode(customFields) : null,
    };
  }
}

class EmployeeField {
  final int id;
  final String fieldKey;
  final String displayLabel;
  final String sectionName;
  final int sectionOrder;
  final int fieldOrder;
  final int gridSize;
  final String componentType;
  final List<String>? options;
  final bool isVisible;
  final bool isMandatory;

  EmployeeField({
    required this.id,
    required this.fieldKey,
    required this.displayLabel,
    required this.sectionName,
    required this.sectionOrder,
    required this.fieldOrder,
    required this.gridSize,
    required this.componentType,
    this.options,
    required this.isVisible,
    required this.isMandatory,
  });

  factory EmployeeField.fromJson(Map<String, dynamic> json) {
    List<String>? opts;
    if (json['optionsJson'] != null && json['optionsJson'].toString().isNotEmpty) {
      try {
        opts = List<String>.from(jsonDecode(json['optionsJson']));
      } catch (e) {
        print('Error decoding optionsJson: $e');
      }
    }

    return EmployeeField(
      id: json['id'] ?? json['Id'] ?? 0,
      fieldKey: json['fieldKey'] ?? json['field_key'] ?? '',
      displayLabel: json['displayLabel'] ?? json['display_label'] ?? '',
      sectionName: json['sectionName'] ?? json['section_name'] ?? 'General',
      sectionOrder: json['sectionOrder'] ?? json['section_order'] ?? 99,
      fieldOrder: json['fieldOrder'] ?? json['field_order'] ?? 99,
      gridSize: json['gridSize'] ?? json['grid_size'] ?? 6,
      componentType: json['componentType'] ?? json['component_type'] ?? 'text',
      options: opts,
      isVisible: json['isVisible'] == 1 || json['isVisible'] == true || json['IsVisible'] == true || json['IsVisible'] == 1,
      isMandatory: json['isMandatory'] == 1 || json['isMandatory'] == true || json['IsMandatory'] == true || json['IsMandatory'] == 1,
    );
  }
}

class EmployeeBankDetails {
  final int id;
  final int employeeId;
  final int organizationId;
  final int? accountNumber;
  final String? accountHolderName;
  final String? branch;
  final String? ifsc;

  EmployeeBankDetails({
    required this.id,
    required this.employeeId,
    required this.organizationId,
    this.accountNumber,
    this.accountHolderName,
    this.branch,
    this.ifsc,
  });

  factory EmployeeBankDetails.fromJson(Map<String, dynamic> json) {
    return EmployeeBankDetails(
      id: json['id'],
      employeeId: json['employeeId'],
      organizationId: json['organizationId'],
      accountNumber: json['accountNumber'],
      accountHolderName: json['accountHolderName'],
      branch: json['branch'],
      ifsc: json['ifsc'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'organizationId': organizationId,
      'accountNumber': accountNumber,
      'accountHolderName': accountHolderName,
      'branch': branch,
      'ifsc': ifsc,
    };
  }
}
