import React, { useState, useEffect } from 'react';
import {
    Drawer, Box, Typography, Stack, Button, TextField,
    MenuItem, CircularProgress, IconButton, FormControl, Select
} from '@mui/material';
import { X, Check, Building2 } from 'lucide-react';
import { createDepartment, updateDepartment, fetchDepartments } from '../../utils/api';
import toast from 'react-hot-toast';
import { useFormStyles } from '../../styles/formStyles';

const starStyle = { color: '#ef4444', marginLeft: '4px' };

export default function CreateDepartmentModal({ open, onClose, onSaved, editData = null, organizationId, organizationName }) {
    const fs = useFormStyles();
    const [department, setDepartment] = useState('');
    const [parentDepartmentId, setParentDepartmentId] = useState('');
    const [parentOptions, setParentOptions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        if (open) {
            setDepartment(editData?.departmentName || '');
            setParentDepartmentId(editData?.parentDepartmentId || '');
            loadParents();
        }
    }, [open, editData, organizationId]);

    const loadParents = async () => {
        try {
            setLoading(true);
            const data = await fetchDepartments(organizationId);
            if (!editData?.id) {
                setParentOptions(Array.isArray(data) ? data : []);
                return;
            }
            const descendants = new Set();
            const findDescendants = (parentId) => {
                data.forEach(d => {
                    if (d.parentDepartmentId === parentId) {
                        descendants.add(d.id);
                        findDescendants(d.id);
                    }
                });
            };
            findDescendants(editData.id);
            setParentOptions(Array.isArray(data) ? data.filter(d => d.id !== editData.id && !descendants.has(d.id)) : []);
        } catch { console.error('Failed to load parent departments'); }
        finally { setLoading(false); }
    };

    const handleSave = async () => {
        if (!department.trim()) { toast.error('Department name is required'); return; }
        try {
            setSaving(true);
            const payload = { organizationId, organizationName, departmentName: department.trim(), parentDepartmentId: parentDepartmentId || null };
            if (editData) { await updateDepartment(editData.id, payload); toast.success('Department updated successfully'); }
            else { await createDepartment(payload); toast.success('Department created successfully'); }
            onSaved(department.trim());
            onClose();
        } catch (error) {
            toast.error(error.response?.data?.message || (editData ? 'Failed to update' : 'Failed to create'));
        } finally { setSaving(false); }
    };

    return (
        <Drawer anchor="right" open={open} onClose={onClose} disableScrollLock
            sx={fs.drawer}
            PaperProps={{ sx: fs.drawerPaper }}>

            {open && (
                <IconButton onClick={onClose} size="small" sx={fs.closeBtn}>
                    <X size={18} strokeWidth={3} />
                </IconButton>
            )}

            {/* Header */}
            <Box sx={fs.header}>
                <Typography sx={{ fontWeight: 600, fontSize: '17px', color: 'text.primary' }}>
                    {editData ? 'Edit Department' : 'Add Department'}
                </Typography>
            </Box>

            {/* Body */}
            <Box sx={fs.body}>
                <Box sx={fs.sectionBox}>
                    <Stack spacing={3}>
                        <FormControl fullWidth>
                            <Typography sx={fs.label}><Building2 size={14} style={{ marginRight: 6 }} /> Organization</Typography>
                            <Box sx={fs.readonlyBox}>{organizationName || 'No Organization Selected'}</Box>
                        </FormControl>

                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={3}>
                            <FormControl fullWidth>
                                <Typography sx={fs.label}>Name <span style={starStyle}>*</span></Typography>
                                <TextField size="small" placeholder="e.g. Sales" value={department}
                                    onChange={(e) => setDepartment(e.target.value)} sx={fs.input} />
                            </FormControl>
                            <FormControl fullWidth>
                                <Typography sx={fs.label}>Parent Department</Typography>
                                <Select size="small" value={parentDepartmentId}
                                    onChange={(e) => setParentDepartmentId(e.target.value)}
                                    displayEmpty sx={fs.input} MenuProps={fs.menuProps}>
                                    <MenuItem value=""><em style={{ color: 'inherit', opacity: 0.5 }}>-- None --</em></MenuItem>
                                    {loading
                                        ? <MenuItem disabled><CircularProgress size={16} /></MenuItem>
                                        : parentOptions.map(o => <MenuItem key={o.id} value={o.id}>{o.departmentName}</MenuItem>)
                                    }
                                </Select>
                            </FormControl>
                        </Stack>
                    </Stack>
                </Box>
            </Box>

            {/* Footer */}
            <Box sx={fs.footer}>
                <Stack direction="row" spacing={2} alignItems="center">
                    <Button variant="contained" startIcon={saving ? null : <Check size={16} />}
                        onClick={handleSave} disabled={saving} sx={fs.saveBtn}>
                        {saving ? <CircularProgress size={18} color="inherit" /> : 'Save'}
                    </Button>
                    <Button onClick={onClose} sx={fs.cancelBtn}>Cancel</Button>
                </Stack>
            </Box>
        </Drawer>
    );
}
