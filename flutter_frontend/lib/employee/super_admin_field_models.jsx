import React, { useState, useEffect } from 'react';
import {
    Dialog, DialogTitle, DialogContent, DialogActions,
    Button, Typography, Box, Stack, TextField, Select, MenuItem,
    FormControl, InputLabel, IconButton, CircularProgress, Paper,
    Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
    Divider, Chip
} from '@mui/material';
import { X, Plus, Trash2, Database, AlertTriangle } from 'lucide-react';
import { fetchEmployeeFields, createMasterField, deleteMasterField } from '../../utils/api';
import toast from 'react-hot-toast';

const SECTION_OPTIONS = [
    'Personal Information',
    'Bank Account Details',
    'Contact Info',
    'Exit Details & Remarks',
    'General',
];

const COMPONENT_TYPES = [
    { value: 'text', label: 'Text' },
    { value: 'number', label: 'Number' },
    { value: 'date', label: 'Date' },
    { value: 'select', label: 'Dropdown (Select)' },
    { value: 'radio', label: 'Radio Buttons' },
    { value: 'textarea', label: 'Text Area' },
    { value: 'email', label: 'Email' },
];

const emptyForm = {
    fieldKey: '',
    displayLabel: '',
    sectionName: 'General',
    sectionOrder: 99,
    fieldOrder: 99,
    gridSize: 6,
    componentType: 'text',
    optionsJson: '',
};

