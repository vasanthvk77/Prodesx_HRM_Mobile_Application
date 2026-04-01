import React, { useState, useEffect, useMemo, useCallback } from 'react';
import {
    Box,
    Paper,
    Typography,
    Avatar,
    IconButton,
    Tooltip,
    Button,
    Select,
    MenuItem,
    CircularProgress,
    Chip,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Menu,
    Divider,
    Stack,
    TextField,
    InputAdornment,
    Checkbox,
    Grid,
    FormControl,
    InputLabel
} from '@mui/material';
import {
    Search,
    UserCheck,
    Settings,
    CalendarDays,
    Sun,
    Sunset,
    Building2,
    Users,
    Filter,
    Download,
    Trash2,
    Palette,
    ArrowUpDown,
    MoreVertical,
    Plus,
    Edit2,
    X,
    Check,
    ChevronLeft
} from 'lucide-react';

import {
    fetchEmployees,
    fetchAttendanceByDate,
    fetchLeaveTypes,
    fetchLeaveTypeSettings,
    toggleLeaveType,
    createLeaveType,
    updateLeaveType,
    deleteLeaveType,
    bulkUpsertEmpAttendance,
    fetchOrganizations,
    switchOrganization,
    exportAttendanceRegister
} from '../utils/api';
import { format } from 'date-fns';
import { toast } from 'react-hot-toast';
import { getCurrentUser } from '../utils/auth';
import config from '../config';
import CustomDatePicker from '../components/CustomDatePicker';
import { HubConnectionBuilder, LogLevel } from '@microsoft/signalr'; // NEW: SignalR

const getStatusColor = (code) => {
    if (!code) return '#94a3b8';
    if (code === 'P') return '#10b981';
    if (code === 'A') return '#ef4444';
    return '#3b82f6';
};

const StatusBadge = ({ code, onClick, disabled }) => {
    const color = getStatusColor(code);

    return (
        <Box
            onClick={disabled ? null : onClick}
            sx={{
                width: 32,
                height: 32,
                borderRadius: '8px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '12px',
                fontWeight: 800,
                bgcolor: code ? color + '15' : 'transparent',
                color: code ? color : 'text.disabled',
                border: '1.5px solid',
                borderColor: code ? color + '60' : 'divider',
                cursor: disabled ? 'default' : 'pointer',
                transition: 'all .15s',
                '&:hover': !disabled ? { transform: 'scale(1.08)', boxShadow: `0 0 0 2px ${color}40` } : {}
            }}
        >
            {code || '—'}
        </Box>
    );
};

