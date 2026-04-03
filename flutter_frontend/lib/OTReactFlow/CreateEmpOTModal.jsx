import React, { useState, useEffect } from 'react';
import {
    Dialog, DialogTitle, DialogContent, DialogActions,
    Button, TextField, Box, Typography,
    FormControl, InputLabel, CircularProgress, IconButton,
    Autocomplete, Avatar, Chip, Paper
} from '@mui/material';
import { X } from 'lucide-react';
import toast from 'react-hot-toast';
import CustomDatePicker from '../CustomDatePicker';
import { saveEmpOT, updateEmpOT, fetchEmployees } from '../../utils/api';
import config from '../../config';
import { useFormStyles } from '../../styles/formStyles';

export default function CreateEmpOTModal({ open, onClose, onSaved, editData, organizationId }) {
    const fs = useFormStyles();
    const [loading, setLoading] = useState(false);
    const [employees, setEmployees] = useState([]);
    const [selectedEmployee, setSelectedEmployee] = useState(null);
    
    const [formData, setFormData] = useState({
        employeeId: '',
        overDutyDate: new Date().toISOString().split('T')[0],
        hours: '',
        ratePerHour: '',
        remarks: ''
    });

    useEffect(() => {
        if (open && organizationId) {
            fetchEmployees(organizationId)
                .then(data => setEmployees(data || []))
                .catch(err => console.error("Failed to fetch employees", err));
        }
    }, [open, organizationId]);

    useEffect(() => {
        if (editData && open) {
            setFormData({
                employeeId: editData.employeeId || '',
                overDutyDate: editData.overDutyDate ? editData.overDutyDate.split('T')[0] : '',
                hours: editData.hours || '',
                ratePerHour: editData.ratePerHour || '',
                remarks: editData.remarks || ''
            });

            if (employees.length > 0) {
                const emp = employees.find(e => e.id === editData.employeeId);
                setSelectedEmployee(emp || null);
            }
        } else {
            setFormData({
                employeeId: '',
                overDutyDate: new Date().toISOString().split('T')[0],
                hours: '',
                ratePerHour: '',
                remarks: ''
            });
            setSelectedEmployee(null);
        }
    }, [editData, open, employees]);

    const handleChange = (e) => {
        const { name, value } = e.target;
        setFormData(prev => ({ ...prev, [name]: value }));
    };

    const handleDateChange = (e) => {
        setFormData(prev => ({ ...prev, overDutyDate: e.target.value }));
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!organizationId) {
            toast.error('Organization not selected.');
            return;
        }
        
        if (!formData.employeeId || !formData.overDutyDate || !formData.hours) {
            toast.error('Please fill in required fields.');
            return;
        }

        try {
            setLoading(true);
            const payload = {
                organizationId,
                employeeId: formData.employeeId,
                overDutyDate: formData.overDutyDate,
                hours: parseFloat(formData.hours),
                ratePerHour: formData.ratePerHour ? parseFloat(formData.ratePerHour) : null,
                remarks: formData.remarks
            };

            if (editData) {
                payload.overDutyId = editData.overDutyId;
                await updateEmpOT(payload);
                toast.success('OT updated successfully');
            } else {
                await saveEmpOT(payload);
                toast.success('OT saved successfully');
            }
            onSaved();
            onClose();
        } catch (error) {
            toast.error(error?.response?.data || 'Failed to save OT');
        } finally {
            setLoading(false);
        }
    };

    return (
        <Dialog 
            open={open} 
            onClose={onClose} 
            maxWidth="sm" 
            fullWidth
            PaperProps={{ sx: fs.modalContainer }}
            disableScrollLock
        >
            <DialogTitle sx={fs.modalHeader}>
                <Typography sx={fs.modalTitle}>
                    {editData ? 'Edit Employee OT' : 'Add Employee OT'}
                </Typography>
                <IconButton onClick={onClose} size="small" sx={fs.modalCloseButton}>
                    <X size={18} />
                </IconButton>
            </DialogTitle>
            
            <form onSubmit={handleSubmit}>
                <DialogContent sx={fs.modalBody}>
                    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5, mt: 1 }}>
                        <Autocomplete
                            options={employees}
                            getOptionLabel={(option) => `${option.name} (${option.employeeCode})`}
                            value={selectedEmployee}
                            onChange={(event, newValue) => {
                                setSelectedEmployee(newValue);
                                setFormData(prev => ({ ...prev, employeeId: newValue ? newValue.id : '' }));
                            }}
                            renderInput={(params) => (
                                <TextField {...params} label="Search & Select Employee *" size="small" required />
                            )}
                            renderOption={(props, option) => (
                                <Box component="li" {...props} sx={{ display: 'flex', gap: 1.5, py: 1 }}>
                                    <Avatar 
                                        src={config.getMediaUrl(option.profilePictureUrl || option.ProfilePictureUrl)} 
                                        sx={{ width: 32, height: 32, border: '1px solid', borderColor: 'divider' }}
                                    >
                                        {option.name?.charAt(0)}
                                    </Avatar>
                                    <Box>
                                        <Typography sx={{ fontSize: '13px', fontWeight: 600 }}>{option.name}</Typography>
                                        <Typography sx={{ fontSize: '11px', color: 'text.secondary' }}>ID: {option.employeeCode} • {option.department || 'Staff'}</Typography>
                                    </Box>
                                </Box>
                            )}
                            disablePortal
                        />

                        {selectedEmployee && (
                            <Paper variant="outlined" sx={{ p: 1.5, borderRadius: 2, bgcolor: 'action.hover', borderStyle: 'dashed', display: 'flex', alignItems: 'center', gap: 2 }}>
                                <Avatar 
                                    src={config.getMediaUrl(selectedEmployee.profilePictureUrl || selectedEmployee.ProfilePictureUrl)} 
                                    sx={{ width: 48, height: 48, border: '2px solid', borderColor: 'primary.main', boxShadow: '0 4px 10px rgba(0,0,0,0.1)' }}
                                >
                                    {selectedEmployee.name?.charAt(0)}
                                </Avatar>
                                <Box>
                                    <Typography sx={{ fontSize: '14px', fontWeight: 800, color: 'primary.main' }}>{selectedEmployee.name}</Typography>
                                    <Typography sx={{ fontSize: '12px', color: 'text.secondary', fontWeight: 600 }}>{selectedEmployee.employeeCode} • {selectedEmployee.designation || 'Staff'}</Typography>
                                    <Chip label={selectedEmployee.department || 'N/A'} size="small" sx={{ height: 18, fontSize: '10px', mt: 0.5, bgcolor: 'primary.main', color: '#fff', fontWeight: 700 }} />
                                </Box>
                            </Paper>
                        )}
                        
                        <CustomDatePicker
                            label="OT Date"
                            value={formData.overDutyDate}
                            onChange={handleDateChange}
                            starStyle={{ color: '#f43f5e', marginLeft: '3px', fontSize: '14px' }}
                        />

                        <Box sx={{ display: 'flex', gap: 2 }}>
                            <TextField
                                fullWidth
                                label="Hours *"
                                name="hours"
                                type="number"
                                inputProps={{ step: "0.5", min: "0" }}
                                value={formData.hours}
                                onChange={handleChange}
                                size="small"
                                required
                            />
                            <TextField
                                fullWidth
                                label="Rate per Hour (Optional)"
                                name="ratePerHour"
                                type="number"
                                inputProps={{ step: "0.01", min: "0" }}
                                value={formData.ratePerHour}
                                onChange={handleChange}
                                size="small"
                            />
                        </Box>

                        <TextField
                            fullWidth
                            label="Remarks"
                            name="remarks"
                            value={formData.remarks}
                            onChange={handleChange}
                            size="small"
                            multiline
                            rows={3}
                            inputProps={{ maxLength: 250 }}
                        />
                    </Box>
                </DialogContent>
                <DialogActions sx={fs.modalFooter}>
                    <Button onClick={onClose} variant="text" sx={{ color: 'text.secondary' }}>
                        Cancel
                    </Button>
                    <Button 
                        type="submit" 
                        variant="contained" 
                        disabled={loading}
                        sx={fs.submitButton}
                    >
                        {loading ? <CircularProgress size={20} color="inherit" /> : 'Save'}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}
