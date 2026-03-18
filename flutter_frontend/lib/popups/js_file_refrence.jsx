import React, { useState, useEffect } from 'react';
import {
    Dialog, DialogTitle, DialogContent, DialogActions,
    TextField, MenuItem, Button, Stack, Typography,
    IconButton, Box, CircularProgress, Collapse, Tooltip, Avatar,
} from '@mui/material';
import { X, UserPlus, Plus, Check, Building2, Upload } from 'lucide-react';
import { createUser, fetchRoles, fetchOrganizations, createOrganization, fetchUsers } from '../../utils/api';
import config from '../../config';
import { getCurrentUser } from '../../utils/auth';
import toast from 'react-hot-toast';
import { useFormStyles } from '../../styles/formStyles';

// Design tokens are derived from the shared useFormStyles hook inside each component.
const labelSx = { fontSize: '12px', color: 'text.secondary', fontWeight: 500, mb: 0.75 };

const EMPTY_FORM = { name: '', email: '', password: '', roleName: 'User', organizationId: '' };
const EMPTY_ORG = { name: '', email: '', phone: '', address: '', logo: null };

/* ── Inline "Add new organisation" panel ────────────────────────────────── */
function AddOrgPanel({ onSaved, onCancel }) {
    const fs = useFormStyles();
    const [form, setForm] = useState(EMPTY_ORG);
    const [errors, setErrors] = useState({});
    const [saving, setSaving] = useState(false);

    const validate = () => {
        let newErrors = {};
        if (!form.name.trim()) newErrors.name = 'Organisation name is required';
        if (form.email == null || form.email == undefined || form.email == '') {
            newErrors.email = 'Organisation email is required';
        }
        else if (form.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
            newErrors.email = 'Invalid email format';
        }
        if (form.phone == null || form.phone == undefined || form.phone == '') {
            newErrors.phone = 'Phone number is required';
        }
        else if (form.phone && !/^\+?[\d\s-]{10,}$/.test(form.phone)) {
            newErrors.phone = 'Invalid phone number';
        }
        if (form.address == null || form.address == undefined || form.address == '') {
            newErrors.address = 'Organisation address is required';
        }
        else if (form.address && !/^.{10,}$/.test(form.address)) {
            newErrors.address = 'Address is too short';
        }
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const change = (e) => {
        if (e.target.type === 'file') {
            const file = e.target.files[0];
            setForm(f => ({ ...f, logo: file }));
        } else {
            setForm(f => ({ ...f, [e.target.name]: e.target.value }));
        }
        if (errors[e.target.name]) {
            setErrors(prev => ({ ...prev, [e.target.name]: '' }));
        }
    };

    const save = async () => {
        if (!validate()) return;
        setSaving(true);
        try {
            const res = await createOrganization({ ...form, name: form.name.trim() });
            toast.success(`"${res.name}" created!`);
            onSaved({ id: res.id, name: res.name });
        } catch (err) {
            const msg = err.response?.data?.message ?? 'Failed to create organisation';
            toast.error(msg);
        } finally {
            setSaving(false);
        }
    };

    return (
        <Box sx={{
            mt: 1, p: 2, borderRadius: 1.5,
            border: '1px solid', borderColor: 'divider',
            bgcolor: 'action.hover',
        }}>
            <Typography sx={{ fontSize: '12px', color: '#94a3b8', fontWeight: 600, mb: 1.5, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                New Organisation
            </Typography>
            <Stack spacing={1.5}>
                <Box>
                    <TextField size="small" label="Name *" name="name"
                        value={form.name} onChange={change} fullWidth sx={fs.input}
                        error={!!errors.name} />
                    {errors.name && <Typography sx={{ color: '#ef4444', fontSize: '11px', mt: 0.5 }}>{errors.name}</Typography>}
                </Box>

                <Stack direction="row" spacing={1.5}>
                    <Box flex={1}>
                        <TextField size="small" label="Email" name="email"
                            value={form.email} onChange={change} fullWidth sx={fs.input}
                            error={!!errors.email} />
                        {errors.email && <Typography sx={{ color: '#ef4444', fontSize: '11px', mt: 0.5 }}>{errors.email}</Typography>}
                    </Box>
                    <Box flex={1}>
                        <TextField size="small" label="Phone" name="phone"
                            value={form.phone} onChange={change} fullWidth sx={fs.input}
                            error={!!errors.phone} />
                        {errors.phone && <Typography sx={{ color: '#ef4444', fontSize: '11px', mt: 0.5 }}>{errors.phone}</Typography>}
                    </Box>
                </Stack>

                {/* Logo Upload Section */}
                <Box sx={{
                    p: 1.5, border: '1px dashed', borderColor: 'divider', borderRadius: 1.5,
                    bgcolor: 'background.paper', display: 'flex', alignItems: 'center', gap: 2
                }}>
                    <Box sx={{
                        width: 48, height: 48, borderRadius: 1.5, bgcolor: 'action.hover',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        overflow: 'hidden', border: '1px solid', borderColor: 'divider', flexShrink: 0
                    }}>
                        {form.logo ? (
                            <img src={URL.createObjectURL(form.logo)} alt="Logo Preview" style={{ width: '100%', height: '100%', objectFit: 'contain' }} />
                        ) : (
                            <Building2 size={24} color="#94a3b8" />
                        )}
                    </Box>
                    <Box flex={1}>
                        <Typography sx={{ fontSize: '12px', fontWeight: 600, color: 'text.primary', mb: 0.5 }}>
                            Organisation Logo <span style={{ fontSize: '10px', color: '#94a3b8', fontWeight: 400 }}>(Optional)</span>
                        </Typography>
                        <Button component="label" size="small" startIcon={<Upload size={14} />}
                            sx={{ textTransform: 'none', fontSize: '12px', p: '2px 8px' }}>
                            {form.logo ? 'Change Logo' : 'Choose File'}
                            <input type="file" hidden accept="image/*" onChange={change} name="logo" />
                        </Button>
                        {form.logo && (
                            <Typography sx={{ fontSize: '10px', color: 'primary.main', mt: 0.5, display: 'block' }}>
                                {form.logo.name}
                            </Typography>
                        )}
                    </Box>
                </Box>
                <TextField size="small" label="Address" name="address"
                    value={form.address} onChange={change} fullWidth sx={fs.input}
                    error={!!errors.address} />
                {errors.address && <Typography sx={{ color: '#ef4444', fontSize: '11px', mt: 0.5 }}>{errors.address}</Typography>}
                <Stack direction="row" spacing={1} justifyContent="flex-end">
                    <Button size="small" onClick={onCancel} disabled={saving}
                        sx={{ color: 'text.secondary', textTransform: 'none', fontSize: '13px', '&:hover': { bgcolor: 'action.hover' } }}>
                        Cancel
                    </Button>
                    <Button size="small" variant="outlined" onClick={save} disabled={saving}
                        startIcon={saving ? <CircularProgress size={12} /> : <Check size={14} />}
                        sx={{ textTransform: 'none', fontSize: '13px', fontWeight: 600 }}>
                        {saving ? 'Saving…' : 'Save'}
                    </Button>
                </Stack>
            </Stack >
        </Box >
    );
}

/* ── Main modal ─────────────────────────────────────────────────────────── */
const EMPTY = { name: '', email: '', password: '', roleName: 'User', organizationId: '' };

export default function CreateUserModal({ open, onClose, onCreated }) {
    const fs = useFormStyles();
    const [form, setForm] = useState(EMPTY);
    const [roles, setRoles] = useState([]);
    const [orgs, setOrgs] = useState([]);
    const [errors, setErrors] = useState({});
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [addingOrg, setAddingOrg] = useState(false);

    // Current logged-in user — determines which roles are available in the dropdown
    const me = getCurrentUser();

    /**
     * Role visibility rules:
     *   SuperAdmin → can create any role (SuperAdmin, Admin, User)
     *   Admin      → can only create User accounts
     */
    const filterRoles = (allRoles) => {
        if (me?.role === 'SuperAdmin') return allRoles;
        // Admin or anything else: only User role
        return allRoles.filter(r => r.roleName === 'User');
    };

    useEffect(() => {
        if (!open) return;
        setForm(EMPTY);
        setErrors({});
        setAddingOrg(false);

        const load = async () => {
            setLoading(true);
            try {
                const [r, o] = await Promise.all([fetchRoles(), fetchOrganizations()]);
                const allowed = filterRoles(r);
                setRoles(allowed);
                setOrgs(o);
                if (allowed.length > 0) setForm(f => ({ ...f, roleName: allowed[0].roleName }));
                if (o.length > 0) setForm(f => ({ ...f, organizationId: o[0].id }));
            } catch {
                toast.error('Failed to load form data');
            } finally {
                setLoading(false);
            }
        };

        load();
    }, [open]);

    const handleChange = (e) => {
        setForm(f => ({ ...f, [e.target.name]: e.target.value }));
        if (errors[e.target.name]) {
            setErrors(prev => ({ ...prev, [e.target.name]: '' }));
        }
    };

    const handleOrgCreated = (newOrg) => {
        setOrgs(prev => [...prev, newOrg]);
        setForm(f => ({ ...f, organizationId: newOrg.id }));
        setAddingOrg(false);
    };

    const validate = () => {
        let newErrors = {};
        if (!form.name.trim()) newErrors.name = 'Name is required';
        if (!form.email.trim()) {
            newErrors.email = 'Email is required';
        } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
            newErrors.email = 'Invalid email format';
        }
        if (!form.password) {
            newErrors.password = 'Password is required';
        } else if (form.password.length < 6) {
            newErrors.password = 'Must be at least 6 characters';
        }
        if (!form.organizationId) newErrors.organizationId = 'Please select an organization';

        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSave = async () => {
        if (!validate()) return;

        const id = toast.loading('Creating user…');
        setSaving(true);
        try {
            await createUser({
                name: form.name.trim(),
                email: form.email.trim(),
                password: form.password,
                roleName: form.roleName,
                organizationId: Number(form.organizationId),
            });
            toast.success(`User "${form.name}" created!`, { id });
            onCreated();
        } catch (err) {
            toast.error(err.response?.data?.message ?? 'Failed to create user', { id });
        } finally {
            setSaving(false);
        }
    };

    return (
        <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth
            PaperProps={{ sx: { bgcolor: 'background.paper', border: '1px solid', borderColor: 'divider', borderRadius: 2, backgroundImage: 'none' } }}>

            {/* ── Header ── */}
            <DialogTitle sx={{ p: 0 }}>
                <Stack direction="row" justifyContent="space-between" alignItems="center"
                    sx={{ px: 3, pt: 2.5, pb: 2, borderBottom: '1px solid', borderColor: 'divider' }}>
                    <Stack direction="row" spacing={1.5} alignItems="center">
                        <UserPlus size={18} color="#3182ce" />
                        <Box>
                            <Typography sx={{ fontWeight: 600, color: 'text.primary', fontSize: '15px', lineHeight: 1.2 }}>
                                Create New User
                            </Typography>
                            <Typography sx={{ fontSize: '12px', color: 'text.secondary' }}>
                                Fill in details and assign organisation access
                            </Typography>
                        </Box>
                    </Stack>
                    <IconButton onClick={onClose} size="small"
                        sx={{ color: 'text.secondary', '&:hover': { color: 'text.primary', bgcolor: 'action.hover' } }}>
                        <X size={16} />
                    </IconButton>
                </Stack>
            </DialogTitle>

            {/* ── Body ── */}
            <DialogContent sx={{ px: 3, pt: 2.5, pb: 1 }}>
                {loading ? (
                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
                        <CircularProgress size={28} sx={{ color: '#3182ce' }} />
                    </Box>
                ) : (
                    <Stack spacing={2}>
                        {/* Name */}
                        <Box>
                            <Typography sx={labelSx}>Full Name <span style={{ color: '#ef4444' }}>*</span></Typography>
                            <TextField size="small" name="name" value={form.name}
                                onChange={handleChange} fullWidth placeholder="e.g. John Smith"
                                sx={fs.input} error={!!errors.name} />
                            {errors.name && <Typography sx={{ color: '#ef4444', fontSize: '11px', mt: 0.5 }}>{errors.name}</Typography>}
                        </Box>

                        {/* Email */}
                        <Box>
                            <Typography sx={labelSx}>Email Address <span style={{ color: '#ef4444' }}>*</span></Typography>
                            <TextField size="small" name="email" type="email" value={form.email}
                                onChange={handleChange} fullWidth placeholder="john@company.com"
                                sx={fs.input} error={!!errors.email} />
                            {errors.email && <Typography sx={{ color: '#ef4444', fontSize: '11px', mt: 0.5 }}>{errors.email}</Typography>}
                        </Box>

                        {/* Password */}
                        <Box>
                            <Typography sx={labelSx}>Password <span style={{ color: '#ef4444' }}>*</span></Typography>
                            <TextField size="small" name="password" type="password" value={form.password}
                                onChange={handleChange} fullWidth placeholder="Min. 6 characters"
                                sx={fs.input} error={!!errors.password} />
                            {errors.password && <Typography sx={{ color: '#ef4444', fontSize: '11px', mt: 0.5 }}>{errors.password}</Typography>}
                        </Box>

                        {/* Role + Org in a row */}
                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                            {/* Role */}
                            <Box flex={1}>
                                <Typography sx={labelSx}>Role</Typography>
                                <TextField select size="small" name="roleName" value={form.roleName}
                                    onChange={handleChange} fullWidth sx={fs.input}
                                    SelectProps={{ MenuProps: fs.menuProps }}>
                                    {roles.map(r => (
                                        <MenuItem key={r.roleID} value={r.roleName}>{r.roleName}</MenuItem>
                                    ))}
                                </TextField>
                            </Box>

                            {/* Organisation */}
                            <Box flex={1}>
                                <Typography sx={labelSx}>Organisation <span style={{ color: '#ef4444' }}>*</span></Typography>
                                <Stack direction="row" spacing={0.75} alignItems="center">
                                    <TextField select size="small" name="organizationId" value={form.organizationId}
                                        onChange={handleChange} fullWidth sx={fs.input}
                                        error={!!errors.organizationId}
                                        SelectProps={{ MenuProps: fs.menuProps }}>
                                        {orgs.map(o => (
                                            <MenuItem key={o.id} value={o.id}>
                                                <Stack direction="row" spacing={1.5} alignItems="center">
                                                    <Avatar
                                                        src={o.logoUrl ? `${config.SOCKET_URL}${o.logoUrl}` : ''}
                                                        variant="rounded"
                                                        sx={{ width: 22, height: 22, bgcolor: 'action.selected', color: 'text.secondary', fontSize: '10px' }}
                                                    >
                                                        <Building2 size={12} />
                                                    </Avatar>
                                                    <Typography sx={{ fontSize: '13px' }}>{o.name}</Typography>
                                                </Stack>
                                            </MenuItem>
                                        ))}
                                    </TextField>
                                    {/* Only SuperAdmin can create new organisations */}
                                    {me?.role === 'SuperAdmin' && (
                                        <Tooltip title="Add new organisation" arrow>
                                            <IconButton size="small"
                                                onClick={() => setAddingOrg(v => !v)}
                                                sx={{
                                                    border: `1px solid ${addingOrg ? 'primary.main' : (errors.organizationId ? '#ef4444' : 'divider')}`,
                                                    borderRadius: 1, color: errors.organizationId ? '#ef4444' : 'text.secondary', p: '7px',
                                                    bgcolor: addingOrg ? 'action.selected' : 'transparent',
                                                    '&:hover': { color: 'text.primary', bgcolor: 'action.hover' },
                                                    flexShrink: 0,
                                                }}>
                                                <Plus size={16} />
                                            </IconButton>
                                        </Tooltip>
                                    )}
                                </Stack>
                                {errors.organizationId && <Typography sx={{ color: '#ef4444', fontSize: '11px', mt: 0.5 }}>{errors.organizationId}</Typography>}
                            </Box>
                        </Stack>

                        {/* Inline Add Organisation Panel */}
                        <Collapse in={addingOrg} unmountOnExit>
                            <AddOrgPanel
                                onSaved={handleOrgCreated}
                                onCancel={() => setAddingOrg(false)}
                            />
                        </Collapse>
                    </Stack>
                )}
            </DialogContent>

            {/* ── Footer ── */}
            <DialogActions sx={{ px: 3, py: 2.5, gap: 1, borderTop: '1px solid', borderColor: 'divider' }}>
                <Button onClick={onClose} disabled={saving}
                    sx={{ color: 'text.secondary', textTransform: 'none', fontWeight: 500, px: 2, '&:hover': { bgcolor: 'action.hover' } }}>
                    Cancel
                </Button>
                <Button variant="contained" onClick={handleSave}
                    disabled={saving || loading}
                    startIcon={saving ? <CircularProgress size={13} /> : <UserPlus size={15} />}
                    sx={{ textTransform: 'none', fontWeight: 600, px: 3, borderRadius: 1.5 }}>
                    {saving ? 'Creating…' : 'Create User'}
                </Button>
            </DialogActions>
        </Dialog>
    );
}
