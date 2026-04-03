using Microsoft.AspNetCore.SignalR;

namespace backend.Hubs;

public class EmpOTHub : Hub
{
    public async Task JoinOrganization(int orgId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"Org_{orgId}");
    }

    public async Task LeaveOrganization(int orgId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Org_{orgId}");
    }
}
