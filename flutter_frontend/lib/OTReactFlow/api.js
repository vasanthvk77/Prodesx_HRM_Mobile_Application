import axios from 'axios';
import config from '../config';

const API_BASE_URL = config.API_BASE_URL;

const api = axios.create({
    baseURL: API_BASE_URL,
    headers: {
        'Content-Type': 'application/json',
    },
});

// Add a request interceptor to include the JWT token
api.interceptors.request.use((config) => {
    const token = localStorage.getItem('token');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
}, (error) => {
    return Promise.reject(error);
});

// Add a response interceptor to handle Token Expiry (401)
api.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response && error.response.status === 401) {
            console.error('[API] 401 Unauthorized — Session Expired');
            localStorage.removeItem('token');
            // Redirect to login ONLY if not already on a guest page
            if (typeof window !== 'undefined') {
                const path = window.location.pathname;
                if (path !== '/' && path !== '/login' && path !== '/forget-password') {
                    window.location.href = '/login';
                }
            }
        }
        return Promise.reject(error);
    }
);

export const fetchLeads = async () => {
    try {
        const response = await api.get('/leads');
        return response.data;
    } catch (error) {
        console.error('Error fetching leads:', error);
        return [];
    }
};

export const createLead = async (lead) => {
    try {
        const response = await api.post('/leads', lead);
        return response.data;
    } catch (error) {
        console.error('Error creating lead:', error);
        throw error;
    }
};

export const updateLead = async (lead) => {
    try {
        const response = await api.put('/leads', lead);
        return response.data;
    } catch (error) {
        console.error('Error updating lead:', error);
        throw error;
    }
};

export const deleteLead = async (id) => {
    try {
        const response = await api.delete(`/leads/${id}`);
        return response.data;
    } catch (error) {
        console.error('Error deleting lead:', error);
        throw error;
    }
};

export const login = async (email, password) => {
    try {
        const response = await api.post('/auth/login', { email, password });
        return response.data;
    } catch (error) {
        console.error('Login error:', error);
        throw error;
    }
};

