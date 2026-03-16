using Microsoft.AspNetCore.SignalR;

namespace backend.Hubs;

public class LeadsHub : Hub
{
    public async Task SendUpdate()
    {
        await Clients.All.SendAsync("LeadListUpdated");
    }
}
