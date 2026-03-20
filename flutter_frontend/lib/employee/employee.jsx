import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Stack,
    Typography,
    Button,
    TextField,
    InputAdornment,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Paper,
    Checkbox,
    IconButton,
    Select,
    MenuItem,
    Avatar,
    Drawer,
    CircularProgress,
    Chip,
    Menu
} from '@mui/material';
import AddEmployeeForm from '../components/Forms/AddEmployeeForm';
import { fetchEmployees, fetchOrganizations, deleteEmployee, switchOrganization } from '../utils/api';
import toast from 'react-hot-toast';
import config from '../config';
import { HubConnectionBuilder, LogLevel } from '@microsoft/signalr';
import {
    Plus, Search, Filter, Download, List, LayoutGrid, MoreVertical,
    Upload, ArrowUpDown, Edit, Trash2, ChevronLeft, ChevronRight, User as UserIcon, Building2, Settings, Database
} from 'lucide-react';
import SuperAdminFieldsModal from '../components/Forms/SuperAdminFieldsModal';
import { useFormStyles } from '../styles/formStyles';
import { getCurrentUser } from '../utils/auth';

const Employees = () => {
    const fs = useFormStyles();
    const [searchQuery, setSearchQuery] = useState('');
    const [designationFilter, setDesignationFilter] = useState('All');
    const [departmentFilter, setDepartmentFilter] = useState('All');
    const [isDrawerOpen, setIsDrawerOpen] = useState(false);
    const [isSuperAdminFieldsModalOpen, setIsSuperAdminFieldsModalOpen] = useState(false);
    const [employees, setEmployees] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedIds, setSelectedIds] = useState([]);
    const [exportAnchorEl, setExportAnchorEl] = useState(null);

    const user = getCurrentUser();
    const userRole = user?.role || 'User';
    const isSuperAdmin = userRole === 'SuperAdmin';
    const isAdminOrAbove = userRole === 'Admin' || userRole === 'SuperAdmin';
    const currentOrgIdFromToken = user?.organizationId;

    // Organization state
    const [organizations, setOrganizations] = useState([]);
    const [selectedOrgId, setSelectedOrgId] = useState(null);
    const [selectedOrgName, setSelectedOrgName] = useState('');

    // Menu state
    const [anchorEl, setAnchorEl] = useState(null);
    const [menuEmployee, setMenuEmployee] = useState(null); // The employee being interacted via menu
    const [editEmployee, setEditEmployee] = useState(null); // The employee to populate in drawer for edit

    // Fetch organizations the current user has access to, default to first
    useEffect(() => {
        fetchOrganizations()
            .then(orgs => {
                setOrganizations(orgs || []);
                if (orgs && orgs.length > 0) {
                    const defaultId = currentOrgIdFromToken || orgs[0].id;
                    const found = orgs.find(o => o.id === defaultId) || orgs[0];
                    setSelectedOrgId(found.id);
                    setSelectedOrgName(found.name);
                }
            })
            .catch(() => toast.error('Failed to load organizations'));
    }, [currentOrgIdFromToken]);

    const loadEmployees = useCallback(async (silent = false) => {
        if (!selectedOrgId) return;
        try {
            if (!silent) setLoading(true);
            const data = await fetchEmployees(selectedOrgId);
            setEmployees(data || []);
        } catch {
            toast.error('Failed to load employees');
        } finally {
            if (!silent) setLoading(false);
        }
    }, [selectedOrgId]);

    useEffect(() => {
        loadEmployees();
    }, [loadEmployees]);

    // SignalR Setup
    useEffect(() => {
        if (!selectedOrgId) return;

        let connection = new HubConnectionBuilder()
            .withUrl(`${config.SOCKET_URL}/hubs/employees`)
            .withAutomaticReconnect()
            .configureLogging(LogLevel.Information)
            .build();

        const startConnection = async () => {
            try {
                await connection.start();
                console.log('[SignalR] Connected to EmployeesHub');
                // Join the group for this organization
                await connection.invoke('JoinOrganizationGroup', selectedOrgId);

                connection.on('EmployeeChanged', (payload) => {
                    console.log('[SignalR] Employee change received:', payload);
                    if (payload.action === 'Create') toast.success(`Employee Created: ${payload.name}`);
                    else if (payload.action === 'Update') toast.success(`Employee Updated: ${payload.name}`);
                    else if (payload.action === 'Delete') toast.error(`Employee Deleted`);

                    loadEmployees(true); // reload silently
                });

            } catch (err) {
                console.error('[SignalR] Connection Error: ', err);
            }
        };

        startConnection();

        return () => {
            if (connection) {
                connection.stop();
            }
        };
    }, [selectedOrgId, loadEmployees]);

    const handleOrgChange = async (e) => {
        const id = parseInt(e.target.value);
        if (id === selectedOrgId) return;

        try {
            const loadingToast = toast.loading('Switching organization...');
            await switchOrganization(id);

            const org = organizations.find(o => o.id === id);
            setSelectedOrgId(id);
            setSelectedOrgName(org?.name || '');
            setSelectedIds([]); // Clear selection on org change

            toast.success(`Switched to ${org?.name}`, { id: loadingToast });
        } catch (error) {
            toast.error('Failed to switch organization');
        }
    };

    const handleSelectAll = (e) => {
        if (e.target.checked) {
            setSelectedIds(filtered.map(emp => emp.id));
        } else {
            setSelectedIds([]);
        }
    };

    const handleSelectOne = (id) => {
        setSelectedIds(prev =>
            prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
        );
    };

    const handleExport = (type) => {
        if (!selectedOrgId) return;
        setExportAnchorEl(null);

        const idsParam = selectedIds.length > 0 ? `&employeeIds=${selectedIds.join(',')}` : '';
        const url = `${config.API_BASE_URL}/employees/export-${type}?organizationId=${selectedOrgId}${idsParam}`;

        const loadingToast = toast.loading(`Generating ${type.toUpperCase()}...`);

        fetch(url, {
            headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` }
        })
            .then(res => {
                if (!res.ok) throw new Error('Export failed');
                return res.blob();
            })
            .then(blob => {
                const downloadUrl = window.URL.createObjectURL(blob);
                const link = document.createElement('a');
                link.href = downloadUrl;
                link.setAttribute('download', `Employees_${new Date().toISOString().split('T')[0]}.${type === 'excel' ? 'xlsx' : 'pdf'}`);
                document.body.appendChild(link);
                link.click();
                link.remove();
                toast.success(`${type.toUpperCase()} exported successfully`, { id: loadingToast });
            })
            .catch(err => {
                console.error(err);
                toast.error(`Failed to export ${type.toUpperCase()}`, { id: loadingToast });
            });
    };

    const toggleDrawer = (open) => {
        setIsDrawerOpen(open);
        if (!open) {
            setEditEmployee(null);
        }
    };

    const handleOpenMenu = (event, emp) => {
        setAnchorEl(event.currentTarget);
        setMenuEmployee(emp);
    };

    const handleCloseMenu = () => {
        setAnchorEl(null);
        setMenuEmployee(null);
    };

    const handleEdit = () => {
        setEditEmployee(menuEmployee);
        handleCloseMenu();
        setIsDrawerOpen(true);
    };

    const handleDelete = async () => {
        if (!menuEmployee) return;
        if (!window.confirm(`Are you sure you want to delete ${menuEmployee.name}?`)) return;

        try {
            await deleteEmployee(menuEmployee.id);
            toast.success('Employee deleted successfully');
            loadEmployees();
        } catch (err) {
            toast.error('Failed to delete employee');
            console.error(err);
        } finally {
            handleCloseMenu();
        }
    };


    // Filter by search, designation, and department
    const filtered = employees.filter(emp => {
        const matchesSearch = !searchQuery ||
            emp.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
            emp.email?.toLowerCase().includes(searchQuery.toLowerCase()) ||
            emp.employeeCode?.toLowerCase().includes(searchQuery.toLowerCase());

        const matchesDesignation = designationFilter === 'All' || emp.designation === designationFilter;
        const matchesDepartment = departmentFilter === 'All' || emp.department === departmentFilter;

        return matchesSearch && matchesDesignation && matchesDepartment;
    });

    // Get unique designations and departments from current employees
    const availableDesignations = ['All', ...new Set(employees.map(emp => emp.designation).filter(Boolean))];
    const availableDepartments = ['All', ...new Set(employees.map(emp => emp.department).filter(Boolean))];

    const filterSelectSx = {
        height: 32,
        color: 'text.primary',
        fontSize: '13px',
        '& .MuiOutlinedInput-notchedOutline': { border: 'none' },
        bgcolor: 'action.hover',
        borderRadius: 1
    };

    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>

            {/* Filter Bar */}
            <Paper
                elevation={0}
                sx={{
                    display: 'flex',
                    flexDirection: { xs: 'column', md: 'row' },
                    alignItems: { xs: 'stretch', md: 'center' },
                    gap: 1.5,
                    bgcolor: 'background.paper',
                    p: 1,
                    px: 2,
                    borderRadius: 1,
                    mb: 2,
                    border: '1px solid',
                    borderColor: 'divider'
                }}
            >
                {/* ── Organization Selector (replaces Duration) ── */}
                <Stack direction="row" spacing={1} alignItems="center" sx={{ borderRight: { md: '1px solid' }, borderColor: { md: 'divider' }, borderBottom: { xs: '1px solid', md: 'none' }, pr: { md: 2 }, pb: { xs: 1, md: 0 } }}>
                    <Building2 size={14} color="#94a3b8" />
                    <Typography sx={{ color: 'text.secondary', fontSize: '13px', whiteSpace: 'nowrap' }}>Organization</Typography>
                    {organizations.length === 1 ? (
                        // Only one org — show as a read-only chip, no dropdown needed
                        <Chip
                            label={selectedOrgName}
                            size="small"
                            sx={{ bgcolor: 'rgba(59,130,246,0.15)', color: '#60a5fa', fontSize: '12px', fontWeight: 500, border: '1px solid rgba(59,130,246,0.3)', height: 24 }}
                        />
                    ) : (
                        <Select
                            value={selectedOrgId || ''}
                            onChange={handleOrgChange}
                            size="small"
                            displayEmpty
                            sx={{
                                height: 32, color: 'text.primary', fontSize: '13px',
                                '& .MuiOutlinedInput-notchedOutline': { border: 'none' },
                                bgcolor: 'action.hover', borderRadius: 1
                            }}
                        >
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
                                        <Typography sx={{ fontSize: '13px' }}>{org.name}</Typography>
                                    </Stack>
                                </MenuItem>
                            ))}
                        </Select>
                    )}
                </Stack>

                <Stack direction="row" spacing={1} alignItems="center" sx={{ borderRight: { md: '1px solid' }, borderColor: { md: 'divider' }, borderBottom: { xs: '1px solid', md: 'none' }, pr: { md: 2 }, pb: { xs: 1, md: 0 } }}>
                    <Typography sx={{ color: 'text.secondary', fontSize: '13px' }}>Designation</Typography>
                    <Select value={designationFilter} onChange={(e) => setDesignationFilter(e.target.value)} size="small" sx={{ height: 32, color: 'text.primary', fontSize: '13px', '& .MuiOutlinedInput-notchedOutline': { border: 'none' }, bgcolor: 'action.hover', borderRadius: 1 }}>
                        {availableDesignations.map(d => (
                            <MenuItem key={d} value={d}>{d}</MenuItem>
                        ))}
                    </Select>
                </Stack>

                <Stack direction="row" spacing={1} alignItems="center" sx={{ borderRight: { md: '1px solid' }, borderColor: { md: 'divider' }, borderBottom: { xs: '1px solid', md: 'none' }, pr: { md: 2 }, pb: { xs: 1, md: 0 } }}>
                    <Typography sx={{ color: 'text.secondary', fontSize: '13px' }}>Department</Typography>
                    <Select value={departmentFilter} onChange={(e) => setDepartmentFilter(e.target.value)} size="small" sx={{ height: 32, color: 'text.primary', fontSize: '13px', '& .MuiOutlinedInput-notchedOutline': { border: 'none' }, bgcolor: 'action.hover', borderRadius: 1 }}>
                        {availableDepartments.map(d => (
                            <MenuItem key={d} value={d}>{d}</MenuItem>
                        ))}
                    </Select>
                </Stack>

                <Box sx={{ flex: 1 }}>
                    <TextField
                        fullWidth
                        placeholder="Start typing to search"
                        size="small"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        InputProps={{
                            startAdornment: (
                                <InputAdornment position="start">
                                    <Search size={14} color="#64748b" />
                                </InputAdornment>
                            ),
                            sx: {
                                bgcolor: 'action.hover',
                                color: 'text.primary',
                                fontSize: '13px',
                                '& .MuiOutlinedInput-notchedOutline': { border: 'none' }
                            }
                        }}
                    />
                </Box>

                <Button
                    variant="text"
                    startIcon={<Filter size={14} />}
                    sx={{ color: 'text.secondary', textTransform: 'none', fontSize: '13px' }}
                >
                    Filters
                </Button>
            </Paper>

            {/* Action Buttons & View Toggle */}
            <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" spacing={2} sx={{ mb: 2 }}>
                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1.5 }}>
                    <Button
                        variant="contained"
                        startIcon={<Plus size={18} />}
                        onClick={() => { setEditEmployee(null); setIsDrawerOpen(true); }}
                        sx={{
                            textTransform: 'none',
                            fontWeight: 600,
                            whiteSpace: 'nowrap'
                        }}
                    >
                        Add Employee
                    </Button>
                    {isSuperAdmin && (
                        <Button variant="outlined" startIcon={<Database size={16} />} onClick={() => setIsSuperAdminFieldsModalOpen(true)} sx={{ textTransform: 'none', whiteSpace: 'nowrap', borderColor: '#ef4444', color: '#ef4444', '&:hover': { bgcolor: 'rgba(239,68,68,0.05)', borderColor: '#ef4444' } }}>Manage Fields</Button>
                    )}
                    <Button variant="outlined" startIcon={<Upload size={16} />} sx={{ textTransform: 'none', whiteSpace: 'nowrap' }}>Import</Button>
                    <Button variant="outlined" startIcon={<Download size={16} />} sx={{ textTransform: 'none', whiteSpace: 'nowrap' }} onClick={(e) => setExportAnchorEl(e.currentTarget)}>Export</Button>
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
                            PDF  (.pdf)
                        </MenuItem>
                    </Menu>
                </Box>

                <Stack direction="row" spacing={1} sx={{ bgcolor: 'action.hover', p: 0.5, borderRadius: 1, alignSelf: { xs: 'flex-start', sm: 'auto' } }}>
                    <IconButton size="small" sx={{ bgcolor: 'rgba(59,130,246,0.15)', color: 'primary.main', borderRadius: 1 }}><List size={18} /></IconButton>
                    <IconButton size="small" sx={{ color: 'text.secondary' }}><LayoutGrid size={18} /></IconButton>
                </Stack>
            </Stack>

            {/* Table + Pagination — wrapped in one Paper like Designation page */}
            <Paper elevation={0} sx={{ bgcolor: 'background.paper', border: '1px solid', borderColor: 'divider', borderRadius: 2, overflow: 'hidden' }}>
                <TableContainer sx={{ overflowX: 'auto' }}>
                    <Table sx={{ minWidth: 1000 }}>
                        <TableHead sx={{ bgcolor: 'action.hover' }}>
                            <TableRow>
                                <TableCell padding="checkbox">
                                    <Checkbox
                                        size="small"
                                        sx={{ color: 'divider' }}
                                        checked={filtered.length > 0 && selectedIds.length === filtered.length}
                                        indeterminate={selectedIds.length > 0 && selectedIds.length < filtered.length}
                                        onChange={handleSelectAll}
                                    />
                                </TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center' }}>EMPLOYEE ID <ArrowUpDown size={12} style={{ marginLeft: 4 }} /></Box>
                                </TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center' }}>NAME <ArrowUpDown size={12} style={{ marginLeft: 4 }} /></Box>
                                </TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center' }}>EMAIL <ArrowUpDown size={12} style={{ marginLeft: 4 }} /></Box>
                                </TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center' }}>USER ROLE <ArrowUpDown size={12} style={{ marginLeft: 4 }} /></Box>
                                </TableCell>
                                <TableCell sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center' }}>STATUS <ArrowUpDown size={12} style={{ marginLeft: 4 }} /></Box>
                                </TableCell>
                                {isAdminOrAbove && (
                                    <TableCell align="right" sx={{ color: 'text.secondary', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', borderBottom: '1px solid', borderColor: 'divider' }}>ACTION</TableCell>
                                )}
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow>
                                    <TableCell colSpan={8} align="center" sx={{ py: 6, border: 'none' }}>
                                        <CircularProgress size={28} sx={{ color: 'primary.main' }} />
                                        <Typography sx={{ color: 'text.secondary', fontSize: '13px', mt: 1.5 }}>Loading employees...</Typography>
                                    </TableCell>
                                </TableRow>
                            ) : filtered.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={8} align="center" sx={{ py: 6, border: 'none' }}>
                                        <Typography sx={{ color: 'text.secondary', fontSize: '13px' }}>
                                            {searchQuery ? 'No employees match your search.' : 'No employees yet. Click "Add Employee" to get started.'}
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            ) : filtered.map((emp) => (
                                <TableRow key={emp.id} sx={{ bgcolor: 'transparent', '&:hover': { bgcolor: 'action.hover' }, '& td': { borderColor: 'divider' } }}>
                                    <TableCell padding="checkbox">
                                        <Checkbox
                                            size="small"
                                            sx={{ color: 'text.disabled' }}
                                            checked={selectedIds.includes(emp.id)}
                                            onChange={() => handleSelectOne(emp.id)}
                                        />
                                    </TableCell>
                                    <TableCell sx={{ color: 'text.primary', fontSize: '13px', py: 1.5 }}>{emp.employeeCode || '--'}</TableCell>
                                    <TableCell sx={{ py: 1.5 }}>
                                        <Stack direction="row" spacing={1} alignItems="center">
                                            <Avatar
                                                src={emp.profilePictureUrl ? `${config.SOCKET_URL}${emp.profilePictureUrl}` : undefined}
                                                alt={emp.name}
                                                sx={{ width: 28, height: 28, bgcolor: 'primary.light', fontSize: '11px', fontWeight: 600, color: 'primary.main' }}
                                            >
                                                {emp.name?.charAt(0)?.toUpperCase() || 'E'}
                                            </Avatar>
                                            <Box sx={{ display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                                                <Typography sx={{ color: 'text.primary', fontSize: '12px', fontWeight: 600, lineHeight: 1.2 }}>{emp.name}</Typography>
                                            </Box>
                                        </Stack>
                                    </TableCell>
                                    <TableCell sx={{ color: 'text.primary', fontSize: '12px', py: 1.5 }}>{emp.email || '--'}</TableCell>
                                    <TableCell sx={{ py: 1.5 }}>
                                        <Box sx={{ display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                                            <Typography sx={{ color: 'text.secondary', fontSize: '10px', mt: 0.5 }}>{emp.designation || 'Staff'}</Typography>
                                        </Box>
                                    </TableCell>
                                    <TableCell>
                                        <Stack direction="row" spacing={1} alignItems="center">
                                            <Box sx={{ width: 8, height: 8, bgcolor: emp.status === 'Active' ? '#22c55e' : '#ef4444', borderRadius: '50%' }} />
                                            <Typography sx={{ color: 'text.primary', fontSize: '11px' }}>{emp.status}</Typography>
                                        </Stack>
                                    </TableCell>
                                    {isAdminOrAbove && (
                                        <TableCell align="right">
                                            <IconButton
                                                size="small"
                                                sx={{ color: 'text.secondary' }}
                                                onClick={(e) => handleOpenMenu(e, emp)}
                                            >
                                                <MoreVertical size={18} />
                                            </IconButton>
                                        </TableCell>
                                    )}
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                </TableContainer>

                {/* ── Pagination Footer — inside Paper, same as Designation ── */}
                {/* Pagination Footer — inside Paper */}
                <Box sx={{
                    p: 2,
                    display: 'flex',
                    flexWrap: 'wrap',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    gap: 2,
                    bgcolor: 'action.hover',
                    borderTop: '1px solid',
                    borderColor: 'divider'
                }}>
                    <Stack direction="row" spacing={1} alignItems="center">
                        <Typography sx={{ fontSize: '13px', color: 'text.secondary', whiteSpace: 'nowrap' }}>Show</Typography>
                        <Select
                            size="small"
                            value={10}
                            sx={{ color: 'text.primary', fontSize: '13px', height: 32, bgcolor: 'background.paper', '& .MuiSelect-select': { py: 0, px: 1 }, '& fieldset': { borderColor: 'divider' } }}
                        >
                            {[10, 25, 50, 100].map(v => <MenuItem key={v} value={v}>{v}</MenuItem>)}
                        </Select>
                        <Typography sx={{ fontSize: '13px', color: 'text.secondary', whiteSpace: 'nowrap' }}></Typography>
                    </Stack>

                    <Stack direction="row" spacing={2} alignItems="center">
                        <Typography sx={{ fontSize: '13px', color: 'text.secondary', whiteSpace: 'nowrap' }}>
                            Showing {filtered.length === 0 ? 0 : 1} to {filtered.length} of {filtered.length} entries
                        </Typography>
                        <Stack direction="row" spacing={1}>
                            <IconButton
                                disabled
                                sx={{ color: 'text.primary', bgcolor: 'action.hover', borderRadius: 1.5, '&.Mui-disabled': { color: 'text.disabled' } }}
                            >
                                <ChevronLeft size={16} />
                            </IconButton>
                            <Box sx={{ width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center', bgcolor: 'primary.main', borderRadius: 1.5, color: '#fff', fontSize: '13px', fontWeight: 600 }}>1</Box>
                            <IconButton
                                disabled
                                sx={{ color: 'text.primary', bgcolor: 'action.hover', borderRadius: 1.5, '&.Mui-disabled': { color: 'text.disabled' } }}
                            >
                                <ChevronRight size={16} />
                            </IconButton>
                        </Stack>
                    </Stack>
                </Box>
            </Paper>

            <Drawer
                anchor="right"
                open={isDrawerOpen}
                onClose={() => toggleDrawer(false)}
                disableScrollLock
                BackdropProps={{ sx: { backdropFilter: 'none' } }}
                sx={fs.drawer}
                PaperProps={{ sx: fs.drawerPaper }}
            >
                <AddEmployeeForm
                    onClose={() => toggleDrawer(false)}
                    organizationId={selectedOrgId}
                    organizationName={selectedOrgName}
                    editData={editEmployee}
                    onSaved={loadEmployees}
                />
            </Drawer>

            <Menu
                anchorEl={anchorEl}
                open={Boolean(anchorEl)}
                onClose={handleCloseMenu}
                PaperProps={{
                    sx: { bgcolor: 'background.paper', border: '1px solid', borderColor: 'divider', boxShadow: '0 8px 32px rgba(0,0,0,0.3)', '& .MuiMenuItem-root': { fontSize: '13px', gap: '12px', minHeight: '40px', '&:hover': { bgcolor: 'action.hover' } } }
                }}
            >
                <MenuItem onClick={handleEdit}>
                    <Edit size={14} color="#3b82f6" /> Edit
                </MenuItem>
                <MenuItem onClick={handleDelete} sx={{ color: '#ef4444' }}>
                    <Trash2 size={14} color="#ef4444" /> Delete
                </MenuItem>
            </Menu>

            <SuperAdminFieldsModal
                open={isSuperAdminFieldsModalOpen}
                onClose={() => setIsSuperAdminFieldsModalOpen(false)}
            />
            {/* Removed actions and Modals */}
        </Box >
    );
};

export default Employees;
