using Microsoft.AspNetCore.SignalR;

namespace backend.Hubs;

public class StaffSalaryHub : Hub
{
    public async Task JoinOrganizationGroup(string orgId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"Org_{orgId}");
    }

    public async Task LeaveOrganizationGroup(string orgId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Org_{orgId}");
    }
}
