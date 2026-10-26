using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using BillSplit.Domain.Entities;
using BillSplit.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace BillSplit.Infrastructure.Services;

public class UserService : IUserService
{
    private readonly AppDbContext _context;

    public UserService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<UserProfileDto?> GetProfileAsync(Guid userId)
    {
        var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null) return null;

        var bank = await _context.Banks.AsNoTracking().FirstOrDefaultAsync(b => b.Bin == user.BankBin);
        var bankName = bank?.ShortName ?? user.BankBin;

        return new UserProfileDto(
            user.Id,
            user.PhoneNumber,
            user.Email,
            user.FullName,
            user.AvatarUrl,
            user.BankBin,
            user.BankAccountNo,
            user.BankAccountName,
            bankName
        );
    }

    public async Task<(bool Success, string Message, UserProfileDto? Data)> UpdateProfileAsync(Guid userId, UpdateProfileRequestDto request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null)
        {
            return (false, "Không tìm thấy người dùng.", null);
        }

        if (string.IsNullOrWhiteSpace(request.FullName))
        {
            return (false, "Họ và tên không được để trống.", null);
        }

        user.FullName = request.FullName.Trim();
        user.BankBin = request.BankBin.Trim();
        user.BankAccountNo = request.BankAccountNo.Trim();
        user.BankAccountName = request.BankAccountName.Trim().ToUpper();
        if (!string.IsNullOrWhiteSpace(request.AvatarUrl))
        {
            user.AvatarUrl = request.AvatarUrl.Trim();
        }
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        var bank = await _context.Banks.AsNoTracking().FirstOrDefaultAsync(b => b.Bin == user.BankBin);
        var bankName = bank?.ShortName ?? user.BankBin;

        var dto = new UserProfileDto(
            user.Id,
            user.PhoneNumber,
            user.Email,
            user.FullName,
            user.AvatarUrl,
            user.BankBin,
            user.BankAccountNo,
            user.BankAccountName,
            bankName
        );

        return (true, "Cập nhật hồ sơ thành công.", dto);
    }
}
