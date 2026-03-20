import React, { useState, useEffect, useRef } from 'react';
import { useFormStyles } from '../../styles/formStyles';
import {
    Box,
    Stack,
    Typography,
    Button,
    TextField,
    Select,
    MenuItem,
    FormControl,
    InputAdornment,
    Tooltip,
    IconButton,
    Grid,
    Radio,
    RadioGroup,
    FormControlLabel,
    Checkbox,
    Avatar,
    CircularProgress,
    useTheme
} from '@mui/material';
import {
    X,
    Settings,
    User,
    Briefcase,
    Phone,
    CreditCard,
    LogOut,
    CircleDashed,
    FileSignature,
    ChevronDown,
    ChevronUp,
    Clock,
    Mail,
    MapPin,
    IdCard,
    UploadCloud,
    Plus
} from 'lucide-react';
import CustomDatePicker from '../CustomDatePicker';
import {
    fetchDesignations,
    fetchDepartments,
    createEmployee,
    updateEmployee,
    uploadEmployeePhoto,
    deleteEmployeePhoto,
    fetchEmployeeFields,
    fetchEmployeeBankDetails,
    saveEmployeeBankDetails,
    uploadEmployeeSignature,
    deleteEmployeeSignature
} from '../../utils/api';
import CreateDesignationModal from './CreateDesignationModal';
import CreateDepartmentModal from './CreateDepartmentModal';
import config from '../../config';
import toast from 'react-hot-toast';
import {
    validateEmail,
    validateMobile,
    validatePF,
    validateESIC,
    validateAadhar,
    validateIFSC,
    validateAccountNumber,
    validateInteger
} from '../../utils/validation';

// Core employee model properties stored as dedicated columns. Any dynamic field
// not in this list will be stored in the CustomFieldsJson blob.
const CORE_MODEL_KEYS = new Set([
    'employeeCode',
    'salutation',
    'name',
    'email',
    'designation',
    'gender',
    'mobile',
    'joiningDate',
    'dateOfBirth',
    'profilePictureUrl',
    'fatherOrSpouse',
    'presentAddress',
    'permanentAddress',
    'employeePfNo',
    'employeeEsicNo',
    'employeeAadharNo',
    'days80ServiceCompletionDate',
    'permanentAppointmentDate',
    'periodOfSuspension',
    'signatureImageUrl',
    'thumbImpressionImageUrl',
    'dateOfExit',
    'reasonForExit',
    'department',
    'remarks'
]);

