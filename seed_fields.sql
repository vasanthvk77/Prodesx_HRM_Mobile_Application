-- Clear old mappings to recreate the requested order precisely
DELETE FROM emp_data_use_fields;
DELETE FROM employee_data_fields;


INSERT INTO employee_data_fields (field_key, display_label, section_name, section_order, field_order, grid_size, component_type, is_core_field)
SELECT field_key, display_label, section_name, section_order, field_order, grid_size, component_type, is_core_field
FROM (
    VALUES 
    -- 1) to 16) Personal Information
    ('serialNo', 'Serial no', 'Personal Information', 1, 1, 6, 'text', 0),
    ('name', 'Name of the employee', 'Personal Information', 1, 2, 6, 'text', 1),
    ('employeeCode', 'Employee Id no', 'Personal Information', 1, 3, 6, 'text', 1),
    ('gender', 'Gender(M/F/Others)', 'Personal Information', 1, 4, 6, 'select', 0),
    ('fatherOrSpouse', 'Father or spouse name', 'Personal Information', 1, 5, 6, 'text', 0),
    ('dateOfBirth', 'DOB', 'Personal Information', 1, 6, 6, 'date', 0),
    ('joiningDate', 'Date of entry into service', 'Personal Information', 1, 7, 6, 'date', 0),
    ('designation', 'Designation', 'Personal Information', 1, 8, 6, 'select', 0),
    ('presentAddress', 'Present Address/ Pincode', 'Personal Information', 1, 9, 12, 'textarea', 0),
    ('permanentAddress', 'Permanent Address / Pincode', 'Personal Information', 1, 10, 12, 'textarea', 0),
    ('employeePfNo', 'Employees PF No', 'Personal Information', 1, 11, 6, 'text', 0),
    ('employeeEsicNo', 'Employees ESIC No', 'Personal Information', 1, 12, 6, 'text', 0),
    ('employeeAadharNo', 'Aadhar no', 'Personal Information', 1, 13, 12, 'text', 0),
    ('days80ServiceCompletionDate', 'Date of which completion for 80 days of service', 'Personal Information', 1, 14, 12, 'date', 0),
    ('permanentAppointmentDate', 'Date on which made permanament', 'Personal Information', 1, 15, 6, 'date', 0),
    ('periodOfSuspension', 'Period of Suspension', 'Personal Information', 1, 16, 6, 'text', 0),

    -- 17) Bank Account Details
    ('accountNumber', 'Account Number', 'Bank Account Details', 2, 1, 6, 'text', 0),
    ('bankName', 'Bank Name', 'Bank Account Details', 2, 2, 6, 'text', 0),
    ('branchName', 'Branch Name', 'Bank Account Details', 2, 3, 6, 'text', 0),
    ('ifscCode', 'IFSC Code', 'Bank Account Details', 2, 4, 6, 'text', 0),

    -- Contact Info (Requested as 19 and 20)
    ('mobile', 'Mobile number', 'Contact Info', 3, 1, 6, 'text', 0),
    ('email', 'Email id', 'Contact Info', 3, 2, 6, 'text', 0),

    -- 22) to 24) Exit Details & Remarks
    ('dateOfExit', 'date of exit', 'Exit Details & Remarks', 4, 1, 4, 'date', 0),
    ('reasonForExit', 'reason for exit', 'Exit Details & Remarks', 4, 2, 8, 'text', 0),
    ('remarks', 'Remark', 'Exit Details & Remarks', 4, 3, 12, 'textarea', 0)
) AS src(field_key, display_label, section_name, section_order, field_order, grid_size, component_type, is_core_field)
WHERE NOT EXISTS (SELECT 1 FROM employee_data_fields WHERE field_key = src.field_key);

-- Seed defaults for all existing organizations
INSERT INTO emp_data_use_fields (organization_id, field_id, is_visible, is_mandatory)
SELECT o.id, f.id, 1, 0 
FROM organizations o
CROSS JOIN employee_data_fields f
WHERE NOT EXISTS (
    SELECT 1 FROM emp_data_use_fields 
    WHERE organization_id = o.id AND field_id = f.id
);
