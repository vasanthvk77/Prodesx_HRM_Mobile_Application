using Microsoft.AspNetCore.SignalR;

namespace backend.Hubs
{
    public class UserManagementHub : Hub
    {
        public async Task SendUpdate()
        {
            await Clients.All.SendAsync("UserManagementUpdate");
        }
    }
}
