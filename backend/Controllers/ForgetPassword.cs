using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Dapper;
using System.Text;
using System.Security.Claims;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using backend.Models;
using backend.Data;
using System.Data;
using MailKit.Net.Smtp;
using MimeKit;
using MailKit.Security;
using Microsoft.AspNetCore.Hosting;
using BCrypt.Net;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ForgetPasswordController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly IConfiguration _config;
    private readonly ILogger<ForgetPasswordController> _logger;
    private readonly string _templatePath;

    public ForgetPasswordController(DataBaseConnection db, IConfiguration config, ILogger<ForgetPasswordController> logger, IWebHostEnvironment env)
    {
        _db = db;
        _config = config;
        _logger = logger;
        _templatePath = Path.Combine(env.ContentRootPath, "EmailTemplate", "index.html");
    }

    [HttpPost("request-otp")]
    public async Task<IActionResult> RequestOtp([FromBody] ForgetPasswordRequest request)
    {
        if (string.IsNullOrEmpty(request.Email)) return BadRequest(new { message = "Email is required" });

        _logger.LogInformation("[ForgetPassword] OTP request | Email={Email}", request.Email);
        
        using var conn = _db.CreateConnection();
        var user = await conn.QueryFirstOrDefaultAsync<User>("sp_GetUserByEmail", new { request.Email }, commandType: CommandType.StoredProcedure);
        
        if (user == null)
        {
            // For security, don't reveal if email exists, but the user asked for "No Email Found" in their structure
            _logger.LogWarning("[ForgetPassword] OTP failed — invalid email | Email={Email}", request.Email);
            return BadRequest(new { message = "No Email Found" });
        }

        var otp = GenerateRandomOtp();
        
        // Store OTP in DB
        await conn.ExecuteAsync("sp_UpsertUserOtp", new { Email = request.Email, OtpCode = otp.ToString(), ExpiryMinutes = 10 }, commandType: CommandType.StoredProcedure);

        var sent = await SendOtpEmailAsync(request.Email, otp, user.Name);
        if (!sent)
        {
            return StatusCode(500, new { message = "Failed to send OTP email" });
        }

        return Ok(new { message = "OTP sent successfully" });
    }

    [HttpPost("verify-otp")]
    public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpRequest request)
    {
        if (string.IsNullOrEmpty(request.Email) || string.IsNullOrEmpty(request.Otp))
            return BadRequest(new { message = "Email and OTP are required" });

        using var conn = _db.CreateConnection();
        var result = await conn.QueryFirstOrDefaultAsync<int>("sp_VerifyOtp", new { Email = request.Email, OtpCode = request.Otp }, commandType: CommandType.StoredProcedure);

        if (result == 1)
        {
            return Ok(new { message = "OTP verified successfully" });
        }
        
        return BadRequest(new { message = "Invalid or expired OTP" });
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request)
    {
        if (string.IsNullOrEmpty(request.Email) || string.IsNullOrEmpty(request.NewPassword))
            return BadRequest(new { message = "Email and New Password are required" });

        // Password complexity validation
        if (request.NewPassword.Length < 8)
            return BadRequest(new { message = "Password must be at least 8 characters long" });
        if (!request.NewPassword.Any(char.IsUpper))
            return BadRequest(new { message = "Password must contain at least one uppercase letter" });
        if (!request.NewPassword.Any(char.IsLower))
            return BadRequest(new { message = "Password must contain at least one lowercase letter" });
        if (!request.NewPassword.Any(char.IsDigit))
            return BadRequest(new { message = "Password must contain at least one number" });
        if (!request.NewPassword.Any(ch => !char.IsLetterOrDigit(ch)))
            return BadRequest(new { message = "Password must contain at least one special character" });

        // Generate hash (same as registration/auth)
        var passwordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);

        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync("sp_UpdatePassword", new { Email = request.Email, PasswordHash = passwordHash }, commandType: CommandType.StoredProcedure);

        _logger.LogInformation("[ForgetPassword] Password reset successful | Email={Email}", request.Email);
        return Ok(new { message = "Password reset successfully" });
    }

    private async Task<bool> SendOtpEmailAsync(string email, int otp, string userName)
    {
        try
        {
            var smtpSettings = _config.GetSection("Smtp");
            var host = smtpSettings["Host"] ?? "";
            var port = int.Parse(smtpSettings["Port"] ?? "587");
            var user = smtpSettings["Username"] ?? "";
            var pass = smtpSettings["Password"] ?? "";

            var message = new MimeMessage();
            message.From.Add(new MailboxAddress("ProDesX HRMS", user));
            message.To.Add(new MailboxAddress(userName, email));
            message.Subject = "Reset Your Password - OTP Verification";

            var builder = new BodyBuilder();
            
            // Load template
            string content = "";
            if (System.IO.File.Exists(_templatePath))
            {
                content = await System.IO.File.ReadAllTextAsync(_templatePath);
                content = content.Replace("{{NAME}}", userName).Replace("{{OTP}}", otp.ToString());
            }
            else
            {
                content = $"Hello {userName}, your OTP for password reset is: {otp}. It expires in 10 minutes.";
            }

            builder.HtmlBody = content;
            message.Body = builder.ToMessageBody();

            using var client = new SmtpClient();
            await client.ConnectAsync(host, port, SecureSocketOptions.StartTls);
            await client.AuthenticateAsync(user, pass);
            await client.SendAsync(message);
            await client.DisconnectAsync(true);

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[ForgetPassword] Email sending FAILED | Email={Email}", email);
            return false;
        }
    }

    private int GenerateRandomOtp()
    {
        return new Random().Next(100000, 999999);
    }

    private string GenerateJwtToken(User user)
    {
        var jwtSettings = _config.GetSection("Jwt");
        var jwtKey    = jwtSettings["Key"]        ?? throw new InvalidOperationException("'Jwt:Key' is missing in configuration.");
        var jwtIssuer  = jwtSettings["Issuer"]     ?? throw new InvalidOperationException("'Jwt:Issuer' is missing in configuration.");
        var jwtAudnce  = jwtSettings["Audience"]   ?? throw new InvalidOperationException("'Jwt:Audience' is missing in configuration.");
        var jwtExpiry  = jwtSettings["ExpiryInMinutes"] ?? throw new InvalidOperationException("'Jwt:ExpiryInMinutes' is missing in configuration.");
        var key = Encoding.ASCII.GetBytes(jwtKey);
        var tokenHandler = new JwtSecurityTokenHandler();
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Name ?? ""),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.Role, user.Role ?? "User"),
                new Claim("OrganizationId", user.OrganizationId?.ToString() ?? "")
            }),
            Expires = DateTime.UtcNow.AddMinutes(double.Parse(jwtExpiry)),
            Issuer = jwtIssuer,
            Audience = jwtAudnce,
            SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
        };

        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}