const AddEmployeeForm = ({ onClose, organizationId, organizationName, editData = null, onSaved }) => {
    const fs = useFormStyles();
    const theme = useTheme();
    const isDark = theme.palette.mode === 'dark';

    const [fields, setFields] = useState([]);
    const [sections, setSections] = useState({});
    const [formData, setFormData] = useState({});
    const [bankData, setBankData] = useState({ accountNumber: '', bankName: '', branchName: '', ifscCode: '' });
    const [photoFile, setPhotoFile] = useState(null);
    const [photoPreview, setPhotoPreview] = useState(null);
    const [signatureFile, setSignatureFile] = useState(null);
    const [signaturePreview, setSignaturePreview] = useState(null);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);

    const photoInputRef = useRef(null);
    const signatureInputRef = useRef(null);

    const [designations, setDesignations] = useState([]);
    const [isDesignationModalOpen, setIsDesignationModalOpen] = useState(false);
    const [departments, setDepartments] = useState([]);
    const [isDepartmentModalOpen, setIsDepartmentModalOpen] = useState(false);
    const [errors, setErrors] = useState({});

    // Initial load
    useEffect(() => {
        const init = async () => {
            try {
                const configData = await fetchEmployeeFields(organizationId);
                const visibleFields = configData.filter(f => f.IsVisible);
                setFields(visibleFields);

                // Group by Section
                const grouped = visibleFields.reduce((acc, field) => {
                    const section = field.section_name || 'General';
                    if (!acc[section]) acc[section] = [];
                    acc[section].push(field);
                    return acc;
                }, {});
                setSections(grouped);

                // Init Form Data
                const initialData = {};

                // Safely parse any existing custom field values for edit mode.
                // Supports both camelCase (`customFieldsJson`) and snake_case (`custom_fields_json`)
                // without assuming which shape the API returns.
                let existingCustomValues = {};
                if (editData) {
                    const rawCustom =
                        editData.customFieldsJson ??
                        editData.custom_fields_json ??
                        editData.custom_fieldsJson ??
                        null;

                    if (rawCustom) {
                        try {
                            // If backend already gave us an object, use it directly; otherwise parse JSON.
                            existingCustomValues =
                                typeof rawCustom === 'string' ? JSON.parse(rawCustom) : rawCustom;
                        } catch {
                            existingCustomValues = {};
                        }
                    }
                }

                visibleFields.forEach(f => {
                    const key = f.field_key;

                    // Prefer a direct property on editData when present (for core fields)
                    const directValue =
                        editData && Object.prototype.hasOwnProperty.call(editData, key)
                            ? editData[key]
                            : undefined;

                    // Then fall back to the dynamic custom values blob
                    const customValue = existingCustomValues[key];

                    initialData[key] =
                        directValue !== undefined && directValue !== null
                            ? directValue
                            : customValue !== undefined && customValue !== null
                                ? customValue
                                : '';
                });

                // Special mapping: snake_case DB keys → camelCase form keys
                if (editData) {
                    const snakeToCamel = {
                        name: 'name',
                        email: 'email',
                        employee_code: 'employeeCode',
                        salutation: 'salutation',
                        gender: 'gender',
                        mobile: 'mobile',
                        joining_date: 'joiningDate',
                        date_of_birth: 'dateOfBirth',
                        designation: 'designation',
                        father_or_spouse: 'fatherOrSpouse',
                        present_address: 'presentAddress',
                        permanent_address: 'permanentAddress',
                        employee_pf_no: 'employeePfNo',
                        employee_esic_no: 'employeeEsicNo',
                        employee_aadhar_no: 'employeeAadharNo',
                        days_80_service_completion_date: 'days80ServiceCompletionDate',
                        permanent_appointment_date: 'permanentAppointmentDate',
                        period_of_suspension: 'periodOfSuspension',
                        date_of_exit: 'dateOfExit',
                        reason_for_exit: 'reasonForExit',
                        department: 'department',
                        remarks: 'remarks',
                        profile_picture_url: 'profilePictureUrl',
                        signature_image_url: 'signatureImageUrl'
                    };

                    // Support both snake_case (from SQL) and camelCase (from API JSON)
                    Object.entries(snakeToCamel).forEach(([snake, camel]) => {
                        const value =
                            editData[snake] !== undefined && editData[snake] !== null
                                ? editData[snake]
                                : editData[camel];

                        if (value !== undefined && value !== null) {
                            initialData[camel] = value;
                        }
                    });

                    const photoUrl = editData.profile_picture_url || editData.profilePictureUrl;
                    if (photoUrl) {
                        setPhotoPreview(photoUrl.startsWith('http') ? photoUrl : `${config.API_BASE_URL.replace('/api', '')}${photoUrl}`);
                    }
                    const sigUrl = editData.signature_image_url || editData.signatureImageUrl;
                    if (sigUrl) {
                        setSignaturePreview(sigUrl.startsWith('http') ? sigUrl : `${config.API_BASE_URL.replace('/api', '')}${sigUrl}`);
                    }

                    // Load bank details for edit mode
                    try {
                        const bankDetails = await fetchEmployeeBankDetails(editData.id);
                        if (bankDetails) {
                            // Support multiple possible casing/conventions from the API
                            // without hardcoding a single expected shape.
                            const getFirstNonNull = (obj, keys, fallback = '') => {
                                for (const k of keys) {
                                    if (obj[k] !== undefined && obj[k] !== null) return obj[k];
                                }
                                return fallback;
                            };

                            setBankData({
                                accountNumber: getFirstNonNull(bankDetails, ['accountNumber', 'AccountNumber', 'account_number']),
                                bankName: getFirstNonNull(bankDetails, ['bankName', 'BankName', 'accountHolderName', 'AccountHolderName', 'account_holder_name']),
                                branchName: getFirstNonNull(bankDetails, ['branch', 'Branch', 'branchName']),
                                ifscCode: getFirstNonNull(bankDetails, ['ifsc', 'IFSC', 'Ifsc', 'ifscCode'])
                            });
                        }
                    } catch (e) { console.error('Failed to load bank details', e); }
                }

                setFormData(initialData);
                await Promise.all([loadDesignations(), loadDepartments()]);
            } catch (error) {
                toast.error('Failed to load form configuration');
                console.error('Failed to load form configuration:', error);
            } finally {
                setLoading(false);
            }
        };
        init();
    }, [organizationId, editData]);

    const loadDesignations = async () => {
        if (!organizationId) return;
        try {
            const data = await fetchDesignations(organizationId);
            setDesignations(data || []);
        } catch (error) {
            console.error('Failed to load designations');
        }
    };

    const loadDepartments = async () => {
        if (!organizationId) return;
        try {
            const data = await fetchDepartments(organizationId);
            setDepartments(data || []);
        } catch (error) {
            console.error('Failed to load departments');
        }
    };

    // Dynamically derive special field groupings from configuration
    const bankKeys = React.useMemo(
        () => new Set(fields.filter(f => f.section_name === 'Bank Account Details').map(f => f.field_key)),
        [fields]
    );

    const handleChange = (key) => (e) => {
        const value = e.target.value;
        if (bankKeys.has(key)) {
            setBankData(prev => ({ ...prev, [key]: value }));
        } else {
            setFormData(prev => ({ ...prev, [key]: value }));
        }

        if (errors[key]) {
            setErrors(prev => {
                const newErrors = { ...prev };
                delete newErrors[key];
                return newErrors;
            });
        }
    };

    const handleFileChange = (type) => (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
        if (!allowed.includes(file.type)) {
            toast.error('Only JPEG, PNG, WebP or GIF images are allowed.');
            return;
        }
        if (file.size > 5 * 1024 * 1024) {
            toast.error('Image must be under 5 MB.');
            return;
        }

        if (type === 'photo') {
            setPhotoFile(file);
            setPhotoPreview(URL.createObjectURL(file));
        } else {
            setSignatureFile(file);
            setSignaturePreview(URL.createObjectURL(file));
        }
    };

    const handleRemoveFile = (type) => {
        if (type === 'photo') {
            setPhotoFile(null);
            setPhotoPreview(null);
            if (photoInputRef.current) photoInputRef.current.value = '';
            setFormData(prev => ({ ...prev, profilePictureUrl: null }));
        } else {
            setSignatureFile(null);
            setSignaturePreview(null);
            if (signatureInputRef.current) signatureInputRef.current.value = '';
            setFormData(prev => ({ ...prev, signatureImageUrl: null }));
        }
    };

    const handleSave = async (andAddMore = false) => {
        // Validation
        const newErrors = {};

        // 1. Check metadata-driven mandatory fields
        fields.forEach(f => {
            const value = bankKeys.has(f.field_key) ? bankData[f.field_key] : formData[f.field_key];
            if (f.IsMandatory && (!value || value.toString().trim() === '')) {
                newErrors[f.field_key] = `${f.display_label} is required`;
            }
        });

        // 2. Force check core system requirements (Name/Email)
        if (!formData.name || formData.name.trim() === '') newErrors['name'] = 'Name is required';
        if (!formData.email || formData.email.trim() === '') newErrors['email'] = 'Email is required';

        // 3. Optional format validations (Only if field has a value)
        const emailErr = validateEmail(formData.email);
        if (emailErr) newErrors['email'] = emailErr;

        const mobileErr = validateMobile(formData.mobile);
        if (mobileErr) newErrors['mobile'] = mobileErr;

        const pfErr = validatePF(formData.employeePfNo);
        if (pfErr) newErrors['employeePfNo'] = pfErr;

        const esicErr = validateESIC(formData.employeeEsicNo);
        if (esicErr) newErrors['employeeEsicNo'] = esicErr;

        const aadharErr = validateAadhar(formData.employeeAadharNo);
        if (aadharErr) newErrors['employeeAadharNo'] = aadharErr;

        const suspensionErr = validateInteger(formData.periodOfSuspension);
        if (suspensionErr) newErrors['periodOfSuspension'] = suspensionErr;

        const ifscErr = validateIFSC(bankData.ifscCode);
        if (ifscErr) newErrors['ifscCode'] = ifscErr;

        const accountErr = validateAccountNumber(bankData.accountNumber);
        if (accountErr) newErrors['accountNumber'] = accountErr;

        if (Object.keys(newErrors).length > 0) {
            setErrors(newErrors);
            toast.error('Please fill in all mandatory fields');

            // Find visual order for scrolling
            const visualOrder = [];
            Object.values(sections).forEach(sectionFields => {
                sectionFields.sort((a, b) => a.field_order - b.field_order).forEach(f => {
                    visualOrder.push(f.field_key);
                });
            });

            const firstErrorKey = visualOrder.find(key => newErrors[key]) || Object.keys(newErrors)[0];
            const element = document.getElementById(`field-${firstErrorKey}`);
            if (element) {
                element.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
            return;
        }

        setSaving(true);
        try {
            const payload = { organizationId };
            const customFields = {};

            Object.keys(formData).forEach(key => {
                if (bankKeys.has(key)) return; // handled separately via bank details endpoint

                if (CORE_MODEL_KEYS.has(key)) {
                    payload[key] = formData[key];
                } else {
                    customFields[key] = formData[key];
                }
            });

            payload.customFieldsJson = JSON.stringify(customFields);

            let currentId = editData?.id;
            if (editData) {
                await updateEmployee(editData.id, payload);
            } else {
                const res = await createEmployee(payload);
                currentId = res.employeeId;
                if (!currentId || currentId <= 0) {
                    throw new Error('Server returned invalid employee ID. Employee may not have been created.');
                }
            }

            // Handle photo changes
            if (photoFile && currentId) {
                try { await uploadEmployeePhoto(currentId, photoFile); }
                catch { toast.error('Employee saved, but photo upload failed.'); }
            } else if (!photoPreview && (editData?.profile_picture_url || editData?.profilePictureUrl) && currentId) {
                try { await deleteEmployeePhoto(currentId); }
                catch { toast.error('Employee saved, but failed to remove photo.'); }
            }

            // Handle signature changes
            if (signatureFile && currentId) {
                try { await uploadEmployeeSignature(currentId, signatureFile); }
                catch { toast.error('Employee saved, but signature upload failed.'); }
            } else if (!signaturePreview && (editData?.signature_image_url || editData?.signatureImageUrl) && currentId) {
                try { await deleteEmployeeSignature(currentId); }
                catch { toast.error('Employee saved, but failed to remove signature.'); }
            }

            // Handle bank details (save to dedicated table)
            const bankFields = fields.filter(f => f.section_name === 'Bank Account Details');
            const hasBankData = bankFields.some(f => bankData[f.field_key]);

            if (hasBankData && currentId) {
                // Construct payload dynamically
                const bankPayload = { OrganizationId: organizationId };
                bankFields.forEach(f => {
                    const key = f.field_key;
                    const value = bankData[key];
                    if (value) {
                        // Map specific keys to PascalCase backend props
                        let backendKey = key.charAt(0).toUpperCase() + key.slice(1);
                        if (key === 'ifscCode') backendKey = 'Ifsc';
                        if (key === 'bankName') backendKey = 'AccountHolderName';
                        if (key === 'branchName') backendKey = 'Branch';

                        bankPayload[backendKey] = (backendKey === 'AccountNumber') ? parseInt(value) : value;
                    }
                });

                try {
                    await saveEmployeeBankDetails(currentId, bankPayload);
                } catch { toast.error('Employee saved, but bank details could not be saved.'); }
            }

            toast.success(editData ? 'Employee updated successfully!' : 'Employee added successfully!');
            if (onSaved) onSaved();

            if (andAddMore) {
                // Reset form for next entry, keeping some common fields if desired
                setFormData(prev => {
                    const newFormData = {};
                    fields.forEach(f => {
                        if (f.field_key === 'designation' || f.field_key === 'department' || f.field_key === 'gender' || f.field_key === 'joiningDate') {
                            newFormData[f.field_key] = prev[f.field_key];
                        } else {
                            newFormData[f.field_key] = '';
                        }
                    });
                    return newFormData;
                });
                handleRemoveFile('photo');
                handleRemoveFile('signature');
            } else {
                onClose();
            }
        } catch (err) {
            console.error('[AddEmployeeForm] Error:', err);

            if (err.response?.status === 400 && err.response.data?.errors) {
                const serverErrors = err.response.data.errors;
                const mappedErrors = {};

                // Map server property names to form field keys
                Object.keys(serverErrors).forEach(prop => {
                    // Try exact match or camelCase version
                    const camelProp = prop.charAt(0).toLowerCase() + prop.slice(1);
                    if (formData[prop] !== undefined) mappedErrors[prop] = true;
                    else mappedErrors[camelProp] = true;
                });

                setErrors(mappedErrors);
                toast.error('Please check the highlighted fields');
            } else {
                toast.error(err?.response?.data?.message || err?.message || 'Failed to save employee');
            }
        } finally {
            setSaving(false);
        }
    };

    const groupStyle = {
        p: 3,
        borderRadius: '16px',
        bgcolor: isDark ? 'rgba(255,255,255,0.02)' : 'rgba(0,0,0,0.01)',
        border: '1px solid',
        borderColor: isDark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)',
        mb: 3
    };

    const groupTitleStyle = {
        fontSize: '16px',
        fontWeight: 700,
        color: 'primary.main',
        mb: 2,
        display: 'flex',
        alignItems: 'center',
        gap: 1
    };

    const labelStyle = {
        fontSize: '13px',
        mb: 0.8,
        color: isDark ? '#cbd5e1' : '#475569',
        fontWeight: 600,
        display: 'flex',
        alignItems: 'center'
    };
    const starStyle = { color: '#f43f5e', marginLeft: '3px', fontSize: '14px' };
    const inputStyle = {
        ...fs.input,
        '& .MuiOutlinedInput-root': {
            ...fs.input['& .MuiOutlinedInput-root'],
            height: '44px',
            borderRadius: '10px',
            transition: 'all 0.2s ease-in-out',
            bgcolor: isDark ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.02)',
            '&:hover': {
                bgcolor: isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)',
                borderColor: 'primary.main',
            },
            '&.Mui-focused': {
                bgcolor: isDark ? 'rgba(255,255,255,0.01)' : '#fff',
                boxShadow: `0 0 0 4px ${isDark ? 'rgba(59,130,246,0.15)' : 'rgba(59,130,246,0.1)'}`,
            },
            '&.Mui-error': {
                borderColor: '#f43f5e',
                bgcolor: isDark ? 'rgba(244,63,94,0.05)' : 'rgba(244,63,94,0.02)',
                '&:hover': {
                    bgcolor: isDark ? 'rgba(244,63,94,0.08)' : 'rgba(244,63,94,0.04)',
                    borderColor: '#f43f5e',
                },
                '& .MuiOutlinedInput-notchedOutline': {
                    borderColor: '#f43f5e',
                    borderWidth: '1px'
                },
                '&:hover .MuiOutlinedInput-notchedOutline': {
                    borderColor: '#f43f5e',
                },
                '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                    borderColor: '#f43f5e',
                }
            }
        },
        '& .MuiInputBase-input': {
            fontSize: '14px',
            color: isDark ? '#f1f5f9' : '#1e293b',
        }
    };

    const renderField = (field) => {
        const { field_key, display_label, component_type, grid_size, options_json, IsMandatory } = field;

        const label = (
            <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 0.8 }}>
                <Typography sx={{ ...labelStyle, mb: 0 }}>
                    {display_label} {IsMandatory ? <span style={starStyle}>*</span> : null}
                </Typography>
                {field_key === 'permanentAddress' && (
                    <FormControlLabel
                        control={
                            <Checkbox
                                size="small"
                                checked={!!(formData.presentAddress && formData.permanentAddress === formData.presentAddress)}
                                onChange={(e) => {
                                    if (e.target.checked && formData.presentAddress) {
                                        setFormData(prev => ({ ...prev, permanentAddress: prev.presentAddress }));
                                    } else {
                                        setFormData(prev => ({ ...prev, permanentAddress: '' }));
                                    }
                                }}
                                sx={{ p: 0, mr: 0.5, color: 'primary.main' }}
                            />
                        }
                        label={<Typography sx={{ fontSize: '11px', color: 'primary.main', fontWeight: 600 }}>Same as Present</Typography>}
                        sx={{ m: 0 }}
                    />
                )}
            </Stack>
        );

        let input;
        switch (component_type) {
            case 'select':
                let options = [];
                try { options = options_json ? JSON.parse(options_json) : []; } catch (e) { console.error("Error parsing options_json:", e); }

                // Hardcoded lookups for system entities
                if (field_key === 'designation') options = designations.map(d => ({ label: d.designationName, value: d.designationName }));
                if (field_key === 'department') options = departments.map(d => ({ label: d.departmentName, value: d.departmentName }));
                if (field_key === 'gender') options = [{ label: 'Male', value: 'Male' }, { label: 'Female', value: 'Female' }, { label: 'Others', value: 'Others' }];
                if (field_key === 'salutation') options = [{ label: 'Mr.', value: 'Mr.' }, { label: 'Ms.', value: 'Ms.' }, { label: 'Mrs.', value: 'Mrs.' }, { label: 'Dr.', value: 'Dr.' }];

                const fieldValue = bankKeys.has(field_key) ? bankData[field_key] : formData[field_key];

                input = (
                    <FormControl fullWidth error={!!errors[field_key]}>
                        <Select
                            fullWidth
                            size="small"
                            value={fieldValue || ''}
                            onChange={handleChange(field_key)}
                            sx={inputStyle}
                            IconComponent={ChevronDown}
                        >
                            <MenuItem value="">-- Select --</MenuItem>
                            {options.map((opt, index) => (
                                <MenuItem key={opt.value || index} value={opt.value}>{opt.label}</MenuItem>
                            ))}
                            {(field_key === 'designation' || field_key === 'department') && (
                                <MenuItem value="__add_new__" sx={{ color: 'primary.main', fontWeight: 600 }}
                                    onClick={(e) => {
                                        e.stopPropagation(); // Prevent select from closing immediately
                                        field_key === 'designation' ? setIsDesignationModalOpen(true) : setIsDepartmentModalOpen(true);
                                    }}>
                                    <Plus size={16} style={{ marginRight: 8 }} /> Add New
                                </MenuItem>
                            )}
                        </Select>
                        {errors[field_key] && (
                            <Typography sx={{ color: '#f43f5e', fontSize: '11px', mt: 0.5, ml: 1, fontWeight: 500 }}>
                                {errors[field_key]}
                            </Typography>
                        )}
                    </FormControl>
                );
                break;
            case 'date':
                input = (
                    <CustomDatePicker
                        label=""
                        value={(bankKeys.has(field_key) ? bankData[field_key] : formData[field_key]) || ''}
                        onChange={handleChange(field_key)}
                        inputStyle={inputStyle}
                        error={!!errors[field_key]}
                        helperText={errors[field_key]}
                    />
                );
                break;
            case 'textarea':
                input = (
                    <TextField
                        fullWidth
                        multiline
                        rows={3}
                        size="small"
                        value={(bankKeys.has(field_key) ? bankData[field_key] : formData[field_key]) || ''}
                        onChange={handleChange(field_key)}
                        sx={{ ...inputStyle, '& .MuiOutlinedInput-root': { ...inputStyle['& .MuiOutlinedInput-root'], height: 'auto' } }}
                        error={!!errors[field_key]}
                        helperText={errors[field_key]}
                    />
                );
                break;
            case 'radio':
                input = (
                    <RadioGroup row value={(bankKeys.has(field_key) ? bankData[field_key] : formData[field_key]) || ''} onChange={handleChange(field_key)}>
                        {options_json && JSON.parse(options_json).map((opt, index) => (
                            <FormControlLabel key={opt.value || index} value={opt.value} control={<Radio size="small" />} label={<Typography sx={{ fontSize: '14px' }}>{opt.label}</Typography>} />
                        ))}
                    </RadioGroup>
                );
                break;
            default: // text, number, email, password etc.
                input = (
                    <TextField
                        fullWidth
                        size="small"
                        value={(bankKeys.has(field_key) ? bankData[field_key] : formData[field_key]) || ''}
                        onChange={handleChange(field_key)}
                        sx={inputStyle}
                        error={!!errors[field_key]}
                        helperText={errors[field_key]}
                    />
                );
        }

        return (
            <Grid size={{ xs: 12, md: grid_size || 6 }} key={field_key} id={`field-${field_key}`}>
                {label}
                {input}
            </Grid>
        );
    };

    if (loading) return <Box sx={{ p: 5, textAlign: 'center' }}><CircularProgress /></Box>;

    return (
        <Box sx={{ width: '100%', height: '100%', bgcolor: 'background.paper', display: 'flex', flexDirection: 'column', overflow: 'visible', position: 'relative', boxShadow: isDark ? 'inset 0 0 20px rgba(0,0,0,0.5)' : 'none' }}>
            <IconButton onClick={onClose} size="small" sx={fs.closeBtn}>
                <X size={18} strokeWidth={3} />
            </IconButton>

            {/* Header */}
            <Box sx={{
                ...fs.header,
                position: 'relative',
                bgcolor: isDark ? 'rgba(255,255,255,0.02)' : 'rgba(0,0,0,0.01)',
                borderBottom: '1px solid',
                borderColor: isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)',
                py: 2.5
            }}>
                <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ width: '100%' }}>
                    <Box>
                        <Stack direction="row" spacing={1.5} alignItems="center">
                            <Box sx={{ p: 1, borderRadius: '12px', bgcolor: 'primary.main', color: '#fff', display: 'flex', boxShadow: '0 4px 12px rgba(59,130,246,0.3)' }}>
                                <User size={20} />
                            </Box>
                            <Box>
                                <Typography sx={{ fontWeight: 800, fontSize: '1.2rem', color: isDark ? '#fff' : '#1e293b', letterSpacing: '-0.02em' }}>
                                    {editData ? 'Edit Employee Profile' : 'New Employee Registration'}
                                </Typography>
                                {organizationName && (
                                    <Typography sx={{ fontSize: '12px', color: 'primary.main', mt: 0, fontWeight: 600, opacity: 0.8 }}>
                                        {organizationName}
                                    </Typography>
                                )}
                            </Box>
                        </Stack>
                    </Box>
                </Stack>
            </Box>

            {/* Main Content (Scrollable) */}
            <Box sx={{ p: { xs: 2, sm: 3 }, flex: 1, overflowY: 'auto', overflowX: 'hidden', bgcolor: isDark ? 'rgba(0,0,0,0.2)' : 'rgba(0,0,0,0.01)' }}>
                {Object.keys(sections).map(sectionName => {
                    const isPersonalInfo = sectionName === 'Personal Information';

                    const photoUploadUI = (
                        <Box>
                            <Stack alignItems="center" spacing={1} sx={{ mb: 3 }}>
                                <Typography sx={{ ...labelStyle, alignSelf: 'center' }}>Profile Photo</Typography>
                                <Box
                                    onClick={() => !photoPreview && photoInputRef.current?.click()}
                                    sx={{
                                        border: photoPreview ? 'none' : '2px dashed',
                                        borderColor: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)',
                                        bgcolor: isDark ? 'rgba(255,255,255,0.02)' : 'rgba(0,0,0,0.02)',
                                        borderRadius: '20px',
                                        width: 140, height: 140,
                                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                                        cursor: 'pointer', overflow: 'hidden', position: 'relative',
                                        transition: 'all 0.2s',
                                        '&:hover': { borderColor: 'primary.main', bgcolor: 'action.hover' }
                                    }}
                                >
                                    {photoPreview ? (
                                        <>
                                            <img src={photoPreview} alt="Preview" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                                            <IconButton
                                                onClick={(e) => { e.stopPropagation(); handleRemoveFile('photo'); }}
                                                sx={{ position: 'absolute', top: 8, right: 8, bgcolor: 'rgba(0,0,0,0.6)', color: '#fff', '&:hover': { bgcolor: 'rgba(0,0,0,0.8)' }, p: 0.5 }}
                                            >
                                                <X size={14} />
                                            </IconButton>
                                        </>
                                    ) : (
                                        <Stack alignItems="center" spacing={1}>
                                            <UploadCloud size={28} style={{ opacity: 0.4, color: isDark ? '#fff' : '#000' }} />
                                            <Typography sx={{ fontSize: '11px', opacity: 0.5 }}>Click to upload</Typography>
                                        </Stack>
                                    )}
                                </Box>
                                <input ref={photoInputRef} type="file" style={{ display: 'none' }} onChange={handleFileChange('photo')} accept="image/jpeg,image/png,image/webp,image/gif" />
                            </Stack>

                            <Stack alignItems="center" spacing={1}>
                                <Typography sx={{ ...labelStyle, alignSelf: 'center' }}><FileSignature size={16} style={{ marginRight: '8px' }} /> Signature / Thumb</Typography>
                                <Box
                                    onClick={() => !signaturePreview && signatureInputRef.current?.click()}
                                    sx={{
                                        border: signaturePreview ? 'none' : '2px dashed',
                                        borderColor: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)',
                                        bgcolor: isDark ? 'rgba(255,255,255,0.02)' : 'rgba(0,0,0,0.02)',
                                        borderRadius: '16px',
                                        width: '100%',
                                        height: '100px',
                                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                                        cursor: 'pointer', overflow: 'hidden', position: 'relative',
                                        transition: 'all 0.2s',
                                        '&:hover': { borderColor: 'primary.main', bgcolor: 'action.hover' }
                                    }}
                                >
                                    {signaturePreview ? (
                                        <Box sx={{ position: 'relative' }}>
                                            <img src={signaturePreview} alt="Signature" style={{ maxHeight: 80, borderRadius: '4px' }} />
                                            <IconButton
                                                onClick={(e) => { e.stopPropagation(); handleRemoveFile('signature'); }}
                                                sx={{ position: 'absolute', top: -10, right: -10, bgcolor: 'rgba(0,0,0,0.6)', color: '#fff', p: 0.3 }}
                                            >
                                                <X size={12} />
                                            </IconButton>
                                        </Box>
                                    ) : (
                                        <Stack alignItems="center" spacing={1}>
                                            <UploadCloud size={24} style={{ opacity: 0.4 }} />
                                            <Typography sx={{ fontSize: '11px', opacity: 0.5, textAlign: 'center' }}>Upload Signature / Thumb</Typography>
                                        </Stack>
                                    )}
                                    <input ref={signatureInputRef} type="file" style={{ display: 'none' }} onChange={handleFileChange('signature')} accept="image/jpeg,image/png,image/webp,image/gif" />
                                </Box>
                            </Stack>
                        </Box>
                    );

                    return (
                        <Box key={sectionName} sx={groupStyle}>
                            <Typography sx={groupTitleStyle}>
                                {sectionName === 'Personal Information' && <User size={18} />}
                                {sectionName === 'Bank Account Details' && <CreditCard size={18} />}
                                {sectionName === 'Contact Info' && <Phone size={18} />}
                                {sectionName === 'Exit Details & Remarks' && <LogOut size={18} />}
                                {(!['Personal Information', 'Bank Account Details', 'Contact Info', 'Exit Details & Remarks'].includes(sectionName)) && <Settings size={18} />}
                                {sectionName}
                            </Typography>

                            {isPersonalInfo ? (
                                <Grid container spacing={3}>
                                    <Grid size={{ xs: 12, md: 9 }}>
                                        <Grid container spacing={3}>
                                            {sections[sectionName].sort((a, b) => a.field_order - b.field_order).map(renderField)}
                                        </Grid>
                                    </Grid>
                                    <Grid size={{ xs: 12, md: 3 }}>
                                        {photoUploadUI}
                                    </Grid>
                                </Grid>
                            ) : (
                                <Grid container spacing={3}>
                                    {sections[sectionName].sort((a, b) => a.field_order - b.field_order).map(renderField)}
                                </Grid>
                            )}
                        </Box>
                    );
                })}
            </Box>

            {/* Footer */}
            <Box sx={{
                ...fs.footer,
                bgcolor: isDark ? 'rgba(255,255,255,0.02)' : 'rgba(0,0,0,0.01)',
                borderTop: '1px solid',
                borderColor: isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)',
                p: 3
            }}>
                <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} sx={{ width: '100%', maxWidth: '800px', mx: 'auto' }}>
                    <Button
                        variant="contained"
                        disabled={saving}
                        onClick={() => handleSave(false)}
                        sx={{
                            ...fs.saveBtn,
                            flex: 1.5,
                            height: 48,
                            borderRadius: '12px',
                            boxShadow: '0 4px 14px 0 rgba(0,118,255,0.39)',
                            fontSize: '15px'
                        }}
                    >
                        {saving ? 'Saving...' : (editData ? 'Update Profile' : 'Complete Registration')}
                    </Button>
                    {!editData && (
                        <Button
                            variant="contained"
                            disabled={saving}
                            onClick={() => handleSave(true)}
                            sx={{
                                ...fs.saveBtn,
                                flex: 1,
                                height: 48,
                                borderRadius: '12px',
                                boxShadow: '0 4px 14px 0 rgba(0,118,255,0.39)',
                                fontSize: '15px'
                            }}
                        >
                            {saving ? 'Saving...' : 'Add & Register Next'}
                        </Button>
                    )}
                    <Button
                        sx={{
                            ...fs.cancelBtn,
                            px: { xs: 0, sm: 4 },
                            height: 48,
                            borderRadius: '12px',
                            fontSize: '15px'
                        }}
                        onClick={onClose}
                    >
                        Cancel
                    </Button>
                </Stack>
            </Box>

            {/* Existing Modals */}
            <CreateDesignationModal open={isDesignationModalOpen} onClose={() => setIsDesignationModalOpen(false)} onSaved={loadDesignations} organizationId={organizationId} organizationName={organizationName} />
            <CreateDepartmentModal open={isDepartmentModalOpen} onClose={() => setIsDepartmentModalOpen(false)} onSaved={loadDepartments} organizationId={organizationId} organizationName={organizationName} />
        </Box>
    );
};


export default AddEmployeeForm;
