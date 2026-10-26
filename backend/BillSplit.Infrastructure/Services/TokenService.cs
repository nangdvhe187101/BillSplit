using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using BillSplit.Application.Interfaces;
using BillSplit.Domain.Entities;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace BillSplit.Infrastructure.Services;

public class TokenService : ITokenService
{
    private readonly IConfiguration _configuration;

    public TokenService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public string GenerateToken(User user)
    {
        // Secret BẮT BUỘC lấy từ cấu hình (User Secrets / biến môi trường), không hardcode.
        var secret = _configuration["Jwt:Secret"]
            ?? throw new InvalidOperationException("Thiếu cấu hình 'Jwt:Secret' trong appsettings/User Secrets.");
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.MobilePhone, user.PhoneNumber),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Name, user.FullName)
        };

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddDays(7),
            Issuer = _configuration["Jwt:Issuer"] ?? "BillSplitApi",
            Audience = _configuration["Jwt:Audience"] ?? "BillSplitApp",
            SigningCredentials = creds
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}