const SuperAdminFieldsModal = ({ open, onClose }) => {
    const [allFields, setAllFields] = useState([]);
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [deleting, setDeleting] = useState(null);
    const [form, setForm] = useState(emptyForm);
    const [confirmDeleteId, setConfirmDeleteId] = useState(null);

    useEffect(() => {
        if (open) loadFields();
    }, [open]);

    const loadFields = async () => {
        setLoading(true);
        try {
            const data = await fetchEmployeeFields(null);
            setAllFields(data || []);
        } catch {
            toast.error('Failed to load fields');
        } finally {
            setLoading(false);
        }
    };

    const handleCreate = async () => {
        if (!form.fieldKey.trim() || !form.displayLabel.trim()) {
            toast.error('Field Key and Label are required');
            return;
        }
        // Validate field key format (no spaces)
        if (/\s/.test(form.fieldKey)) {
            toast.error('Field Key must not contain spaces');
            return;
        }

        setSaving(true);
        try {
            await createMasterField({
                FieldKey: form.fieldKey.trim(),
                DisplayLabel: form.displayLabel.trim(),
                SectionName: form.sectionName,
                SectionOrder: parseInt(form.sectionOrder) || 99,
                FieldOrder: parseInt(form.fieldOrder) || 99,
                GridSize: parseInt(form.gridSize) || 6,
                ComponentType: form.componentType,
                OptionsJson: form.optionsJson.trim() || null,
            });
            toast.success('Field created and added to all organizations!');
            setForm(emptyForm);
            loadFields();
        } catch (err) {
            toast.error(err?.response?.data?.message || 'Failed to create field');
        } finally {
            setSaving(false);
        }
    };

    const handleDelete = async (id) => {
        setDeleting(id);
        try {
            await deleteMasterField(id);
            toast.success('Field deleted');
            setConfirmDeleteId(null);
            loadFields();
        } catch (err) {
            toast.error(err?.response?.data?.message || 'Failed to delete field');
        } finally {
            setDeleting(null);
        }
    };

    const inputSx = {
        '& .MuiOutlinedInput-root': { borderRadius: '10px' },
        '& .MuiInputBase-input': { fontSize: '13px' }
    };

    return (
        <Dialog open={open} onClose={onClose} maxWidth="lg" fullWidth disableScrollLock PaperProps={{
            sx: { bgcolor: 'background.paper', borderRadius: 2, border: '1px solid', borderColor: 'divider', height: '90vh', display: 'flex', flexDirection: 'column' }
        }}>
            <DialogTitle sx={{ p: 2, borderBottom: '1px solid', borderColor: 'divider', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Stack direction="row" spacing={1.5} alignItems="center">
                    <Box sx={{ p: 1, borderRadius: '10px', bgcolor: 'rgba(239,68,68,0.1)', color: '#ef4444', display: 'flex' }}>
                        <Database size={18} />
                    </Box>
                    <Box>
                        <Typography sx={{ fontWeight: 700, fontSize: '16px' }}>Manage Master Fields</Typography>
                        <Typography sx={{ fontSize: '12px', color: 'text.secondary' }}>SuperAdmin — changes apply to all organizations</Typography>
                    </Box>
                </Stack>
                <IconButton onClick={onClose} size="small" sx={{ color: 'text.secondary' }}>
                    <X size={18} />
                </IconButton>
            </DialogTitle>

            <DialogContent sx={{ p: 0, display: 'flex', flexDirection: { xs: 'column', md: 'row' }, overflow: 'hidden' }}>
                {/* Create new field panel */}
                <Box sx={{ width: { xs: '100%', md: '360px' }, borderRight: { md: '1px solid' }, borderColor: 'divider', p: 2.5, overflowY: 'auto', flexShrink: 0 }}>
                    <Typography sx={{ fontWeight: 600, fontSize: '14px', mb: 2, color: 'primary.main' }}>
                        <Plus size={14} style={{ marginRight: 6, verticalAlign: 'middle' }} />
                        Add New Field
                    </Typography>

                    <Stack spacing={2}>
                        <TextField label="Field Key (camelCase, no spaces)" placeholder="e.g. bloodGroup" value={form.fieldKey}
                            onChange={e => setForm(p => ({ ...p, fieldKey: e.target.value.replace(/\s/g, '') }))}
                            size="small" fullWidth sx={inputSx} />
                        <TextField label="Display Label" placeholder="e.g. Blood Group" value={form.displayLabel}
                            onChange={e => setForm(p => ({ ...p, displayLabel: e.target.value }))}
                            size="small" fullWidth sx={inputSx} />

                        <FormControl size="small" fullWidth>
                            <InputLabel>Section</InputLabel>
                            <Select value={form.sectionName} onChange={e => setForm(p => ({ ...p, sectionName: e.target.value }))} label="Section"
                                sx={{ borderRadius: '10px', fontSize: '13px' }}>
                                {SECTION_OPTIONS.map(s => <MenuItem key={s} value={s}>{s}</MenuItem>)}
                            </Select>
                        </FormControl>

                        <FormControl size="small" fullWidth>
                            <InputLabel>Component Type</InputLabel>
                            <Select value={form.componentType} onChange={e => setForm(p => ({ ...p, componentType: e.target.value }))} label="Component Type"
                                sx={{ borderRadius: '10px', fontSize: '13px' }}>
                                {COMPONENT_TYPES.map(t => <MenuItem key={t.value} value={t.value}>{t.label}</MenuItem>)}
                            </Select>
                        </FormControl>

                        <Stack direction="row" spacing={1.5}>
                            <TextField label="Section Order" type="number" value={form.sectionOrder}
                                onChange={e => setForm(p => ({ ...p, sectionOrder: e.target.value }))}
                                size="small" sx={inputSx} inputProps={{ min: 1 }} />
                            <TextField label="Field Order" type="number" value={form.fieldOrder}
                                onChange={e => setForm(p => ({ ...p, fieldOrder: e.target.value }))}
                                size="small" sx={inputSx} inputProps={{ min: 1 }} />
                            <TextField label="Width (1-12)" type="number" value={form.gridSize}
                                onChange={e => setForm(p => ({ ...p, gridSize: e.target.value }))}
                                size="small" sx={inputSx} inputProps={{ min: 1, max: 12 }} />
                        </Stack>

                        {['select', 'radio'].includes(form.componentType) && (
                            <TextField
                                label="Options JSON"
                                placeholder='[{"label":"Option 1","value":"opt1"}]'
                                value={form.optionsJson}
                                onChange={e => setForm(p => ({ ...p, optionsJson: e.target.value }))}
                                size="small" fullWidth multiline rows={3} sx={inputSx}
                                helperText="Required for select/radio fields"
                            />
                        )}

                        <Button fullWidth variant="contained" onClick={handleCreate} disabled={saving}
                            startIcon={saving ? <CircularProgress size={14} color="inherit" /> : <Plus size={15} />}
                            sx={{ textTransform: 'none', borderRadius: '10px', fontWeight: 600 }}>
                            {saving ? 'Creating...' : 'Create Field'}
                        </Button>
                    </Stack>
                </Box>

                {/* Existing fields list */}
                <Box sx={{ flex: 1, overflowY: 'auto', p: 2 }}>
                    <Typography sx={{ fontWeight: 600, fontSize: '14px', mb: 1.5, color: 'text.primary' }}>
                        All Master Fields ({allFields.length})
                    </Typography>

                    {loading ? (
                        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}><CircularProgress size={24} /></Box>
                    ) : (
                        <TableContainer component={Paper} variant="outlined" sx={{ borderRadius: 2 }}>
                            <Table size="small">
                                <TableHead sx={{ bgcolor: 'action.hover' }}>
                                    <TableRow>
                                        <TableCell sx={{ fontWeight: 700, fontSize: '11px', color: 'text.secondary', textTransform: 'uppercase' }}>Field Key</TableCell>
                                        <TableCell sx={{ fontWeight: 700, fontSize: '11px', color: 'text.secondary', textTransform: 'uppercase' }}>Label</TableCell>
                                        <TableCell sx={{ fontWeight: 700, fontSize: '11px', color: 'text.secondary', textTransform: 'uppercase' }}>Section</TableCell>
                                        <TableCell sx={{ fontWeight: 700, fontSize: '11px', color: 'text.secondary', textTransform: 'uppercase' }}>Type</TableCell>
                                        <TableCell sx={{ fontWeight: 700, fontSize: '11px', color: 'text.secondary', textTransform: 'uppercase' }}>Core</TableCell>
                                        <TableCell align="right" sx={{ fontWeight: 700, fontSize: '11px', color: 'text.secondary', textTransform: 'uppercase' }}>Action</TableCell>
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {allFields.map(field => (
                                        <TableRow key={field.id} sx={{ '&:hover': { bgcolor: 'action.hover' } }}>
                                            <TableCell sx={{ fontSize: '12px', fontFamily: 'monospace', color: 'primary.main' }}>{field.field_key}</TableCell>
                                            <TableCell sx={{ fontSize: '12px' }}>{field.CustomLabel || field.display_label}</TableCell>
                                            <TableCell sx={{ fontSize: '11px', color: 'text.secondary' }}>{field.section_name}</TableCell>
                                            <TableCell sx={{ fontSize: '11px' }}>
                                                <Chip label={field.component_type} size="small" sx={{ fontSize: '10px', height: 20 }} />
                                            </TableCell>
                                            <TableCell>
                                                {field.IsCoreField === 1
                                                    ? <Chip label="Core" size="small" color="primary" sx={{ fontSize: '10px', height: 20 }} />
                                                    : <Chip label="Custom" size="small" sx={{ fontSize: '10px', height: 20, bgcolor: 'action.hover' }} />}
                                            </TableCell>
                                            <TableCell align="right">
                                                {confirmDeleteId === field.id ? (
                                                    <Stack direction="row" spacing={0.5} justifyContent="flex-end">
                                                        <Button size="small" variant="contained" color="error" onClick={() => handleDelete(field.id)}
                                                            disabled={deleting === field.id} sx={{ textTransform: 'none', fontSize: '11px', minWidth: 60 }}>
                                                            {deleting === field.id ? '...' : 'Confirm'}
                                                        </Button>
                                                        <Button size="small" onClick={() => setConfirmDeleteId(null)} sx={{ textTransform: 'none', fontSize: '11px' }}>
                                                            Cancel
                                                        </Button>
                                                    </Stack>
                                                ) : (
                                                    <IconButton size="small" sx={{ color: '#ef4444', '&:hover': { bgcolor: 'rgba(239,68,68,0.1)' } }}
                                                        onClick={() => setConfirmDeleteId(field.id)}>
                                                        <Trash2 size={14} />
                                                    </IconButton>
                                                )}
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    )}
                </Box>
            </DialogContent>

            <DialogActions sx={{ p: 2, borderTop: '1px solid', borderColor: 'divider' }}>
                <Button onClick={onClose} sx={{ color: 'text.secondary', textTransform: 'none' }}>Close</Button>
            </DialogActions>
        </Dialog>
    );
};

export default SuperAdminFieldsModal;