const LeaveTypeSettingsModal = ({ open, onClose, selectedOrgId, fetchLeaveTypesData }) => {
    const [leaveTypes, setLeaveTypes] = useState([]);
    const [loading, setLoading] = useState(false);
    const [view, setView] = useState('list'); // 'list' or 'form'
    const [form, setForm] = useState({ id: null, fullName: '', shortName: '', isPaid: true });

    const loadData = useCallback(async () => {
        setLoading(true);
        try {
            const data = await fetchLeaveTypeSettings(selectedOrgId);
            setLeaveTypes(data || []);
        } catch (err) { console.error(err); }
        finally { setLoading(false); }
    }, [selectedOrgId]);

    useEffect(() => { if (open && selectedOrgId) { loadData(); setView('list'); } }, [open, selectedOrgId, loadData]);

    const handleToggle = async (leaveTypeId, currentStatus) => {
        try {
            await toggleLeaveType({ leaveTypeId, organizationId: selectedOrgId, isShow: !currentStatus });
            toast.success("Visibility updated");
            loadData();
            fetchLeaveTypesData();
        } catch (err) { toast.error("Update failed"); }
    };

    const handleSave = async (e) => {
        e.preventDefault();
        try {
            const payload = { 
                leaveTypeId: form.id, 
                fullName: form.fullName, 
                shortName: form.shortName, 
                isPaid: form.isPaid,
                organizationId: selectedOrgId 
            };
            await updateLeaveType(payload);
            toast.success(form.id ? "Updated successfully" : "Added successfully");
            setView('list');
            loadData();
            fetchLeaveTypesData();
        } catch (err) {
            toast.error(err.response?.data?.message || "Failed to save");
        }
    };

    const handleDelete = async (id) => {
        if (!window.confirm("Delete this leave type? This action will remove it from your organization's settings.")) return;
        try {
            await deleteLeaveType(id);
            toast.success("Deleted successfully");
            loadData();
            fetchLeaveTypesData();
        } catch (err) { toast.error("Delete failed"); }
    };

    if (!open) return null;

    return (
        <Paper elevation={24} sx={{ position: 'fixed', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', zIndex: 2000, p: 4, width: 480, height: 'auto', maxHeight: '90vh', borderRadius: 3, bgcolor: 'background.paper', display: 'flex', flexDirection: 'column' }}>
            {/* Header */}
            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 3 }}>
                <Stack direction="row" spacing={1.5} alignItems="center">
                    {view === 'form' && (
                        <IconButton size="small" onClick={() => setView('list')} sx={{ p: 0.5, bgcolor: 'action.hover' }}><ChevronLeft size={18} /></IconButton>
                    )}
                    <Box>
                        <Typography variant="h6" sx={{ fontWeight: 800, color: 'text.primary', display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Settings size={20} color="#6366f1" /> {view === 'list' ? 'Status Settings' : (form.id ? 'Edit Status' : 'Add New Status')}
                        </Typography>
                        <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>CONFIGURE ATTENDANCE LABELS</Typography>
                    </Box>
                </Stack>
                {view === 'list' && (
                    <Button 
                        startIcon={<Plus size={16} />} 
                        onClick={() => { setForm({ id: null, fullName: '', shortName: '', isPaid: true }); setView('form'); }} 
                        variant="contained" 
                        disableElevation
                        sx={{ borderRadius: 1.5, height: 35, textTransform: 'none', fontWeight: 700, px: 2 }}
                    >Add Status</Button>
                )}
            </Box>

            {/* List View */}
            {view === 'list' ? (
                <Stack spacing={1.2} sx={{ overflowY: 'auto', pr: 0.5, minHeight: 100 }}>
                    {loading && leaveTypes.length === 0 ? (
                        <Box sx={{ py: 6, textAlign: 'center' }}><CircularProgress size={24} /></Box>
                    ) : leaveTypes.map(lt => (
                        <Paper key={lt.leaveTypeId} variant="outlined" sx={{ p: 1.8, borderRadius: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between', bgcolor: lt.isShow ? 'background.paper' : 'action.hover', border: '1px solid', borderColor: 'divider', '&:hover': { borderColor: 'primary.main', bgcolor: 'background.paper' }, transition: 'all 0.2s' }}>
                            <Stack direction="row" spacing={2} alignItems="center">
                                <Box sx={{ width: 10, height: 10, bgcolor: getStatusColor(lt.shortName), borderRadius: '50%', boxShadow: `0 0 8px ${getStatusColor(lt.shortName)}40` }} />
                                <Box>
                                    <Typography sx={{ fontWeight: 700, fontSize: '13.5px', color: 'text.primary' }}>{lt.fullName}</Typography>
                                    <Typography sx={{ color: 'text.secondary', fontSize: '11px', fontWeight: 700 }}>CODE: {lt.shortName} • {lt.isPaid ? 'PAID' : 'UNPAID'}</Typography>
                                </Box>
                            </Stack>
                            <Stack direction="row" spacing={1} alignItems="center">
                                <IconButton size="small" sx={{ color: 'text.secondary' }} onClick={() => { setForm({ id: lt.leaveTypeId, fullName: lt.fullName, shortName: lt.shortName, isPaid: lt.isPaid ?? true }); setView('form'); }}>
                                    <Edit2 size={16} />
                                </IconButton>
                                <IconButton size="small" color="error" onClick={() => handleDelete(lt.leaveTypeId)}>
                                    <Trash2 size={16} />
                                </IconButton>
                                <Checkbox size="small" checked={lt.isShow} onChange={() => handleToggle(lt.leaveTypeId, lt.isShow)} sx={{ ml: 1 }} />
                            </Stack>
                        </Paper>
                    ))}
                </Stack>
            ) : (
                /* Form View */
                <Stack component="form" onSubmit={handleSave} spacing={2.5} sx={{ mt: 1 }}>
                    <TextField 
                        label="Status Name" 
                        fullWidth 
                        value={form.fullName} 
                        onChange={(e) => setForm({...form, fullName: e.target.value})} 
                        required 
                        placeholder="e.g. Work From Home"
                        size="small"
                        InputProps={{ sx: { borderRadius: 1.5, fontWeight: 600 } }}
                    />
                    <TextField 
                        label="Short Code (Max 4)" 
                        fullWidth 
                        value={form.shortName} 
                        onChange={(e) => setForm({...form, shortName: e.target.value.toUpperCase().slice(0, 4)})} 
                        required 
                        placeholder="WFH"
                        size="small"
                        InputProps={{ sx: { borderRadius: 1.5, fontWeight: 700 } }}
                        helperText="The code used in the registers (P, A, etc.)"
                    />
                    <Stack direction="row" alignItems="center">
                        <Checkbox 
                            size="small" 
                            checked={form.isPaid} 
                            onChange={(e) => setForm({...form, isPaid: e.target.checked})} 
                            sx={{ p: 0.5, ml: -0.5 }}
                        />
                        <Typography sx={{ fontSize: '13.5px', fontWeight: 600, color: 'text.secondary', cursor: 'pointer' }} onClick={() => setForm({...form, isPaid: !form.isPaid})}>
                            This is a Paid Leave / Status
                        </Typography>
                    </Stack>
                    <Stack direction="row" spacing={1.5} sx={{ mt: 1 }}>
                        <Button fullWidth onClick={() => setView('list')} variant="outlined" sx={{ borderRadius: 1.5, height: 42, textTransform: 'none', fontWeight: 700, borderColor: 'divider', color: 'text.secondary' }}>Cancel</Button>
                        <Button type="submit" fullWidth variant="contained" sx={{ borderRadius: 1.5, height: 42, textTransform: 'none', fontWeight: 800 }}>Save Status</Button>
                    </Stack>
                </Stack>
            )}

            {view === 'list' && (
                <Button fullWidth onClick={onClose} variant="outlined" sx={{ mt: 3, borderRadius: 1.5, height: 42, textTransform: 'none', fontWeight: 700, borderColor: 'divider', color: 'text.primary', bgcolor: 'action.hover' }}>Close Settings</Button>
            )}
        </Paper>
    );
};




const Attendance = () => {
    const user = getCurrentUser();
    const isAdmin = user?.role === 'Admin' || user?.role === 'SuperAdmin';
    const [selectedDate, setSelectedDate] = useState(() => new Date().toISOString().split('T')[0]);
    const [selectedOrgId, setSelectedOrgId] = useState(null);
    const [organizations, setOrganizations] = useState([]);
    const [records, setRecords] = useState([]);
    const [selectedIds, setSelectedIds] = useState([]);
    const [leaveTypes, setLeaveTypes] = useState([]);
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [searchQuery, setSearchQuery] = useState('');
    const [settingsOpen, setSettingsOpen] = useState(false);
    const [deptFilter, setDeptFilter] = useState('');
    const [desigFilter, setDesigFilter] = useState('');
    const [menuAnchor, setMenuAnchor] = useState(null);
    const [menuTarget, setMenuTarget] = useState(null);
    const [exportAnchorEl, setExportAnchorEl] = useState(null);

    const loadLeaveTypes = useCallback(async () => {
        if (!selectedOrgId) return;
        try {
            const data = await fetchLeaveTypes(selectedOrgId);
            setLeaveTypes(data || []);
        } catch (err) { console.error(err); }
    }, [selectedOrgId]);

    const loadRecords = useCallback(async () => {
        if (!selectedOrgId || !selectedDate) return;
        setLoading(true);
        try {
            const data = await fetchAttendanceByDate(selectedDate, selectedOrgId);
            setRecords(data || []);
            setSelectedIds([]);
        } catch (err) { console.error(err); }
        finally { setLoading(false); }
    }, [selectedOrgId, selectedDate]);

    useEffect(() => {
        const init = async () => {
            try {
                const orgs = await fetchOrganizations();
                setOrganizations(orgs);
                
                // RESTORE SELECTION FROM LOCAL STORAGE or USER PROFILE
                const savedId = localStorage.getItem('attendance_selected_org');
                const matchingOrg = orgs.find(o => String(o.id) === String(savedId)) || 
                                    orgs.find(o => String(o.id) === String(user?.organizationId));
                
                const defaultId = matchingOrg ? matchingOrg.id : (orgs.length > 0 ? orgs[0].id : null);
                setSelectedOrgId(defaultId);
            } catch (err) { console.error("Init failed", err); }
        };
        init();
    }, []);

    useEffect(() => {
        if (selectedOrgId) {
            loadRecords();
            loadLeaveTypes();
        }
    }, [selectedOrgId, selectedDate, loadRecords, loadLeaveTypes]);

    // ── SignalR REAL-TIME UPDATES ──
    useEffect(() => {
        if (!selectedOrgId) return;

        const connection = new HubConnectionBuilder()
            .withUrl(`${config.SOCKET_URL}/hubs/attendance`)
            .withAutomaticReconnect()
            .configureLogging(LogLevel.Information)
            .build();

        const startConnection = async () => {
            try {
                await connection.start();
                console.log('[SignalR] Connected to Attendance/Employees Hub');
                await connection.invoke('JoinOrganizationGroup', selectedOrgId);

                connection.on('AttendanceChanged', (payload) => {
                    console.log('[SignalR] Attendance update received:', payload);
                    // Match the date (handle JSON date string vs ISO string)
                    const incomingDate = payload.date?.split('T')[0];
                    const currentDate = selectedDate?.split('T')[0];
                    
                    if (incomingDate === currentDate) {
                        loadRecords(true); // silent reload
                    }
                });

                connection.on('LeaveTypeChanged', () => {
                    loadLeaveTypes();
                    loadRecords();
                });

            } catch (err) { console.error('[SignalR] Error:', err); }
        };

        startConnection();

        return () => {
            if (connection) connection.stop();
        };
    }, [selectedOrgId, selectedDate, loadRecords, loadLeaveTypes]);

    const handleOrgChange = async (e) => {
        const id = e.target.value;
        if (id === selectedOrgId) return;

        const org = organizations.find(o => o.id === id);
        const name = org?.name || 'Organization';

        try {
            const loadingToast = toast.loading(`Switching to ${name}...`);
            await switchOrganization(id);
            setSelectedOrgId(id);
            setSelectedIds([]);
            localStorage.setItem('attendance_selected_org', id); // PERSIST SELECTION
            toast.success(`Switched to ${name}`, { id: loadingToast });
        } catch (error) {
            console.error('Switch failed:', error);
            toast.error('Failed to switch organization');
        }
    };

    const allOptions = useMemo(() =>
        leaveTypes.map(lt => ({
            code: lt.shortName,
            label: lt.fullName,
            color: getStatusColor(lt.shortName)
        }))
        , [leaveTypes]);

    const handleStatusSelect = async (code) => {
        if (!menuTarget) return;
        setMenuAnchor(null);
        setMenuTarget(null);
        const { employeeId, field, isBulk } = menuTarget;
        setSaving(true);
        try {
            const targets = isBulk ? selectedIds : [employeeId];
            const bulkRecords = targets.map(id => {
                const rec = records.find(r => r.employeeId === id);
                return {
                    employeeId: id,
                    attendanceDate: selectedDate,
                    fn: field === 'FN' ? code : (rec?.fn || 'A'),
                    an: field === 'AN' ? code : (rec?.an || 'A')
                };
            });
            await bulkUpsertEmpAttendance({ attendanceDate: selectedDate, records: bulkRecords }, selectedOrgId);
            toast.success(`Updated ${bulkRecords.length} records`);
            loadRecords();
        } catch (err) { toast.error("Failed to update"); }
        finally { setSaving(false); }
    };
    /////////////// attnecence report export vk 30/03/2026///////////////////////

    const handleExport = async (type) => {
        setExportAnchorEl(null);
        if (!selectedOrgId) {
            toast.error("Please wait for organization to load...");
            return;
        }
        try {
            const dateObj = new Date(selectedDate);
            const params = {
                month: dateObj.getMonth() + 1,
                year: dateObj.getFullYear(),
                department: deptFilter || null,
                designation: desigFilter || null,
                search: searchQuery || null
            };
            
            const loadingToast = toast.loading(`Generating ${type.toUpperCase()} Attendance Register...`);
            await exportAttendanceRegister(params, type);
            toast.success("Attendance Register exported successfully", { id: loadingToast });
        } catch (err) {
            console.error("Export failed:", err);
            toast.error("Failed to export attendance register");
        }
    };
////////////////attendance report export vk 30/03/2026///////////////////////
    const filtered = useMemo(() =>
        records.filter(r => {
            const matchesSearch = !searchQuery || r.employeeName?.toLowerCase().includes(searchQuery.toLowerCase()) || r.employeeCode?.toLowerCase().includes(searchQuery.toLowerCase());
            const matchesDept = !deptFilter || r.department === deptFilter;
            const matchesDesig = !desigFilter || r.designation === desigFilter;
            return matchesSearch && matchesDept && matchesDesig;
        })
        , [records, searchQuery, deptFilter, desigFilter]);

    const toggleSelectAll = (e) => {
        if (e.target.checked) setSelectedIds(filtered.map(r => r.employeeId));
        else setSelectedIds([]);
    };

    const isAllSelected = filtered.length > 0 && selectedIds.length === filtered.length;
    const isIndeterminate = selectedIds.length > 0 && selectedIds.length < filtered.length;

    const uniqueDepts = useMemo(() => [...new Set(records.map(r => r.department).filter(Boolean))], [records]);
    const uniqueDesigs = useMemo(() => [...new Set(records.map(r => r.designation).filter(Boolean))], [records]);

    const stats = useMemo(() => {
        let present = 0, absent = 0, leave = 0, unmarked = 0;
        records.forEach(r => {
            if (!r.fn && !r.an) unmarked++;
            else if (r.fn === 'P' && r.an === 'P') present++;
            else if (r.fn === 'A' && r.an === 'A') absent++;
            else leave++;
        });
        return { present, absent, leave, unmarked };
    }, [records]);

    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
            <Box>
                <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2.5 }}>
                    <Box>
                        <Typography variant="h5" sx={{ fontWeight: 800, color: 'text.primary', display: 'flex', alignItems: 'center', gap: 1.5 }}>
                            <CalendarDays color="#6366f1" size={26} /> Daily Attendance Register
                        </Typography>
                        <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>
                            {format(new Date(selectedDate), 'EEEE, do MMMM yyyy')} • {records.length} Employees Total
                        </Typography>
                    </Box>
                    <Stack direction="row" spacing={1.5}>
                        {isAdmin && (
                            <Button variant="outlined" startIcon={<Settings size={16} />} onClick={() => setSettingsOpen(true)} sx={{ borderRadius: 1.5, textTransform: 'none', fontWeight: 600 }}>Settings</Button>
                        )}
                        <Button 
                            variant="contained" 
                            disableElevation 
                            startIcon={<Download size={16} />} 
                            onClick={(e) => setExportAnchorEl(e.currentTarget)}
                            disabled={!selectedOrgId || loading}
                            sx={{ borderRadius: 1.5, textTransform: 'none', px: 2, fontWeight: 700 }}
                        >Export Data</Button>
                        <Menu
                            anchorEl={exportAnchorEl}
                            open={Boolean(exportAnchorEl)}
                            onClose={() => setExportAnchorEl(null)}
                            PaperProps={{
                                sx: { mt: 1, border: '1px solid', borderColor: 'divider', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }
                            }}
                        >
                            <MenuItem onClick={() => handleExport('excel')} sx={{ fontSize: '13px', py: 1 }}>
                                Excel Spreadsheet (.xlsx)
                            </MenuItem>
                            <MenuItem onClick={() => handleExport('pdf')} sx={{ fontSize: '13px', py: 1 }}>
                                PDF Document (.pdf)
                            </MenuItem>
                        </Menu>
                    </Stack>
                </Stack>

                <Grid container spacing={2}>
                    {[
                        { label: 'Present', val: stats.present, color: '#10b981', bg: 'rgba(16,185,129,0.08)' },
                        { label: 'Absent', val: stats.absent, color: '#ef4444', bg: 'rgba(239,68,68,0.08)' },
                        { label: 'On Leave / Half', val: stats.leave, color: '#3b82f6', bg: 'rgba(59,130,246,0.08)' },
                        { label: 'Unmarked', val: stats.unmarked, color: '#94a3b8', bg: 'rgba(148,163,184,0.08)' },
                    ].map(s => (
                        <Grid size={{ xs: 12, sm: 6, md: 3 }} key={s.label}>
                            <Paper elevation={0} sx={{ p: 2, borderRadius: 2, bgcolor: s.bg, border: '1px solid', borderColor: s.color + '20', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                <Box>
                                    <Typography variant="caption" sx={{ color: s.color, fontWeight: 800, textTransform: 'uppercase', letterSpacing: 1.2, display: 'block', mb: 0.5 }}>{s.label}</Typography>
                                    <Typography variant="h4" sx={{ fontWeight: 900, color: 'text.primary', lineHeight: 1 }}>{s.val}</Typography>
                                </Box>
                                <Avatar sx={{ bgcolor: s.color, width: 32, height: 32, opacity: 0.2 }}>
                                    <Users size={16} color="#fff" />
                                </Avatar>
                            </Paper>
                        </Grid>
                    ))}
                </Grid>
            </Box>

            <Paper elevation={0} sx={{ display: 'flex', flexDirection: { xs: 'column', md: 'row' }, alignItems: { xs: 'stretch', md: 'center' }, gap: 1.5, p: 1, px: 2, borderRadius: 1, border: '1px solid', borderColor: 'divider' }}>
                <Stack direction="row" spacing={1} alignItems="center" sx={{ borderRight: { md: '1px solid' }, borderColor: { md: 'divider' }, pr: { md: 2 } }}>
                    <Building2 size={14} color="#94a3b8" />
                    <Typography sx={{ color: 'text.secondary', fontSize: '13px' }}>Organization</Typography>
                    <Select
                        value={selectedOrgId || ''}
                        onChange={handleOrgChange}
                        size="small"
                        displayEmpty
                        sx={{
                            height: 32, fontSize: '13px',
                            '& .MuiOutlinedInput-notchedOutline': { border: 'none' },
                            bgcolor: 'action.hover', borderRadius: 1, minWidth: 200
                        }}
                    >
                        {organizations.length === 0 && <MenuItem value="">Loading...</MenuItem>}
                        {organizations.map((org, index) => (
                            <MenuItem key={`${org.id ?? 'org'}-${index}`} value={org.id}>
                                <Stack direction="row" spacing={1.5} alignItems="center">
                                    <Avatar
                                        src={org.logoUrl ? `${config.SOCKET_URL}${org.logoUrl}` : ''}
                                        variant="rounded"
                                        sx={{ width: 22, height: 22, bgcolor: 'action.selected', color: 'text.secondary', fontSize: '10px' }}
                                    >
                                        <Building2 size={12} />
                                    </Avatar>
                                    <Typography sx={{ fontSize: '13px', fontWeight: 500 }}>{org.name}</Typography>
                                </Stack>
                            </MenuItem>
                        ))}
                    </Select>
                </Stack>

                <Box sx={{ minWidth: 160 }}>
                    <CustomDatePicker
                        value={selectedDate}
                        onChange={e => setSelectedDate(e.target.value)}
                        inputStyle={{
                            '& .MuiInputBase-root': {
                                height: 32,
                                fontSize: '13px',
                                bgcolor: 'action.hover',
                                border: 'none',
                                '& fieldset': { border: 'none' },
                                borderRadius: 1
                            }
                        }}
                    />
                </Box>

                <Box sx={{ flex: 1 }}>
                    <TextField
                        placeholder="Search employee name or code..."
                        size="small"
                        fullWidth
                        value={searchQuery}
                        onChange={e => setSearchQuery(e.target.value)}
                        InputProps={{
                            startAdornment: <InputAdornment position="start"><Search size={14} color="#64748b" /></InputAdornment>,
                            sx: { height: 32, fontSize: '13px', bgcolor: 'action.hover', border: 'none', '& fieldset': { border: 'none' }, borderRadius: 1 }
                        }}
                    />
                </Box>

                <Stack direction="row" spacing={1} alignItems="center">
                    <Typography sx={{ color: 'text.secondary', fontSize: '13px' }}>Dept</Typography>
                    <Select value={deptFilter} onChange={e => setDeptFilter(e.target.value)} size="small" sx={{ height: 32, fontSize: '13px', border: 'none', '& .MuiOutlinedInput-notchedOutline': { border: 'none' }, bgcolor: 'action.hover', borderRadius: 1 }}>
                        <MenuItem value="">All</MenuItem>
                        {uniqueDepts.map(d => <MenuItem key={d} value={d} sx={{ fontSize: '13px' }}>{d}</MenuItem>)}
                    </Select>
                </Stack>

                <Stack direction="row" spacing={1} alignItems="center">
                    <Typography sx={{ color: 'text.secondary', fontSize: '13px' }}>Desig</Typography>
                    <Select value={desigFilter} onChange={e => setDesigFilter(e.target.value)} size="small" sx={{ height: 32, fontSize: '13px', border: 'none', '& .MuiOutlinedInput-notchedOutline': { border: 'none' }, bgcolor: 'action.hover', borderRadius: 1 }}>
                        <MenuItem value="">All</MenuItem>
                        {uniqueDesigs.map(d => <MenuItem key={d} value={d} sx={{ fontSize: '13px' }}>{d}</MenuItem>)}
                    </Select>
                </Stack>
            </Paper>

            {selectedIds.length > 0 && (
                <Stack direction="row" spacing={2} alignItems="center" sx={{ p: 1, px: 2, bgcolor: 'primary.main', borderRadius: 1.5, color: '#fff', boxShadow: '0 4px 20px rgba(59,130,246,0.3)' }}>
                    <Typography variant="body2" sx={{ fontWeight: 800 }}>{selectedIds.length} Selected</Typography>
                    <Divider orientation="vertical" flexItem sx={{ bgcolor: 'rgba(255,255,255,0.2)' }} />
                    <Button size="small" variant="contained" disableElevation onClick={e => { setMenuAnchor(e.currentTarget); setMenuTarget({ isBulk: true, field: 'FN' }); }} sx={{ textTransform: 'none', fontWeight: 700, bgcolor: 'rgba(255,255,255,0.15)', '&:hover': { bgcolor: 'rgba(255,255,255,0.25)' } }}>Apply FN Status</Button>
                    <Button size="small" variant="contained" disableElevation onClick={e => { setMenuAnchor(e.currentTarget); setMenuTarget({ isBulk: true, field: 'AN' }); }} sx={{ textTransform: 'none', fontWeight: 700, bgcolor: 'rgba(255,255,255,0.15)', '&:hover': { bgcolor: 'rgba(255,255,255,0.25)' } }}>Apply AN Status</Button>
                    <Box sx={{ flex: 1 }} />
                    <Button size="small" sx={{ color: '#fff', opacity: 0.8, textTransform: 'none' }} onClick={() => setSelectedIds([])}>Clear Selection</Button>
                </Stack>
            )}

            <Paper elevation={0} sx={{ bgcolor: 'background.paper', border: '1px solid', borderColor: 'divider', borderRadius: 2, overflow: 'hidden' }}>
                <TableContainer sx={{ overflowX: 'auto' }}>
                    <Table sx={{ minWidth: 1000 }}>
                        <TableHead sx={{ bgcolor: 'action.hover' }}>
                            <TableRow>
                                <TableCell padding="checkbox">
                                    <Checkbox
                                        size="small"
                                        checked={isAllSelected}
                                        indeterminate={isIndeterminate}
                                        onChange={toggleSelectAll}
                                    />
                                </TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center' }}>CODE <ArrowUpDown size={12} style={{ marginLeft: 4 }} /></Box>
                                </TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    NAME
                                </TableCell>
                                <TableCell align="center" sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    <Stack direction="row" spacing={0.5} justifyContent="center" alignItems="center"><Sun size={12} /><span>FORENOON</span></Stack>
                                </TableCell>
                                <TableCell align="center" sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    <Stack direction="row" spacing={0.5} justifyContent="center" alignItems="center"><Sunset size={12} /><span>AFTERNOON</span></Stack>
                                </TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    DEPT / DESIGNATION
                                </TableCell>
                                <TableCell align="right" sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>ACTION</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow><TableCell colSpan={8} align="center" sx={{ py: 10 }}><CircularProgress size={30} /></TableCell></TableRow>
                            ) : filtered.length === 0 ? (
                                <TableRow><TableCell colSpan={8} align="center" sx={{ py: 10, color: 'text.secondary' }}>No matching employees found for the selected date.</TableCell></TableRow>
                            ) : filtered.map((rec) => (
                                <TableRow key={rec.employeeId} sx={{ '&:hover': { bgcolor: 'action.hover' } }}>
                                    <TableCell padding="checkbox">
                                        <Checkbox
                                            size="small"
                                            checked={selectedIds.includes(rec.employeeId)}
                                            onChange={() => setSelectedIds(prev => prev.includes(rec.employeeId) ? prev.filter(x => x !== rec.employeeId) : [...prev, rec.employeeId])}
                                        />
                                    </TableCell>
                                    <TableCell sx={{ fontSize: '13px', fontWeight: 600, color: 'text.secondary' }}>{rec.employeeCode}</TableCell>
                                    <TableCell>
                                        <Stack direction="row" spacing={1.5} alignItems="center">
                                            <Avatar 
                                                src={config.getMediaUrl(rec.profilePictureUrl || rec.ProfilePictureUrl)}
                                                sx={{ width: 30, height: 30, border: '1px solid', borderColor: 'divider', bgcolor: 'primary.light', fontSize: '12px', color: 'primary.main', fontWeight: 700 }}
                                            >
                                                {rec.employeeName?.charAt(0)}
                                            </Avatar>
                                            <Typography sx={{ fontWeight: 700, fontSize: '13px' }}>{rec.employeeName}</Typography>
                                        </Stack>
                                    </TableCell>
                                    <TableCell align="center">
                                        <StatusBadge code={rec.fn} disabled={!isAdmin} onClick={e => { setMenuAnchor(e.currentTarget); setMenuTarget({ employeeId: rec.employeeId, field: 'FN' }); }} />
                                    </TableCell>
                                    <TableCell align="center">
                                        <StatusBadge code={rec.an} disabled={!isAdmin} onClick={e => { setMenuAnchor(e.currentTarget); setMenuTarget({ employeeId: rec.employeeId, field: 'AN' }); }} />
                                    </TableCell>
                                    <TableCell>
                                        <Typography sx={{ fontSize: '12px', fontWeight: 600 }}>{rec.department || '—'}</Typography>
                                        <Typography variant="caption" sx={{ color: 'text.secondary' }}>{rec.designation || 'Staff'}</Typography>
                                    </TableCell>
                                    <TableCell align="right">
                                        <IconButton size="small"><MoreVertical size={16} /></IconButton>
                                    </TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                </TableContainer>
            </Paper>

            <Menu
                anchorEl={menuAnchor}
                open={Boolean(menuAnchor)}
                onClose={() => setMenuAnchor(null)}
                PaperProps={{ sx: { borderRadius: 2, minWidth: 180, p: 0.5, boxShadow: '0 10px 40px rgba(0,0,0,0.1)', border: '1px solid', borderColor: 'divider' } }}
            >
                <Typography variant="caption" sx={{ px: 2, py: 1, display: 'block', fontWeight: 800, color: 'text.secondary', textTransform: 'uppercase', letterSpacing: 1 }}>Select Status</Typography>
                <Divider sx={{ my: 0.5 }} />
                {allOptions.map(opt => (
                    <MenuItem key={opt.code} onClick={() => handleStatusSelect(opt.code)} sx={{ borderRadius: 1.5, fontSize: '13px', fontWeight: 600, py: 1 }}>
                        <Box sx={{ width: 10, height: 10, borderRadius: '50%', bgcolor: opt.color, mr: 2 }} />
                        {opt.label} ({opt.code})
                    </MenuItem>
                ))}
            </Menu>

            <LeaveTypeSettingsModal open={settingsOpen} onClose={() => setSettingsOpen(false)} selectedOrgId={selectedOrgId} fetchLeaveTypesData={loadLeaveTypes} />
        </Box>
    );
};

export default Attendance;
