using Microsoft.AspNetCore.SignalR;

namespace backend.Hubs
{
    public class DangerousOccurrencesHub : Hub
    {
        public async Task JoinOrganizationGroup(int organizationId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"Org_{organizationId}");
        }

        public async Task LeaveOrganizationGroup(int organizationId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Org_{organizationId}");
        }
    }
}
