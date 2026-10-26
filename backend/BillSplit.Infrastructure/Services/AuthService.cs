using System.Security.Cryptography;
using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using BillSplit.Domain.Entities;
using BillSplit.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace BillSplit.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly AppDbContext _context;
    private readonly ITokenService _tokenService;
    private readonly IEmailService _emailService;
    private readonly IMemoryCache _memoryCache;

    public AuthService(
        AppDbContext context,
        ITokenService tokenService,
        IEmailService emailService,
        IMemoryCache memoryCache)
    {
        _context = context;
        _tokenService = tokenService;
        _emailService = emailService;
        _memoryCache = memoryCache;
    }

    public async Task<(bool Success, string Message, AuthResponseDto? Data)> RegisterAsync(RegisterRequestDto request)
    {
        // 1. Kiểm tra số điện thoại hoặc email đã tồn tại chưa
        var phoneExists = await _context.Users.AnyAsync(u => u.PhoneNumber == request.PhoneNumber);
        if (phoneExists)
        {
            return (false, "Số điện thoại đã được đăng ký trên hệ thống.", null);
        }

        var emailExists = await _context.Users.AnyAsync(u => u.Email == request.Email.ToLower());
        if (emailExists)
        {
            return (false, "Email đã được sử dụng trên hệ thống.", null);
        }

        // 2. Hash mật khẩu bằng BCrypt
        var passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);

        // 3. Chuẩn hóa tên in hoa không dấu của chủ tài khoản
        var normalizedAccountName = request.BankAccountName.Trim().ToUpper();

        var newUser = new User
        {
            PhoneNumber = request.PhoneNumber.Trim(),
            Email = request.Email.Trim().ToLower(),
            PasswordHash = passwordHash,
            FullName = request.FullName.Trim(),
            BankBin = request.BankBin.Trim(),
            BankAccountNo = request.BankAccountNo.Trim(),
            BankAccountName = normalizedAccountName,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Users.Add(newUser);

        // 4. Tự động liên kết các khoản nợ quá khứ nếu trước đó bạn bè đã chia nợ theo số điện thoại này
        var unlinkedDebts = await _context.Debts
            .Where(d => d.DebtorId == null && d.DebtorPhone == request.PhoneNumber.Trim())
            .ToListAsync();

        foreach (var debt in unlinkedDebts)
        {
            debt.DebtorId = newUser.Id;
        }

        await _context.SaveChangesAsync();

        var token = _tokenService.GenerateToken(newUser);

        var responseDto = new AuthResponseDto
        {
            Token = token,
            User = MapToDto(newUser)
        };

        return (true, "Đăng ký tài khoản thành công.", responseDto);
    }

    public async Task<(bool Success, string Message, AuthResponseDto? Data)> LoginAsync(LoginRequestDto request)
    {
        var identifier = request.Identifier.Trim().ToLower();

        // Tìm kiếm theo PhoneNumber hoặc Email
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.PhoneNumber == identifier || u.Email.ToLower() == identifier);

        if (user == null)
        {
            return (false, "Tài khoản hoặc mật khẩu không chính xác.", null);
        }

        var isPasswordValid = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);
        if (!isPasswordValid)
        {
            return (false, "Tài khoản hoặc mật khẩu không chính xác.", null);
        }

        var token = _tokenService.GenerateToken(user);

        var responseDto = new AuthResponseDto
        {
            Token = token,
            User = MapToDto(user)
        };

        return (true, "Đăng nhập thành công.", responseDto);
    }

    public async Task<(bool Success, string Message)> SendOtpAsync(SendOtpRequestDto request)
    {
        var email = request.Email.Trim().ToLower();
        var purpose = request.Purpose.Trim().ToLower();

        if (purpose == "register")
        {
            var emailExists = await _context.Users.AnyAsync(u => u.Email == email);
            if (emailExists)
            {
                return (false, "Email này đã được đăng ký tài khoản.");
            }
        }
        else if (purpose == "forgot_password")
        {
            var userExists = await _context.Users.AnyAsync(u => u.Email == email);
            if (!userExists)
            {
                return (false, "Không tìm thấy tài khoản nào gắn với email này.");
            }
        }

        // Tạo mã OTP 6 chữ số ngẫu nhiên
        var otpCode = RandomNumberGenerator.GetInt32(100000, 999999).ToString();
        var cacheKey = $"otp_{purpose}_{email}";

        // Lưu vào IMemoryCache trong 10 phút
        _memoryCache.Set(cacheKey, otpCode, TimeSpan.FromMinutes(10));

        var title = purpose == "register" ? "Xác nhận đăng ký Sổ Nợ" : "Mã xác thực đổi mật khẩu Sổ Nợ";
        var body = $@"
            <div style='font-family: Arial, sans-serif; padding: 20px; color: #333;'>
                <h2 style='color: #4F46E5;'>{title}</h2>
                <p>Chào bạn,</p>
                <p>Mã xác thực OTP của bạn là: <strong style='font-size: 24px; color: #DC2626; letter-spacing: 4px;'>{otpCode}</strong></p>
                <p>Mã này có hiệu lực trong <b>10 phút</b>. Vui lòng không cung cấp mã cho người khác.</p>
                <hr style='border: none; border-top: 1px solid #E5E7EB; margin: 20px 0;'/>
                <p style='font-size: 12px; color: #9CA3AF;'>Ứng dụng Sổ Nợ - Chia tiền & Nhắc nợ thông minh</p>
            </div>";

        var sent = await _emailService.SendEmailAsync(email, title, body);
        if (!sent)
        {
            return (false, "Không thể gửi email OTP lúc này. Vui lòng thử lại sau.");
        }

        return (true, "Mã xác thực OTP đã được gửi đến email của bạn.");
    }

    public Task<(bool Success, string Message)> VerifyOtpAsync(VerifyOtpRequestDto request)
    {
        var email = request.Email.Trim().ToLower();
        var purpose = request.Purpose.Trim().ToLower();
        var cacheKey = $"otp_{purpose}_{email}";

        if (!_memoryCache.TryGetValue<string>(cacheKey, out var cachedOtp))
        {
            return Task.FromResult((false, "Mã OTP đã hết hạn hoặc không tồn tại. Vui lòng yêu cầu mã mới."));
        }

        if (cachedOtp != request.OtpCode.Trim())
        {
            return Task.FromResult((false, "Mã OTP không chính xác."));
        }

        return Task.FromResult((true, "Xác thực OTP thành công."));
    }

    public async Task<(bool Success, string Message)> ForgotPasswordAsync(string email)
    {
        return await SendOtpAsync(new SendOtpRequestDto { Email = email, Purpose = "forgot_password" });
    }

    public async Task<(bool Success, string Message)> ResetPasswordAsync(ResetPasswordRequestDto request)
    {
        var email = request.Email.Trim().ToLower();
        var verifyResult = await VerifyOtpAsync(new VerifyOtpRequestDto
        {
            Email = email,
            OtpCode = request.OtpCode,
            Purpose = "forgot_password"
        });

        if (!verifyResult.Success)
        {
            return verifyResult;
        }

        var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
        if (user == null)
        {
            return (false, "Không tìm thấy người dùng.");
        }

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        // Xóa OTP khỏi bộ nhớ sau khi đổi thành công
        _memoryCache.Remove($"otp_forgot_password_{email}");

        return (true, "Đổi mật khẩu thành công. Bạn có thể đăng nhập ngay bằng mật khẩu mới.");
    }

    private static UserDto MapToDto(User user)
    {
        return new UserDto
        {
            Id = user.Id,
            PhoneNumber = user.PhoneNumber,
            Email = user.Email,
            FullName = user.FullName,
            AvatarUrl = user.AvatarUrl,
            BankBin = user.BankBin,
            BankAccountNo = user.BankAccountNo,
            BankAccountName = user.BankAccountName
        };
    }
}
