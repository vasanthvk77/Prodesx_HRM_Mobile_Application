import React, { useState, useEffect } from 'react';
import {
    Box, Paper, Typography, Stack, Button, Table, TableBody,
    TableCell, TableContainer, TableHead, TableRow, IconButton,
    CircularProgress, InputBase, Checkbox, Menu, MenuItem, Select, Chip, Avatar
} from '@mui/material';
import {
    Plus, Download, List, GitFork, Search, Filter, MoreVertical,
    ChevronLeft, ChevronRight, Eye, Trash2, ArrowUpDown
} from 'lucide-react';
import { fetchDepartments, deleteDepartment, bulkDeleteDepartments, fetchOrganizations, switchOrganization } from '../utils/api';
import CreateDepartmentModal from '../components/Forms/CreateDepartmentModal';
import toast from 'react-hot-toast';
import { getCurrentUser } from '../utils/auth';
import { Building2 } from 'lucide-react';
import * as signalR from '@microsoft/signalr';
import config from '../config';

/* theme-aware: no hardcoded colors */

export default function Department() {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [viewMode, setViewMode] = useState('list'); // 'list' or 'hierarchy'
    const [page, setPage] = useState(1);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    // Modal state
    const [modalOpen, setModalOpen] = useState(false);
    const [editData, setEditData] = useState(null);

    // Action menu state
    const [anchorEl, setAnchorEl] = useState(null);
    const [selectedItem, setSelectedItem] = useState(null);

    // Organization state
    const [organizations, setOrganizations] = useState([]);
    const [selectedOrgId, setSelectedOrgId] = useState(null);
    const [selectedOrgName, setSelectedOrgName] = useState('');

    // Selection & Table State
    const [selectedIds, setSelectedIds] = useState([]);
    const [sortConfig, setSortConfig] = useState({ key: 'departmentName', direction: 'asc' });
    const [parentFilter, setParentFilter] = useState('All');

    const user = getCurrentUser();
    const userRole = user?.role || 'User';
    const isAdminOrAbove = userRole === 'Admin' || userRole === 'SuperAdmin';
    const currentOrgIdFromToken = user?.organizationId;

    // Fetch organizations
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

    const load = React.useCallback(async () => {
        try {
            setLoading(true);
            const response = await fetchDepartments(selectedOrgId);
            setData(Array.isArray(response) ? response : []);
        } catch (error) {
            toast.error('Failed to load departments');
        } finally {
            setLoading(false);
        }
    }, [selectedOrgId]);

    useEffect(() => {
        if (selectedOrgId) load();
    }, [selectedOrgId, load]);

    const loadRef = React.useRef(load);
    useEffect(() => {
        loadRef.current = load;
    }, [load]);

    // SignalR Setup
    useEffect(() => {
        let isStopped = false;
        const connection = new signalR.HubConnectionBuilder()
            .withUrl(`${config.SOCKET_URL}/hubs/departments`)
            .withAutomaticReconnect()
            .build();

        const start = async () => {
            try {
                await connection.start();
                if (!isStopped) {
                    console.log('Connected to DepartmentHub');
                    connection.on('ReceiveDepartmentUpdate', () => {
                        loadRef.current();
                    });
                } else {
                    await connection.stop();
                }
            } catch (err) {
                if (!isStopped) {
                    console.error('SignalR Connection Error: ', err);
                }
            }
        };

        start();

        return () => {
            isStopped = true;
            if (connection.state === signalR.HubConnectionState.Connected ||
                connection.state === signalR.HubConnectionState.Connecting ||
                connection.state === signalR.HubConnectionState.Reconnecting) {
                connection.stop().catch(() => { });
            }
        };
    }, []); // Run once on mount

    const handleAdd = () => {
        setEditData(null);
        setModalOpen(true);
    };

    const handleEdit = (item) => {
        setEditData(item);
        setModalOpen(true);
        handleMenuClose();
    };

    const handleDeleteClick = async (id) => {
        if (!window.confirm('Are you sure you want to delete this department?')) return;
        try {
            await deleteDepartment(id);
            toast.success('Department deleted');
            load();
        } catch (error) {
            toast.error('Failed to delete');
        }
        handleMenuClose();
    };

    const handleBulkDelete = async () => {
        if (!window.confirm(`Are you sure you want to delete ${selectedIds.length} departments?`)) return;
        try {
            await bulkDeleteDepartments(selectedIds);
            toast.success('Departments deleted');
            setSelectedIds([]);
            load();
        } catch (error) {
            toast.error('Failed to delete departments');
        }
    };

    const handleSelectAll = (e) => {
        if (e.target.checked) {
            setSelectedIds(filteredData.map(d => d.id));
        } else {
            setSelectedIds([]);
        }
    };

    const handleSelectOne = (id) => {
        setSelectedIds(prev =>
            prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
        );
    };

    const handleSort = (key) => {
        setSortConfig(prev => ({
            key,
            direction: prev.key === key && prev.direction === 'asc' ? 'desc' : 'asc'
        }));
    };

    const SortIcon = ({ columnKey }) => {
        const isActive = sortConfig.key === columnKey;
        return (
            <ArrowUpDown
                size={12}
                style={{
                    marginLeft: '4px',
                    opacity: isActive ? 1 : 0.5,
                    color: isActive ? 'white' : 'inherit'
                }}
            />
        );
    };

    const handleMenuOpen = (event, item) => {
        setAnchorEl(event.currentTarget);
        setSelectedItem(item);
    };

    const handleMenuClose = () => {
        setAnchorEl(null);
        setSelectedItem(null);
    };

    const handleOrgChange = async (e) => {
        const id = parseInt(e.target.value);
        if (id === selectedOrgId) return;

        try {
            const loadingToast = toast.loading('Switching organization...');
            await switchOrganization(id);

            const org = organizations.find(o => o.id === id);
            setSelectedOrgId(id);
            setSelectedOrgName(org?.name || '');

            toast.success(`Switched to ${org?.name}`, { id: loadingToast });
        } catch (error) {
            toast.error('Failed to switch organization');
        }
    };

    const filteredData = data
        .filter(d => {
            const matchesSearch = d.departmentName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                d.parentDepartmentName?.toLowerCase().includes(searchTerm.toLowerCase());
            const matchesParent = parentFilter === 'All' || d.parentDepartmentName === parentFilter || (!d.parentDepartmentName && parentFilter === 'None');
            return matchesSearch && matchesParent;
        })
        .sort((a, b) => {
            if (!sortConfig.key) return 0;
            const aVal = (a[sortConfig.key] || '').toString().toLowerCase();
            const bVal = (b[sortConfig.key] || '').toString().toLowerCase();
            if (aVal < bVal) return sortConfig.direction === 'asc' ? -1 : 1;
            if (aVal > bVal) return sortConfig.direction === 'asc' ? 1 : -1;
            return 0;
        });

    const parentOptions = ['All', 'None', ...new Set(data.map(d => d.parentDepartmentName).filter(p => p))];

    const paginatedData = filteredData.slice((page - 1) * rowsPerPage, page * rowsPerPage);

    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>


            {/* ── Search & Filter Bar ── */}
            <Box sx={{
                display: 'flex',
                flexDirection: { xs: 'column', md: 'row' },
                gap: 1.5,
                bgcolor: 'background.paper',
                p: 1.5,
                borderRadius: 2,
                border: '1px solid',
                borderColor: 'divider',
                alignItems: { xs: 'stretch', md: 'center' }
            }}>
                {/* Organization Selector */}
                <Stack direction="row" spacing={1} alignItems="center" sx={{
                    borderRight: { md: '1px solid' },
                    borderColor: 'divider',
                    pr: { md: 2 },
                    pb: { xs: 1, md: 0 },
                    borderBottom: { xs: '1px solid', md: 'none' }
                }}>
                    <Building2 size={14} color="#94a3b8" />
                    <Typography sx={{ color: 'text.secondary', fontSize: '13px', whiteSpace: 'nowrap' }}>Organization</Typography>
                    {organizations.length === 1 ? (
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
                                height: 32,
                                color: 'text.primary',
                                fontSize: '13px',
                                '& .MuiOutlinedInput-notchedOutline': { border: 'none' },
                                bgcolor: 'action.hover',
                                borderRadius: 1,
                                minWidth: 100
                            }}
                        >
                            {organizations.map(org => (
                                <MenuItem key={org.id} value={org.id}>
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

                <Box sx={{
                    flex: 1,
                    display: 'flex',
                    alignItems: 'center',
                    bgcolor: 'action.hover',
                    px: 1.5,
                    py: 0.75,
                    borderRadius: 1.5,
                    border: '1px solid',
                    borderColor: 'divider',
                }}>
                    <Search size={16} color="#64748b" style={{ marginRight: '10px' }} />
                    <InputBase
                        placeholder="Start typing to search"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        sx={{ color: 'text.primary', fontSize: '13px', width: '100%' }}
                    />
                </Box>
                <Box sx={{
                    display: 'flex',
                    alignItems: 'center',
                    bgcolor: 'action.hover',
                    px: 1.5,
                    height: 40,
                    borderRadius: 1.5,
                    border: '1px solid',
                    borderColor: 'divider',
                }}>
                    <Filter size={14} color="#64748b" />
                    <Typography sx={{ color: 'text.secondary', fontSize: '12px', ml: 1, mr: 1, whiteSpace: 'nowrap' }}>Parent Department:</Typography>
                    <Select
                        value={parentFilter}
                        onChange={(e) => setParentFilter(e.target.value)}
                        size="small"
                        sx={{
                            height: 24,
                            color: 'text.primary',
                            fontSize: '13px',
                            '& .MuiOutlinedInput-notchedOutline': { border: 'none' },
                            '& .MuiSelect-select': { py: 0, pl: 0 }
                        }}
                    >
                        {parentOptions.map(opt => (
                            <MenuItem key={opt} value={opt}>{opt}</MenuItem>
                        ))}
                    </Select>
                </Box>
            </Box>

            {/* ── Action Toolbar ── */}
            <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} justifyContent="space-between" alignItems={{ xs: 'stretch', md: 'center' }}>
                <Stack direction="row" spacing={1.5}>
                    {isAdminOrAbove && (
                        <Button
                            variant="contained"
                            startIcon={<Plus size={18} />}
                            onClick={handleAdd}
                            sx={{
                                textTransform: 'none',
                                fontSize: '13px',
                                fontWeight: 600,
                                bgcolor: '#3182ce',
                                '&:hover': { bgcolor: '#2b6cb0' },
                                px: 2,
                                borderRadius: 1.5
                            }}
                        >
                            Add Department
                        </Button>
                    )}
                    {isAdminOrAbove && selectedIds.length > 0 && (
                        <Button
                            variant="contained"
                            startIcon={<Trash2 size={18} />}
                            onClick={handleBulkDelete}
                            sx={{
                                textTransform: 'none',
                                fontSize: '13px',
                                fontWeight: 600,
                                bgcolor: '#fc8181',
                                '&:hover': { bgcolor: '#f56565' },
                                px: 2,
                                borderRadius: 1.5
                            }}
                        >
                            Delete ({selectedIds.length})
                        </Button>
                    )}
                    <Button
                        variant="outlined"
                        startIcon={<Download size={18} />}
                        sx={{
                            textTransform: 'none',
                            fontSize: '13px',
                            fontWeight: 600,
                            borderColor: 'divider',
                            color: 'text.secondary',
                            '&:hover': { borderColor: 'primary.main', color: 'primary.main' },
                            px: 2,
                            borderRadius: 1.5
                        }}
                    >
                        Export
                    </Button>
                </Stack>

                <Stack direction="row" sx={{ bgcolor: 'action.hover', borderRadius: 1.5, p: 0.5 }}>
                    <IconButton onClick={() => setViewMode('list')} sx={{ color: viewMode === 'list' ? 'primary.main' : 'text.secondary', bgcolor: viewMode === 'list' ? 'rgba(59,130,246,0.15)' : 'transparent', borderRadius: 1.25, p: 1 }}><List size={20} /></IconButton>
                    <IconButton onClick={() => setViewMode('hierarchy')} sx={{ color: viewMode === 'hierarchy' ? 'primary.main' : 'text.secondary', bgcolor: viewMode === 'hierarchy' ? 'rgba(59,130,246,0.15)' : 'transparent', borderRadius: 1.25, p: 1 }}><GitFork size={20} /></IconButton>
                </Stack>
            </Stack>

            {/* ── Main Table ── */}
            <Paper elevation={0} sx={{ bgcolor: 'background.paper', border: '1px solid', borderColor: 'divider', borderRadius: 2, overflow: 'hidden' }}>
                <TableContainer>
                    <Table>
                        <TableHead>
                            <TableRow sx={{ '& th': { bgcolor: 'action.hover' } }}>
                                <TableCell padding="checkbox">
                                    <Checkbox
                                        size="small"
                                        sx={{ color: 'divider', '&.Mui-checked': { color: 'primary.main' } }}
                                        checked={paginatedData.length > 0 && selectedIds.length === paginatedData.length}
                                        indeterminate={selectedIds.length > 0 && selectedIds.length < paginatedData.length}
                                        onChange={handleSelectAll}
                                    />
                                </TableCell>
                                <TableCell
                                    sx={{ color: 'text.secondary', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', py: 1.5, borderBottom: '1px solid', borderColor: 'divider', cursor: 'pointer' }}
                                    onClick={() => handleSort('departmentName')}
                                >
                                    <Stack direction="row" alignItems="center">
                                        Name
                                        <SortIcon columnKey="departmentName" />
                                    </Stack>
                                </TableCell>
                                <TableCell
                                    sx={{ color: 'text.secondary', fontSize: '12px', fontWeight: 600, py: 1.5, borderBottom: '1px solid', borderColor: 'divider', cursor: 'pointer' }}
                                    onClick={() => handleSort('parentDepartmentName')}
                                >
                                    <Stack direction="row" alignItems="center">
                                        Parent Department
                                        <SortIcon columnKey="parentDepartmentName" />
                                    </Stack>
                                </TableCell>
                                {isAdminOrAbove && (
                                    <TableCell align="right" sx={{ color: 'text.secondary', fontSize: '12px', fontWeight: 600, py: 1.5, borderBottom: '1px solid', borderColor: 'divider' }}>
                                        Action
                                    </TableCell>
                                )}
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow>
                                    <TableCell colSpan={4} align="center" sx={{ py: 8 }}>
                                        <CircularProgress size={24} sx={{ color: '#3182ce' }} />
                                    </TableCell>
                                </TableRow>
                            ) : paginatedData.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={4} align="center" sx={{ py: 6, color: 'text.secondary', fontSize: '14px' }}>
                                        No departments found.
                                    </TableCell>
                                </TableRow>
                            ) : paginatedData.map((d) => (
                                <TableRow key={d.id} sx={{ bgcolor: selectedIds.includes(d.id) ? 'rgba(59,130,246,0.06)' : 'transparent', '&:hover': { bgcolor: 'action.hover' }, '& td': { borderColor: 'divider' } }}>
                                    <TableCell padding="checkbox">
                                        <Checkbox
                                            size="small"
                                            sx={{ color: 'divider', '&.Mui-checked': { color: 'primary.main' } }}
                                            checked={selectedIds.includes(d.id)}
                                            onChange={() => handleSelectOne(d.id)}
                                        />
                                    </TableCell>
                                    <TableCell sx={{ color: 'text.primary', fontSize: '13px', py: 1.5 }}>{d.departmentName}</TableCell>
                                    <TableCell sx={{ color: 'text.secondary', fontSize: '13px', py: 1.5 }}>{d.parentDepartmentName || '-'}</TableCell>
                                    {isAdminOrAbove && (
                                        <TableCell align="right" sx={{ py: 1.5 }}>
                                            <Stack direction="row" spacing={0.5} justifyContent="flex-end">
                                                <Button
                                                    size="small"
                                                    variant="outlined"
                                                    onClick={() => handleEdit(d)}
                                                    sx={{
                                                        textTransform: 'none', fontSize: '12px',
                                                        color: 'text.secondary', borderColor: 'divider',
                                                        '&:hover': { bgcolor: 'action.hover', borderColor: 'primary.main', color: 'primary.main' }
                                                    }}>View</Button>
                                                <IconButton size="small" sx={{ color: 'text.secondary' }} onClick={(e) => handleMenuOpen(e, d)}><MoreVertical size={16} /></IconButton>
                                            </Stack>
                                        </TableCell>
                                    )}
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                </TableContainer>

                {/* ── Pagination Footer ── */}
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
                            value={rowsPerPage}
                            onChange={(e) => setRowsPerPage(e.target.value)}
                            sx={{ color: 'text.primary', fontSize: '13px', height: 32, bgcolor: 'action.hover', '& .MuiSelect-select': { py: 0, px: 1 }, '& fieldset': { borderColor: 'divider' } }}
                        >
                            {[10, 25, 50, 100].map(v => <MenuItem key={v} value={v}>{v}</MenuItem>)}
                        </Select>
                        <Typography sx={{ fontSize: '13px', color: 'text.secondary' }}></Typography>
                    </Stack>

                    <Stack direction="row" spacing={2} alignItems="center">
                        <Typography sx={{ fontSize: '13px', color: 'text.secondary', whiteSpace: 'nowrap' }}>
                            Showing {((page - 1) * rowsPerPage) + 1} to {Math.min(page * rowsPerPage, filteredData.length)} of {filteredData.length} entries
                        </Typography>
                        <Stack direction="row" spacing={1}>
                            <IconButton
                                disabled={page === 1}
                                onClick={() => setPage(p => p - 1)}
                                sx={{ color: 'text.primary', bgcolor: 'action.hover', borderRadius: 1.5, '&.Mui-disabled': { color: 'text.disabled' } }}
                            >
                                <ChevronLeft size={16} />
                            </IconButton>
                            <Box sx={{
                                width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center',
                                bgcolor: 'primary.main', borderRadius: 1.5, color: '#fff', fontSize: '13px', fontWeight: 600
                            }}>
                                {page}
                            </Box>
                            <IconButton
                                disabled={page * rowsPerPage >= filteredData.length}
                                onClick={() => setPage(p => p + 1)}
                                sx={{ color: 'text.primary', bgcolor: 'action.hover', borderRadius: 1.5, '&.Mui-disabled': { color: 'text.disabled' } }}
                            >
                                <ChevronRight size={16} />
                            </IconButton>
                        </Stack>
                    </Stack>
                </Box>
            </Paper>

            {/* ── Action Menu ── */}
            <Menu anchorEl={anchorEl} open={Boolean(anchorEl)} onClose={handleMenuClose}
                PaperProps={{ sx: { bgcolor: 'background.paper', border: '1px solid', borderColor: 'divider', boxShadow: '0 8px 24px rgba(0,0,0,0.25)', '& .MuiMenuItem-root': { color: 'text.primary', fontSize: '13px', '&:hover': { bgcolor: 'action.hover' } } } }}
            >
                <MenuItem onClick={() => handleEdit(selectedItem)}>Edit</MenuItem>
                <MenuItem onClick={() => handleDeleteClick(selectedItem?.id)} sx={{ color: '#fc8181 !important' }}>Delete</MenuItem>
            </Menu>

            {/* ── Create/Edit Modal ── */}
            <CreateDepartmentModal
                open={modalOpen}
                onClose={() => setModalOpen(false)}
                onSaved={load}
                editData={editData}
                organizationId={selectedOrgId}
                organizationName={selectedOrgName}
            />
        </Box>
    );
}