// Organization Calendar Settings
export const fetchCalendarSettings = async (organizationId) => {
    try {
        const response = await api.get('/organizationcalendarsettings', { params: { organizationId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching calendar settings:', error);
        throw error;
    }
};

export const saveCalendarSettings = async (settings) => {
    try {
        const response = await api.post('/organizationcalendarsettings', settings);
        return response.data;
    } catch (error) {
        console.error('Error saving calendar settings:', error);
        throw error;
    }
};

export const switchOrganization = async (organizationId) => {
    try {
        const response = await api.post(`/auth/switch-organization?organizationId=${organizationId}`);
        // The backend returns { token: "..." }
        if (response.data.token) {
            localStorage.setItem('token', response.data.token);
            localStorage.setItem('last_selected_org_id', organizationId); // PERSIST GLOBAL CHOICE
            // Dispatch event so other components (like Sidebar) know to refresh
            window.dispatchEvent(new CustomEvent('org-switched'));
        }
        return response.data;
    } catch (error) {
        console.error('Switch organization error:', error);
        throw error;
    }
};

export const register = async (email, password) => {
    try {
        const response = await api.post('/auth/register', { email, password });
        return response.data;
    } catch (error) {
        console.error('Registration error:', error);
        throw error;
    }
};

// ── Deals ────────────────────────────────────────────────────────────────────

export const fetchDeals = async () => {
    try {
        const response = await api.get('/DealForm');
        return response.data;
    } catch (error) {
        console.error('Error fetching deals:', error);
        throw error;
    }
};

export const createDeal = async (deal) => {
    try {
        const response = await api.post('/DealForm', deal);
        return response.data;
    } catch (error) {
        console.error('Error creating deal:', error);
        throw error;
    }
};

export const updateDeal = async (id, deal) => {
    try {
        const response = await api.put(`/DealForm/${id}`, deal);
        return response.data;
    } catch (error) {
        console.error('Error updating deal:', error);
        throw error;
    }
};

export const deleteDeal = async (id) => {
    try {
        const response = await api.delete(`/DealForm/${id}`);
        return response.data;
    } catch (error) {
        console.error('Error deleting deal:', error);
        throw error;
    }
};

export const updateDealStage = async (id, deal) => {
    try {
        const response = await api.put(`/DealForm/${id}`, deal);
        return response.data;
    } catch (error) {
        console.error('Error updating deal stage:', error);
        throw error;
    }
};

// ── User Management ───────────────────────────────────────────────────────────

export const fetchUsers = async () => {
    const response = await api.get('/users');
    return response.data;
};

export const fetchRoles = async () => {
    const response = await api.get('/users/roles');
    return response.data;
};

export const fetchOrganizations = async () => {
    // We try dedicated endpoint first, then fallback to users/organizations if needed
    try {
        const response = await api.get('/organizations');
        return response.data;
    } catch {
        const response = await api.get('/users/organizations');
        return response.data;
    }
};

export const createOrganization = async (orgData) => {
    const formData = new FormData();
    Object.keys(orgData).forEach(key => {
        if (orgData[key] != null) formData.append(key, orgData[key]);
    });
    const response = await api.post('/organizations', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
    });
    return response.data;
};

export const updateOrganization = async (id, orgData) => {
    const formData = new FormData();
    Object.keys(orgData).forEach(key => {
        if (orgData[key] != null) formData.append(key, orgData[key]);
    });
    const response = await api.put(`/organizations/${id}`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
    });
    return response.data;
};

export const deleteOrganization = async (id) => {
    const response = await api.delete(`/organizations/${id}`);
    return response.data;
};

export const createUser = async (userData) => {
    const response = await api.post('/users', userData);
    return response.data;
};

export const grantOrgAccess = async (userId, organizationId, roleId) => {
    const response = await api.put(`/users/${userId}/access`, { organizationId, roleId });
    return response.data;
};

export const revokeOrgAccess = async (userId, orgId) => {
    const response = await api.delete(`/users/${userId}/access/${orgId}`);
    return response.data;
};

export const deleteUser = async (userId) => {
    const response = await api.delete(`/users/${userId}`);
    return response.data;
};

// ── Designations ─────────────────────────────────────────────────────────────

export const fetchDesignations = async (organizationId = null) => {
    try {
        const params = { params: { ...(organizationId ? { organizationId } : {}), _t: Date.now() } };
        const response = await api.get('/designations', params);
        return response.data;
    } catch (error) {
        console.error('[API] Error fetching designations:', error.response?.data || error.message);
        throw error;
    }
};

export const createDesignation = async (designationData) => {
    try {
        const response = await api.post('/designations', designationData);
        console.log('[API] CreateDesignation response:', response.data);
        return response.data;
    } catch (error) {
        console.error('[API] CreateDesignation error:', error.response?.data || error.message);
        throw error;
    }
};

export const updateDesignation = async (id, designationData) => {
    try {
        const response = await api.put(`/designations/${id}`, designationData);
        console.log('[API] UpdateDesignation response:', response.data);
        return response.data;
    } catch (error) {
        console.error('[API] UpdateDesignation error:', error.response?.data || error.message);
        throw error;
    }
};

export const deleteDesignation = async (id) => {
    try {
        const response = await api.delete(`/designations/${id}`);
        return response.data;
    } catch (error) {
        console.error('[API] Error deleting designation:', error.response?.data || error.message);
        throw error;
    }
};

export const bulkDeleteDesignations = async (ids) => {
    try {
        const response = await api.post('/designations/bulk-delete', ids);
        return response.data;
    } catch (error) {
        console.error('[API] Error bulk deleting designations:', error.response?.data || error.message);
        throw error;
    }
};


// ── Departments ───────────────────────────────────────────────────────────────

export const fetchDepartments = async (organizationId) => {
    const response = await api.get('/departments', { params: { organizationId, _t: Date.now() } });
    return response.data;
};

export const createDepartment = async (data) => {
    const response = await api.post('/departments', data);
    return response.data;
};

export const updateDepartment = async (id, data) => {
    const response = await api.put(`/departments/${id}`, data);
    return response.data;
};

export const deleteDepartment = async (id) => {
    const response = await api.delete(`/departments/${id}`);
    return response.data;
};

export const bulkDeleteDepartments = async (ids) => {
    const response = await api.post('/departments/bulk-delete', ids);
    return response.data;
};
// ── Employees ────────────────────────────────────────────────────────────────

export const fetchEmployees = async (organizationId = null) => {
    // CLEVER: We no longer send organizationId as a query param. 
    // The backend extracts it from the JWT's "OrganizationId" claim for security and efficiency.
    const params = { params: { _t: Date.now() } };
    const response = await api.get('/employees', params);
    return response.data;
};

export const exportEmployees = async (type, employeeIds = [], organizationId = null, form = null) => {
    try {
        // PII (IDs) moved from URL to Request Body (POST)
        const response = await api.post(`/employees/export-${type}`, 
            { organizationId, employeeIds, form }, 
            { responseType: 'blob' }
        );
        
        // Handle download blob
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        const extension = type === 'excel' ? 'xlsx' : 'pdf';
        link.setAttribute('download', `Employees_${new Date().toISOString().split('T')[0]}.${extension}`);
        document.body.appendChild(link);
        link.click();
        link.remove();
        window.URL.revokeObjectURL(url);
    } catch (error) {
        console.error(`Error exporting employees to ${type}:`, error);
        throw error;
    }
};

// ── Mustor Roll (Form A) ─────────────────────────────────────────────────────

export const fetchMustorRolls = async (organizationId = null) => {
    const params = { params: { ...(organizationId ? { organizationId } : {}), _t: Date.now() } };
    const response = await api.get('/MustorRoll', params);
    return response.data;
};

export const createMustorRoll = async (payload) => {
    const response = await api.post('/MustorRoll', payload);
    return response.data;
};

export const updateMustorRoll = async (id, payload) => {
    const response = await api.put(`/MustorRoll/${id}`, payload);
    return response.data;
};

export const deleteMustorRoll = async (id, organizationId = null) => {
    const params = { params: { ...(organizationId ? { organizationId } : {}) } };
    const response = await api.delete(`/MustorRoll/${id}`, params);
    return response.data;
};

export const fetchUnlinkedUsers = async () => {
    const response = await api.get('/employees/unlinked-users');
    return response.data;
};

export const createEmployee = async (employeeData) => {
    try {
        const response = await api.post('/employees', employeeData);
        console.log('[API] CreateEmployee response:', response.data);
        return response.data;
    } catch (error) {
        console.error('[API] CreateEmployee error:', error.response?.data || error.message);
        throw error;
    }
};

export const updateEmployee = async (id, employeeData) => {
    const response = await api.put(`/employees/${id}`, employeeData);
    return response.data;
};

export const deleteEmployee = async (id) => {
    try {
        console.log('[API] Deleting employee:', id);
        const response = await api.delete(`/employees/${id}`);
        console.log('[API] DeleteEmployee response:', response.data);
        return response.data;
    } catch (error) {
        console.error('[API] DeleteEmployee error:', {
            status: error.response?.status,
            statusText: error.response?.statusText,
            message: error.response?.data?.message || error.message,
            data: error.response?.data
        });
        throw error;
    }
};

export const uploadEmployeePhoto = async (employeeId, file) => {
    const form = new FormData();
    form.append('file', file);
    try {
        console.log('[API] Uploading photo for employee:', employeeId, 'File size:', file.size, 'Type:', file.type);
        const response = await api.post(`/employees/${employeeId}/photo`, form, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        console.log('[API] Photo upload response:', response.data);
        return response.data;
    } catch (error) {
        console.error('[API] Photo upload error:', error.response?.data || error.message);
        throw error;
    }
};
export const deleteEmployeePhoto = async (employeeId) => {
    try {
        console.log('[API] Removing photo for employee:', employeeId);
        const response = await api.delete(`/employees/${employeeId}/photo`);
        return response.data;
    } catch (error) {
        console.error('[API] Photo delete error:', error.response?.data || error.message);
        throw error;
    }
};
export const requestOtp = async (email) => {
    try {
        const response = await api.post('/ForgetPassword/request-otp', { email });
        return response.data;
    } catch (error) {
        console.error('Request OTP error:', error);
        throw error;
    }
};

export const verifyOtp = async (email, otp) => {
    try {
        const response = await api.post('/ForgetPassword/verify-otp', { email, otp });
        return response.data;
    } catch (error) {
        console.error('Verify OTP error:', error);
        throw error;
    }
};

export const resetPassword = async (email, newPassword) => {
    try {
        const response = await api.post('/ForgetPassword/reset-password', { email, newPassword });
        return response.data;
    } catch (error) {
        console.error('Reset password error:', error);
        throw error;
    }
};

// ── Shift Management ─────────────────────────────────────────────────────────

export const fetchShiftTemplates = async (orgId) => {
    try {
        const response = await api.get('/ShiftAssignments/templates', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching shift templates:', error);
        throw error;
    }
};

export const createShiftTemplate = async (template, orgId) => {
    try {
        const response = await api.post('/ShiftAssignments/templates', template, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error creating shift template:', error);
        throw error;
    }
};

export const updateShiftTemplate = async (id, template, orgId) => {
    try {
        const response = await api.put(`/ShiftAssignments/templates/${id}`, template, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error updating shift template:', error);
        throw error;
    }
};

export const deleteShiftTemplate = async (id, orgId) => {
    try {
        const response = await api.delete(`/ShiftAssignments/templates/${id}`, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error deleting shift template:', error);
        throw error;
    }
};

export const fetchShiftAssignments = async (orgId) => {
    try {
        const response = await api.get('/ShiftAssignments', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching shift assignments:', error);
        throw error;
    }
};

export const upsertShiftAssignment = async (assignment, orgId) => {
    try {
        const response = await api.post('/ShiftAssignments', assignment, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error upserting shift assignment:', error);
        throw error;
    }
};

export const removeShiftAssignment = async (employeeId, orgId) => {
    try {
        const response = await api.delete(`/ShiftAssignments/employee/${employeeId}`, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error removing shift assignment:', error);
        throw error;
    }
};

export const fetchMonthlyRoster = async (start, end, orgId) => {
    try {
        const response = await api.get('/ShiftAssignments/roster', { params: { start, end, orgId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching roster:', error);
        throw error;
    }
};

export const upsertDailySchedule = async (schedule, orgId) => {
    try {
        const response = await api.post('/ShiftAssignments/schedule', schedule, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error upserting daily schedule:', error);
        throw error;
    }
};

export const removeDailySchedule = async (employeeId, date, orgId) => {
    try {
        const response = await api.delete(`/ShiftAssignments/schedule/${employeeId}`, { params: { date, orgId } });
        return response.data;
    } catch (error) {
        console.error('Error removing daily schedule:', error);
        throw error;
    }
};

export const fetchEmployeeFields = async (organizationId = null) => {
    try {
        const response = await api.get('/DynamicForm/employee-fields', { params: { organizationId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching employee fields:', error);
        throw error;
    }
};

export const updateEmployeeFields = async (payload) => {
    try {
        const response = await api.post('/DynamicForm/update-fields', payload);
        return response.data;
    } catch (error) {
        console.error('Error updating employee fields:', error);
        throw error;
    }
};

export const createMasterField = async (payload) => {
    try {
        const response = await api.post('/DynamicForm/create-field', payload);
        return response.data;
    } catch (error) {
        console.error('Error creating master field:', error);
        throw error;
    }
};

export const deleteMasterField = async (id) => {
    try {
        const response = await api.delete(`/DynamicForm/delete-field/${id}`);
        return response.data;
    } catch (error) {
        console.error('Error deleting master field:', error);
        throw error;
    }
};

// ── Employee Bank Details ──────────────────────────────────────────────────────

export const fetchEmployeeBankDetails = async (employeeId) => {
    try {
        const response = await api.get(`/employees/${employeeId}/bank-details`);
        return response.data;
    } catch (error) {
        console.error('Error fetching bank details:', error);
        throw error;
    }
};

export const saveEmployeeBankDetails = async (employeeId, payload) => {
    try {
        const response = await api.post(`/employees/${employeeId}/bank-details`, payload);
        return response.data;
    } catch (error) {
        console.error('Error saving bank details:', error);
        throw error;
    }
};

// ── Employee Signature ────────────────────────────────────────────────────────

export const uploadEmployeeSignature = async (employeeId, file) => {
    try {
        const formData = new FormData();
        formData.append('file', file);
        const response = await api.post(`/employees/${employeeId}/signature`, formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        return response.data;
    } catch (error) {
        console.error('Error uploading signature:', error);
        throw error;
    }
};

export const deleteEmployeeSignature = async (employeeId) => {
    try {
        const response = await api.delete(`/employees/${employeeId}/signature`);
        return response.data;
    } catch (error) {
        console.error('Error deleting signature:', error);
        throw error;
    }
};

// ── Modules Management ────────────────────────────────────────────────────────

export const fetchOrganizationModules = async (organizationId = null) => {
    try {
        const response = await api.get('/Modules', { params: { organizationId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching organization modules:', error);
        throw error;
    }
};

export const toggleOrganizationModule = async (payload) => {
    try {
        const response = await api.post('/Modules/toggle', payload);
        return response.data;
    } catch (error) {
        console.error('Error toggling organization module:', error);
        throw error;
    }
};

// ── Holiday Management (Form VI) ────────────────────────────────────────────

export const fetchHolidays = async (organizationId = null) => {
    try {
        const response = await api.get('/holidays', { params: { organizationId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching holidays:', error);
        return [];
    }
};

export const getHolidayById = async (id) => {
    try {
        const response = await api.get(`/holidays/${id}`);
        return response.data;
    } catch (error) {
        console.error('Error fetching holiday:', error);
        throw error;
    }
};

export const createHoliday = async (holiday) => {
    try {
        const response = await api.post('/holidays', holiday);
        return response.data;
    } catch (error) {
        console.error('Error creating holiday:', error);
        throw error;
    }
};

export const updateHoliday = async (id, holiday) => {
    try {
        const response = await api.put(`/holidays/${id}`, holiday);
        return response.data;
    } catch (error) {
        console.error('Error updating holiday:', error);
        throw error;
    }
};

export const deleteHoliday = async (id) => {
    try {
        const response = await api.delete(`/holidays/${id}`);
        return response.data;
    } catch (error) {
        console.error('Error deleting holiday:', error);
        throw error;
    }
};

export const exportHolidaysToExcel = async (organizationId = null, filters = {}) => {
    try {
        const response = await api.post('/holidays/export-excel', { 
            organizationId, ...filters 
        }, {
            responseType: 'blob'
        });
        return response;
    } catch (error) {
        console.error('Error exporting holidays to excel:', error);
        throw error;
    }
};

export const exportHolidaysToPdf = async (organizationId = null, filters = {}) => {
    try {
        const response = await api.post('/holidays/export-pdf', { 
            organizationId, ...filters 
        }, {
            responseType: 'blob'
        });
        return response;
    } catch (error) {
        console.error('Error exporting holidays to pdf:', error);
        throw error;
    }
};

export const bulkUpdateHolidayStatus = async (payload) => {
    try {
        const response = await api.post('/holidays/bulk-update-status', payload);
        return response.data;
    } catch (error) {
        console.error('Error in bulk holiday status update:', error);
        throw error;
    }
};

export const fetchEmployeeHolidayStatuses = async (holidayId) => {
    try {
        const response = await api.get('/holidays/employee-statuses', { params: { holidayId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching holiday statuses:', error);
        throw error;
    }
};
// ── Dangerous Occurrences ──────────────────────────────────────────────────

export const fetchDangerousOccurrences = async (orgId, year, fromDate, toDate) => {
    try {
        const response = await api.get('/DangerousOccurrences', { params: { orgId, year, fromDate, toDate } });
        return response.data;
    } catch (error) {
        console.error('Error fetching dangerous occurrences:', error);
        throw error;
    }
};

export const createDangerousOccurrence = async (payload) => {
    try {
        const response = await api.post('/DangerousOccurrences', payload);
        return response.data;
    } catch (error) {
        console.error('Error creating dangerous occurrence:', error);
        throw error;
    }
};

export const deleteDangerousOccurrence = async (id, orgId) => {
    try {
        const response = await api.delete(`/DangerousOccurrences/${id}`, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error deleting dangerous occurrence:', error);
        throw error;
    }
};

export const fetchNextSerialNo = async (orgId, calendarYear) => {
    try {
        const response = await api.get('/DangerousOccurrences/SerialNo', { params: { orgId, calendarYear } });
        return response.data;
    } catch (error) {
        console.error('Error fetching next serial number:', error);
        throw error;
    }
};

export const exportDangerousOccurrences = async (orgId, year, fromDate, toDate, searchQuery, type = 'pdf') => {
    try {
        const endpoint = type === 'excel' ? 'export-excel' : 'export-pdf';
        const response = await api.post(`/DangerousOccurrences/${endpoint}`, {
            organizationId: orgId, year, fromDate, toDate, searchQuery 
        }, {
            responseType: 'blob'
        });
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        const dateStr = fromDate && toDate ? `${fromDate}_to_${toDate}` : (year || 'all');
        const extension = type === 'excel' ? 'xlsx' : 'pdf';
        link.setAttribute('download', `Form_26A_Dangerous_Occurrences_${dateStr}.${extension}`);
        document.body.appendChild(link);
        link.click();
        link.remove();
    } catch (error) {
        console.error('Error exporting dangerous occurrences:', error);
        throw error;
    }
};
export default api;

// ── Attendance & Leave Management ───────────────────────────────────────────

export const fetchLeaveTypes = async (orgId = null) => {
    try {
        const response = await api.get('/LeaveType', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching leave types:', error);
        throw error;
    }
};

export const fetchLeaveTypeSettings = async (orgId = null) => {
    try {
        const response = await api.get('/LeaveType/settings', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching leave type settings:', error);
        throw error;
    }
}

export const toggleLeaveType = async (payload) => {
    try {
        const response = await api.post('/LeaveType/toggle', payload);
        return response.data;
    } catch (error) {
        console.error('Error toggling leave type:', error);
        throw error;
    }
};

export const createLeaveType = async (payload) => {
    try {
        const response = await api.post('/LeaveType', payload);
        return response.data;
    } catch (error) {
        console.error('Error creating leave type:', error);
        throw error;
    }
};

export const updateLeaveType = async (payload) => {
    try {
        const response = await api.post('/LeaveType', payload); // Our controller uses Upsert logic on POST
        return response.data;
    } catch (error) {
        console.error('Error updating leave type:', error);
        throw error;
    }
};

export const deleteLeaveType = async (id) => {
    try {
        const response = await api.delete(`/LeaveType/${id}`);
        return response.data;
    } catch (error) {
        console.error('Error deleting leave type:', error);
        throw error;
    }
};









// ── Organization Acts & Details (Dynamic Forms) ──────────────────────────────
export const fetchOrganizationActs = async () => {
    try {
        const response = await api.get('/OrganizationAct/acts');
        return response.data;
    } catch (error) {
        console.error('Error fetching organization acts:', error);
        throw error;
    }
};

export const fetchOrganizationActFields = async (actId, organizationId = null) => {
    try {
        const response = await api.get('/OrganizationAct/fields', { params: { actId, organizationId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching organization act fields:', error);
        throw error;
    }
};

export const fetchOrganizationActDetail = async (actId, organizationId = null) => {
    try {
        const response = await api.get('/OrganizationAct/detail', { params: { actId, organizationId } });
        return response.data;
    } catch (error) {
        console.error('Error fetching organization act detail:', error);
        throw error;
    }
};

export const saveOrganizationActData = async (payload) => {
    try {
        const response = await api.post('/OrganizationAct/save', payload);
        return response.data;
    } catch (error) {
        console.error('Error saving organization act data:', error);
        throw error;
    }
};

export const addCustomOrgField = async (payload) => {
    try {
        const response = await api.post('/OrganizationAct/add-field', payload);
        return response.data;
    } catch (error) {
        console.error('Error adding custom organization field:', error);
        throw error;
    }
};

export const deleteOrganizationActField = async (fieldId, organizationId = null) => {
    try {
        const response = await api.delete(`/OrganizationAct/delete-field/${fieldId}`, { params: { organizationId } });
        return response.data;
    } catch (error) {
        console.error('Error deleting organization act field:', error);
        throw error;
    }
};

export const updateOrganizationActField = async (payload) => {
    try {
        const response = await api.post('/OrganizationAct/update-field', payload);
        return response.data;
    } catch (error) {
        console.error('Error updating organization act field:', error);
        throw error;
    }
};

export const updateOrganizationFieldSetting = async (payload) => {
    try {
        const response = await api.post('/OrganizationAct/toggle-field', payload);
        return response.data;
    } catch (error) {
        console.error('Error updating organization field setting:', error);
        throw error;
    }
};

// ── Master-Detail Attendance (FN/AN) ─────────────────────────────────────────

/**
 * Fetch all employees with their FN/AN status for a specific date.
 * GET /api/AttendanceMaster?date=yyyy-MM-dd
 */
export const fetchAttendanceByDate = async (date, orgId = null) => {
    try {
        const response = await api.get('/AttendanceMaster', { params: { date, orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error fetching master attendance by date:', error);
        throw error;
    }
};

/**
 * Upsert a single employee's FN/AN attendance.
 * POST /api/AttendanceMaster
 */
export const upsertEmpAttendance = async (payload, orgId = null) => {
    try {
        const response = await api.post('/AttendanceMaster', payload, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error upserting employee attendance:', error);
        throw error;
    }
};

/**
 * Bulk upsert FN/AN attendance for multiple employees on the same date.
 * POST /api/AttendanceMaster/bulk
 * payload: { attendanceDate: string, records: [{ employeeId, fn, an }] }
 */
export const bulkUpsertEmpAttendance = async (payload, orgId = null) => {
    try {
        const response = await api.post('/AttendanceMaster/bulk', payload, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error in bulk employee attendance upsert:', error);
        throw error;
    }
};
// ── Legacy Compatibility Aliases (RE-ADDED) ─────────────────────────────────

export const fetchAttendanceStatus = async (employeeId, orgId = null) => {
    try {
        const response = await api.get('/AttendanceMaster/status', { params: { employeeId, orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error in fetchAttendanceStatus:', error);
        throw error;
    }
};

export const saveAttendanceRecord = async (payload) => {
    const normalized = {
        employeeId: payload.employeeId,
        attendanceDate: payload.date || new Date().toISOString().split('T')[0],
        fn: payload.status || 'P',
        an: payload.status || 'P'
    };
    return await upsertEmpAttendance(normalized);
};

export const fetchAttendanceResults = async (start, end, orgId = null) => {
    return await fetchAttendanceByDate(start, orgId);
};

export const punchViaQR = async (qrToken, latitude, longitude) => {
    try {
        // Fallback or legacy mapping if needed; for now restore to satisfy imports
        const response = await api.post('/Attendance/punch-qr', { qrToken, latitude, longitude });
        return response.data;
    } catch (error) {
        console.error('[API] Error in punchViaQR:', error);
        throw error;
    }
};

export const generateQRToken = async (orgId = null) => {
    try {
        const response = await api.get('/Attendance/generate-qr-token', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error in generateQRToken:', error);
        throw error;
    }
};

/**
 * Export professional monthly attendance register (PDF/Excel).
 * GET /api/Attendance/export-register?month=MM&year=YYYY&department=...&designation=...&type=pdf|excel
 */
export const exportAttendanceRegister = async (params, type = 'excel') => {
    try {
        const response = await api.get('/Attendance/export-register', {
            params: { ...params, type },
            responseType: 'blob'
        });
        
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        const monthName = new Date(params.year, params.month - 1, 1).toLocaleString('default', { month: 'short' });
        const extension = type === 'pdf' ? 'pdf' : 'xlsx';
        link.setAttribute('download', `Attendance_Register_${monthName}_${params.year}.${extension}`);
        document.body.appendChild(link);
        link.click();
        link.remove();
        window.URL.revokeObjectURL(url);
    } catch (error) {
        console.error('[API] Error exporting attendance register:', error);
        throw error;
    }
};

// ── Employee OT (Over Duty) API ─────────────────────────────────────────────
export const fetchEmpOTs = async (orgId) => {
    try {
        const response = await api.get('/EmpOT/GetOTByOrgId', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error fetching Employee OT records:', error);
        throw error;
    }
};

export const getEmpOTByEmpId = async (empId) => {
    try {
        const response = await api.get('/EmpOT/GetOTByEmpId', { params: { empId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error fetching Employee OT by Employee ID:', error);
        throw error;
    }
};

export const saveEmpOT = async (data) => {
    try {
        const response = await api.post('/EmpOT/SaveOT', data);
        return response.data;
    } catch (error) {
        console.error('[API] Error saving Employee OT:', error);
        throw error;
    }
};

export const updateEmpOT = async (data) => {
    try {
        const response = await api.put('/EmpOT/UpdateOT', data);
        return response.data;
    } catch (error) {
        console.error('[API] Error updating Employee OT:', error);
        throw error;
    }
};

export const deleteEmpOT = async (otId, orgId) => {
    try {
        const response = await api.delete('/EmpOT/DeleteOT', { params: { otId, orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error deleting Employee OT:', error);
        throw error;
    }
};

// ── End of API ─────────────────────────────────────────────────────────────

// ── Professional Tax (PT) API ────────────────────────────────────────────────
export const fetchProfessionalTax = async () => {
    try {
        const response = await api.get('/ProfessionalTax/GetProfessionalTax');
        return response.data;
    } catch (error) {
        console.error('[API] Error fetching Professional Tax slabs:', error);
        throw error;
    }
};

export const createProfessionalTax = async (data) => {
    try {
        const response = await api.post('/ProfessionalTax/SaveProfessionalTax', data);
        return response.data;
    } catch (error) {
        console.error('[API] Error creating Professional Tax slab:', error);
        throw error;
    }
};

export const updateProfessionalTax = async (data) => {
    try {
        const response = await api.put('/ProfessionalTax/UpdateProfessionalTax', data);
        return response.data;
    } catch (error) {
        console.error('[API] Error updating Professional Tax slab:', error);
        throw error;
    }
};

export const deleteProfessionalTax = async (ptId) => {
    try {
        const response = await api.delete('/ProfessionalTax/DeleteProfessionalTax', { params: { ptId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error deleting Professional Tax:', error);
        throw error;
    }
};

// ── Allowances API ─────────────────────────────────────────────────────────

export const fetchAllowances = async (orgId) => {
    try {
        const response = await api.get('/Allowances/GetAllowanceByOrgId', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error fetching Allowances:', error);
        throw error;
    }
};

export const createAllowance = async (data, orgId) => {
    try {
        const response = await api.post('/Allowances/SaveAllowance', data, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error creating Allowance:', error);
        throw error;
    }
};

export const updateAllowance = async (data, orgId) => {
    try {
        const response = await api.put('/Allowances/UpdateAllowance', data, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error updating Allowance:', error);
        throw error;
    }
};

export const deleteAllowance = async (allowanceId, orgId) => {
    try {
        const response = await api.delete('/Allowances/DeleteAllowance', { params: { allowanceId, orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error deleting Allowance:', error);
        throw error;
    }
};

// ── Staff Allowance Assignment API ──────────────────────────────────────────

export const fetchStaffAllowances = async (orgId) => {
    try {
        const response = await api.get('/StaffAllowance/GetStaffAllowanceByOrgId', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error fetching Staff Allowances:', error);
        throw error;
    }
};

export const saveStaffAllowance = async (data, orgId) => {
    try {
        const response = await api.post('/StaffAllowance/SaveStaffAllowance', data, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error saving Staff Allowance:', error);
        throw error;
    }
};

export const updateStaffAllowance = async (data, orgId) => {
    try {
        const response = await api.put('/StaffAllowance/UpdateStaffAllowance', data, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error updating Staff Allowance:', error);
        throw error;
    }
};

export const deleteStaffAllowance = async (staffAllowanceId, orgId) => {
    try {
        const response = await api.delete('/StaffAllowance/DeleteStaffAllowance', { params: { staffAllowanceId, orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error deleting Staff Allowance:', error);
        throw error;
    }
};

// ── Deductions API ─────────────────────────────────────────────────────────

export const fetchDeductions = async (orgId) => {
    try {
        const response = await api.get('/Deductions/GetDeductionsByOrgId', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error fetching Deductions:', error);
        throw error;
    }
};

export const createDeduction = async (data, orgId) => {
    try {
        const response = await api.post('/Deductions/SaveDeduction', data, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error creating Deduction:', error);
        throw error;
    }
};

export const updateDeduction = async (data, orgId) => {
    try {
        const response = await api.put('/Deductions/UpdateDeduction', data, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error updating Deduction:', error);
        throw error;
    }
};

export const deleteDeduction = async (deductionId, orgId) => {
    try {
        const response = await api.delete('/Deductions/DeleteDeduction', { params: { deductionId, orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error deleting Deduction:', error);
        throw error;
    }
};

// ── Staff Deduction Assignment API ──────────────────────────────────────────

export const fetchStaffDeductions = async (orgId) => {
    try {
        const response = await api.get('/StaffDeduction/GetStaffDeductionsByOrgId', { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error fetching Staff Deductions:', error);
        throw error;
    }
};

export const saveStaffDeduction = async (data, orgId) => {
    try {
        const response = await api.post('/StaffDeduction/SaveStaffDeduction', data, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error saving Staff Deduction:', error);
        throw error;
    }
};

export const updateStaffDeduction = async (data, orgId) => {
    try {
        const response = await api.put('/StaffDeduction/UpdateStaffDeduction', data, { params: { orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error updating Staff Deduction:', error);
        throw error;
    }
};

export const deleteStaffDeduction = async (staffDeductionId, orgId) => {
    try {
        const response = await api.delete('/StaffDeduction/DeleteStaffDeduction', { params: { staffDeductionId, orgId } });
        return response.data;
    } catch (error) {
        console.error('[API] Error deleting Staff Deduction:', error);
        throw error;
    }
};
