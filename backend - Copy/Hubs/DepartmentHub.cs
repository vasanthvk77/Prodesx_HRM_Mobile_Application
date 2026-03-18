using Microsoft.AspNetCore.SignalR;
using System.Threading.Tasks;

namespace backend.Hubs
{
    public class DepartmentHub : Hub
    {
        public async Task SendDepartmentUpdate()
        {
            await Clients.All.SendAsync("ReceiveDepartmentUpdate");
        }
    }
}
