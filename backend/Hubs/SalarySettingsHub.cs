using Microsoft.AspNetCore.SignalR;
using System.Threading.Tasks;

namespace backend.Hubs;

public class SalarySettingsHub : Hub
{
    public async Task JoinOrganizationGroup(string orgId)
    {
        // orgId here is the HashID passed from frontend
        await Groups.AddToGroupAsync(Context.ConnectionId, $"Org_{orgId}");
    }

    public async Task LeaveOrganizationGroup(string orgId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Org_{orgId}");
    }
}
