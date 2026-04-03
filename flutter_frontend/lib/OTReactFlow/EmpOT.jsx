import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import {
    Box, Paper, Typography, Stack, Button, Table, TableBody,
    TableCell, TableContainer, TableHead, TableRow, IconButton,
    CircularProgress, InputBase, Checkbox, Menu, MenuItem, Select, Chip, Avatar,
    Drawer, TextField, Autocomplete
} from '@mui/material';
import {
    Plus, Download, Search, MoreVertical,
    ChevronLeft, ChevronRight, Trash2, ArrowUpDown, Building2, X, Clock
} from 'lucide-react';
import { 
    fetchEmpOTs, deleteEmpOT, fetchOrganizations, switchOrganization, 
    fetchEmployees, saveEmpOT, updateEmpOT 
} from '../utils/api';
import toast from 'react-hot-toast';
import { getCurrentUser } from '../utils/auth';
import * as signalR from '@microsoft/signalr';
import config from '../config';
import { useFormStyles } from '../styles/formStyles';
import CustomDatePicker from '../components/CustomDatePicker';

export default function EmpOT() {
    const fs = useFormStyles();
    const [data, setData] = useState([]);
    const [employees, setEmployees] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [page, setPage] = useState(1);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    // Drawer state
    const [drawerOpen, setDrawerOpen] = useState(false);
    const [editData, setEditData] = useState(null);
    const [saving, setSaving] = useState(false);
    const [form, setForm] = useState({
        employeeId: null,
        overDutyDate: new Date().toISOString().split('T')[0],
        hours: '',
        ratePerHour: '',
        remarks: ''
    });

    const [anchorEl, setAnchorEl] = useState(null);
    const [selectedItem, setSelectedItem] = useState(null);
    const [organizations, setOrganizations] = useState([]);
    const [selectedOrgId, setSelectedOrgId] = useState(null);

    const selectedOrg = organizations.find(o => o.id == selectedOrgId);
    const selectedOrgName = selectedOrg?.name || '';
    const [sortConfig, setSortConfig] = useState({ key: 'overDutyDate', direction: 'desc' });

    const user = getCurrentUser();
    const isAdminOrAbove = user?.role === 'Admin' || user?.role === 'SuperAdmin';
    const isSwitchingRef = useRef(false);

    const loadOrganizations = useCallback(async () => {
        try {
            const orgs = await fetchOrganizations();
            setOrganizations(orgs || []);
            const user = getCurrentUser();
            const tokenOrgId = user?.organizationId;
            if (orgs && orgs.length > 0) {
                const savedId = localStorage.getItem('last_selected_org_id');
                const matching = orgs.find(o => String(o.id) === String(savedId)) || 
                                 orgs.find(o => String(o.id) === String(tokenOrgId));
                const defaultId = matching ? matching.id : orgs[0].id;
                if (defaultId && String(defaultId) !== String(tokenOrgId)) {
                    isSwitchingRef.current = true;
                    await switchOrganization(defaultId);
                    isSwitchingRef.current = false;
                }
                setSelectedOrgId(defaultId);
            }
        } catch (error) { console.error('Load orgs failed', error); }
    }, []);

    useEffect(() => {
        loadOrganizations();
        const handleGlobalSwitch = () => {
            if (isSwitchingRef.current) return;
            loadOrganizations();
        };
        window.addEventListener('org-switched', handleGlobalSwitch);
        return () => window.removeEventListener('org-switched', handleGlobalSwitch);
    }, [loadOrganizations]);

    const load = useCallback(async (silent = false) => {
        if (!selectedOrgId) return;
        if (!silent) setLoading(true);
        try {
            const [otRes, empRes] = await Promise.all([
                fetchEmpOTs(selectedOrgId),
                fetchEmployees(selectedOrgId)
            ]);
            setData(Array.isArray(otRes) ? otRes : []);
            setEmployees(Array.isArray(empRes) ? empRes : []);
        } catch (error) {
            toast.error('Failed to load OT records');
        } finally {
            if (!silent) setLoading(false);
        }
    }, [selectedOrgId]);

    useEffect(() => { if (selectedOrgId) load(); }, [selectedOrgId, load]);

    useEffect(() => {
        if (!selectedOrgId) return;
        const connection = new signalR.HubConnectionBuilder()
            .withUrl(`${config.SOCKET_URL}/hubs/empot`)
            .withAutomaticReconnect()
            .build();
        const start = async () => {
            try {
                await connection.start();
                await connection.invoke('JoinOrganization', selectedOrgId);
                connection.on('ReceiveOTUpdate', () => load(true));
            } catch (err) { console.error('SignalR Error:', err); }
        };
        start();
        return () => { if (connection.state === signalR.HubConnectionState.Connected) connection.stop(); };
    }, [selectedOrgId, load]);

    const enrichedData = useMemo(() => data.map(ot => {
        const emp = employees.find(e => e.id === ot.employeeId);
        return {
            ...ot,
            employeeName: emp ? emp.name : (ot.employeeName || 'Unknown'),
            displayEmployeeId: emp ? (emp.organization_Employee_id || emp.employeeCode) : (ot.employeeCode || 'N/A'),
            profilePictureUrl: emp?.profilePictureUrl || emp?.ProfilePictureUrl || ot.profilePictureUrl
        };
    }), [data, employees]);

    const filteredData = useMemo(() => enrichedData
        .filter(d => {
            const q = searchTerm.toLowerCase();
            return (
                d.employeeName?.toLowerCase().includes(q) || 
                d.displayEmployeeId?.toLowerCase().includes(q) ||
                d.remarks?.toLowerCase().includes(q)
            );
        })
        .sort((a, b) => {
            const aVal = a[sortConfig.key];
            const bVal = b[sortConfig.key];
            if (aVal < bVal) return sortConfig.direction === 'asc' ? -1 : 1;
            if (aVal > bVal) return sortConfig.direction === 'asc' ? 1 : -1;
            return 0;
        }), [enrichedData, searchTerm, sortConfig]);

    const paginatedData = filteredData.slice((page - 1) * rowsPerPage, page * rowsPerPage);

    const openDrawer = (item = null) => {
        setEditData(item);
        if (item) {
            setForm({
                employeeId: item.employeeId,
                overDutyDate: item.overDutyDate.split('T')[0],
                hours: item.hours || '',
                ratePerHour: item.ratePerHour || '',
                remarks: item.remarks || ''
            });
        } else {
            setForm({
                employeeId: null,
                overDutyDate: new Date().toISOString().split('T')[0],
                hours: '',
                ratePerHour: '',
                remarks: ''
            });
        }
        setDrawerOpen(true);
        handleMenuClose();
    };

    const closeDrawer = () => {
        if (saving) return;
        setDrawerOpen(false);
        setEditData(null);
    };

    const handleSave = async (e) => {
        e.preventDefault();
        setSaving(true);
        try {
            const payload = {
                ...form,
                organizationId: selectedOrgId,
                amount: (Number(form.hours) || 0) * (Number(form.ratePerHour) || 0)
            };
            if (editData) {
                await updateEmpOT({ ...payload, overDutyId: editData.overDutyId });
                toast.success('OT record updated');
            } else {
                await saveEmpOT(payload);
                toast.success('OT record saved');
            }
            closeDrawer();
            load(true);
        } catch { toast.error('Failed to save'); }
        finally { setSaving(false); }
    };

    const handleDeleteClick = async (id) => {
        if (!window.confirm('Delete this record?')) return;
        try {
            await deleteEmpOT(id, selectedOrgId);
            toast.success('Record deleted');
            load(true);
        } catch { toast.error('Delete failed'); }
        handleMenuClose();
    };

    const handleOrgChange = async (e) => {
        const id = e.target.value;
        if (id == selectedOrgId) return;
        const name = organizations.find(o => o.id == id)?.name || 'Organization';
        try {
            const t = toast.loading(`Switching to ${name}...`);
            isSwitchingRef.current = true;
            await switchOrganization(id);
            isSwitchingRef.current = false;
            setSelectedOrgId(id);
            toast.success(`Switched to ${name}`, { id: t });
        } catch {
            isSwitchingRef.current = false;
            toast.error('Failed switch');
        }
    };

    const handleSort = (k) => setSortConfig(p => ({ key: k, direction: p.key === k && p.direction === 'asc' ? 'desc' : 'asc' }));
    const SortIcon = ({ columnKey }) => {
        const active = sortConfig.key === columnKey;
        return <ArrowUpDown size={12} style={{ marginLeft: 6, opacity: active ? 1 : 0.5, color: active ? 'white' : 'inherit' }} />;
    };
    const handleMenuOpen = (e, i) => { setAnchorEl(e.currentTarget); setSelectedItem(i); };
    const handleMenuClose = () => { setAnchorEl(null); setSelectedItem(null); };

    const selectedEmployee = employees.find(e => e.id === form.employeeId) || null;

    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>

            {/* ── Filter Bar ── */}
            <Box sx={{ display: 'flex', flexDirection: { xs: 'column', md: 'row' }, gap: 1.5, bgcolor: 'background.paper', p: 1.5, borderRadius: 2, border: '1px solid', borderColor: 'divider', alignItems: 'center' }}>
                <Stack direction="row" spacing={1} alignItems="center" sx={{ borderRight: { md: '1px solid' }, borderColor: 'divider', pr: 2 }}>
                    <Building2 size={14} color="#94a3b8" />
                    <Select value={selectedOrgId || ''} onChange={handleOrgChange} size="small" disableUnderline sx={{ height: 32, fontSize: '13px', minWidth: 100, '& fieldset': { border: 'none' } }}>
                        {organizations.map(org => <MenuItem key={org.id} value={org.id}>{org.name}</MenuItem>)}
                    </Select>
                </Stack>
                <Box sx={{ flex: 1, display: 'flex', alignItems: 'center', bgcolor: 'action.hover', px: 1.5, borderRadius: 1.5, height: 32 }}>
                    <Search size={16} color="#64748b" />
                    <InputBase placeholder="Search employee name, ID or remarks..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} sx={{ ml: 1, fontSize: '13px', width: '100%' }} />
                </Box>
            </Box>

            {/* ── Toolbar ── */}
            <Stack direction="row" justifyContent="space-between">
                <Typography variant="h6" sx={{ fontWeight: 800, fontSize: '18px' }}>Emp OT Management</Typography>
                <Button variant="contained" startIcon={<Plus size={18} />} onClick={() => openDrawer()} sx={{ textTransform: 'none', borderRadius: 1.5, bgcolor: '#3182ce' }}>Add OT Entry</Button>
            </Stack>

            {/* ── Table ── */}
            <Paper elevation={0} sx={{ border: '1px solid', borderColor: 'divider', borderRadius: 2, overflow: 'hidden' }}>
                <TableContainer>
                    <Table>
                        <TableHead>
                            <TableRow sx={{ bgcolor: 'action.hover' }}>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase' }} onClick={() => handleSort('displayEmployeeId')}><Stack direction="row" alignItems="center">Emp ID <SortIcon columnKey="displayEmployeeId" /></Stack></TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase' }} onClick={() => handleSort('employeeName')}><Stack direction="row" alignItems="center">Name <SortIcon columnKey="employeeName" /></Stack></TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase' }} onClick={() => handleSort('overDutyDate')}><Stack direction="row" alignItems="center">Date <SortIcon columnKey="overDutyDate" /></Stack></TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase' }}>Hours</TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase' }}>Amount</TableCell>
                                {isAdminOrAbove && <TableCell align="right" sx={{ color: 'text.secondary', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase' }}>Action</TableCell>}
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? <TableRow><TableCell colSpan={6} align="center" sx={{ py: 6 }}><CircularProgress size={24} /></TableCell></TableRow> :
                                paginatedData.map((d, i) => (
                                    <TableRow key={d.overDutyId || i} sx={{ '&:hover': { bgcolor: 'action.hover' } }}>
                                        <TableCell sx={{ fontSize: '13px', fontWeight: 700, color: 'text.secondary' }}>{d.displayEmployeeId}</TableCell>
                                        <TableCell>
                                            <Stack direction="row" spacing={1.5} alignItems="center">
                                                <Avatar src={config.getMediaUrl(d.profilePictureUrl)} sx={{ width: 28, height: 28 }}>{d.employeeName?.charAt(0)}</Avatar>
                                                <Typography sx={{ fontSize: '12.5px', fontWeight: 700 }}>{d.employeeName}</Typography>
                                            </Stack>
                                        </TableCell>
                                        <TableCell sx={{ fontSize: '13px' }}>{new Date(d.overDutyDate).toLocaleDateString()}</TableCell>
                                        <TableCell sx={{ fontSize: '13px', fontWeight: 800 }}>{d.hours}</TableCell>
                                        <TableCell sx={{ fontSize: '13px', fontWeight: 800, color: '#0d9488' }}>₹{Number(d.amount).toLocaleString()}</TableCell>
                                        {isAdminOrAbove && <TableCell align="right"><IconButton size="small" onClick={(e) => handleOpenMenu(e, d)}><MoreVertical size={16} /></IconButton></TableCell>}
                                    </TableRow>
                                ))
                            }
                        </TableBody>
                    </Table>
                </TableContainer>
                <Box sx={{ p: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center', bgcolor: 'action.hover', borderTop: '1px solid', borderColor: 'divider' }}>
                    <Typography sx={{ fontSize: '13px', color: 'text.secondary' }}>Showing {filteredData.length} records</Typography>
                    <Stack direction="row" spacing={1}>
                        <IconButton disabled={page === 1} onClick={() => setPage(p => p - 1)} size="small" sx={{ bgcolor: 'action.hover' }}><ChevronLeft size={16} /></IconButton>
                        <Box sx={{ width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center', bgcolor: 'primary.main', color: '#fff', borderRadius: 1.5, fontSize: '13px', fontWeight: 800 }}>{page}</Box>
                        <IconButton disabled={page * rowsPerPage >= filteredData.length} onClick={() => setPage(p => p + 1)} size="small" sx={{ bgcolor: 'action.hover' }}><ChevronRight size={16} /></IconButton>
                    </Stack>
                </Box>
            </Paper>

            <Menu anchorEl={anchorEl} open={Boolean(anchorEl)} onClose={handleMenuClose} PaperProps={{ sx: { border: '1px solid', borderColor: 'divider', boxShadow: '0 8px 24px rgba(0,0,0,0.1)' } }}>
                <MenuItem onClick={() => openDrawer(selectedItem)}>Edit Entry</MenuItem>
                <MenuItem onClick={() => handleDeleteClick(selectedItem?.overDutyId)} sx={{ color: 'error.main' }}>Delete Entry</MenuItem>
            </Menu>

            <Drawer anchor="right" open={drawerOpen} onClose={closeDrawer} sx={fs.drawer} PaperProps={{ sx: fs.drawerPaper }}>
                <IconButton onClick={closeDrawer} sx={fs.closeBtn}><X size={18} /></IconButton>
                <Box sx={fs.header}>
                    <Stack direction="row" spacing={1.5} alignItems="center">
                        <Clock size={22} color="#3182ce" />
                        <Typography variant="h6" sx={{ fontWeight: 800, fontSize: '18px' }}>{editData ? 'Update OT Entry' : 'Manual OT Entry'}</Typography>
                    </Stack>
                </Box>
                <Box sx={fs.body} component="form" id="ot-form" onSubmit={handleSave}>
                    <Box sx={fs.sectionBox}>
                        <Typography sx={{ fontSize: '11px', fontWeight: 800, color: 'text.secondary', textTransform: 'uppercase', mb: 2 }}>Staff & Date</Typography>
                        <Stack spacing={2.5}>
                            <Autocomplete
                                options={employees}
                                getOptionLabel={(o) => `${o.name} (${o.organization_Employee_id || o.employeeCode})`}
                                value={selectedEmployee}
                                onChange={(_, v) => setForm({ ...form, employeeId: v ? v.id : null })}
                                disabled={!!editData}
                                sx={fs.input}
                                renderInput={(p) => <TextField {...p} required placeholder="Select Staff Member..." />}
                                renderOption={(props, option) => (
                                    <li {...props}>
                                        <Stack direction="row" spacing={1.5} alignItems="center">
                                            <Avatar src={config.getMediaUrl(option.profilePictureUrl || option.ProfilePictureUrl)} sx={{ width: 22, height: 22 }} />
                                            <Box>
                                                <Typography sx={{ fontSize: '13px', fontWeight: 600 }}>{option.name}</Typography>
                                                <Typography sx={{ fontSize: '11px', color: 'text.secondary' }}>ID: {option.organization_Employee_id || option.employeeCode}</Typography>
                                            </Box>
                                        </Stack>
                                    </li>
                                )}
                            />
                            <CustomDatePicker 
                                label="Duty Date"
                                value={form.overDutyDate}
                                onChange={(e) => setForm({ ...form, overDutyDate: e.target.value })}
                                starStyle={{ color: 'red' }}
                            />
                        </Stack>
                    </Box>
                    <Box sx={fs.sectionBox}>
                        <Typography sx={{ fontSize: '11px', fontWeight: 800, color: 'text.secondary', textTransform: 'uppercase', mb: 2 }}>Calculation Details</Typography>
                        <Stack direction="row" spacing={2.5}>
                            <TextField fullWidth type="number" label="Hours" value={form.hours} onChange={(e) => setForm({ ...form, hours: e.target.value })} sx={fs.input} />
                            <TextField fullWidth type="number" label="Rate (₹/hr)" value={form.ratePerHour} onChange={(e) => setForm({ ...form, ratePerHour: e.target.value })} sx={fs.input} />
                        </Stack>
                        <Box sx={{ mt: 2, p: 2, bgcolor: 'action.hover', borderRadius: 1.5, border: '1px solid', borderColor: 'divider', display: 'flex', justifyContent: 'space-between' }}>
                            <Typography sx={{ fontSize: '13px', fontWeight: 700 }}>Computed Amount:</Typography>
                            <Typography sx={{ fontSize: '16px', fontWeight: 800, color: 'primary.main' }}>₹{((Number(form.hours) || 0) * (Number(form.ratePerHour) || 0)).toLocaleString()}</Typography>
                        </Box>
                    </Box>
                    <TextField fullWidth multiline rows={3} label="Reason/Remarks" value={form.remarks} onChange={(e) => setForm({ ...form, remarks: e.target.value })} sx={fs.input} />
                </Box>
                <Box sx={fs.footer}>
                    <Stack direction="row" spacing={1.5} justifyContent="flex-end">
                        <Button onClick={closeDrawer} sx={fs.cancelBtn}>Cancel</Button>
                        <Button type="submit" form="ot-form" variant="contained" disabled={saving} sx={fs.saveBtn}>Save Record</Button>
                    </Stack>
                </Box>
            </Drawer>
        </Box>
    );
}
