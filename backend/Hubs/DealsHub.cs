using Microsoft.AspNetCore.SignalR;

namespace backend.Hubs
{
    public class DealsHub : Hub
    {
        public async Task SendUpdate()
        {
            await Clients.All.SendAsync("ReceiveDealUpdate");
        }
    }
}
