using Microsoft.AspNetCore.SignalR;

namespace backend.Hubs;

public class AttendanceHub : Hub
{
    public async Task JoinOrganizationGroup(string organizationId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"Org_{organizationId}");
    }

    public async Task LeaveOrganizationGroup(string organizationId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Org_{organizationId}");
    }
}
