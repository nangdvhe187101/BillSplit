using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using BillSplit.Domain.Entities;
using BillSplit.Domain.Enums;
using BillSplit.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace BillSplit.Infrastructure.Services;

public class GroupService : IGroupService
{
    private readonly AppDbContext _context;

    public GroupService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<(bool Success, string Message, GroupDto? Data)> CreateGroupAsync(Guid currentUserId, CreateGroupRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return (false, "Tên nhóm không được để trống.", null);
        }

        // Sinh mã mời 6 ký tự ngẫu nhiên duy nhất
        var inviteCode = GenerateInviteCode();
        while (await _context.Groups.AnyAsync(g => g.InviteCode == inviteCode))
        {
            inviteCode = GenerateInviteCode();
        }

        var group = new Group
        {
            Id = Guid.NewGuid(),
            Name = request.Name.Trim(),
            Category = request.Category,
            AvatarUrl = request.AvatarUrl,
            InviteCode = inviteCode,
            CreatedById = currentUserId,
            CreatedAt = DateTime.UtcNow
        };

        var member = new GroupMember
        {
            GroupId = group.Id,
            UserId = currentUserId,
            Role = GroupRole.Owner,
            JoinedAt = DateTime.UtcNow
        };

        _context.Groups.Add(group);
        _context.GroupMembers.Add(member);
        await _context.SaveChangesAsync();

        var currentUser = await _context.Users.FindAsync(currentUserId);

        var dto = new GroupDto(
            group.Id,
            group.Name,
            group.Category,
            group.AvatarUrl,
            group.InviteCode,
            group.CreatedById,
            group.CreatedAt,
            1,
            new List<GroupMemberDto>
            {
                new(
                    currentUser!.Id,
                    currentUser.FullName,
                    currentUser.PhoneNumber,
                    currentUser.AvatarUrl,
                    GroupRole.Owner.ToString(),
                    member.JoinedAt
                )
            }
        );

        return (true, "Tạo nhóm thành công!", dto);
    }

    public async Task<List<GroupDto>> GetUserGroupsAsync(Guid currentUserId)
    {
        var groups = await _context.Groups
            .Include(g => g.Members)
                .ThenInclude(m => m.User)
            .Where(g => g.Members.Any(m => m.UserId == currentUserId))
            .OrderByDescending(g => g.CreatedAt)
            .ToListAsync();

        return groups.Select(g => new GroupDto(
            g.Id,
            g.Name,
            g.Category,
            g.AvatarUrl,
            g.InviteCode,
            g.CreatedById,
            g.CreatedAt,
            g.Members.Count,
            g.Members.Select(m => new GroupMemberDto(
                m.UserId,
                m.User.FullName,
                m.User.PhoneNumber,
                m.User.AvatarUrl,
                m.Role.ToString(),
                m.JoinedAt
            )).ToList()
        )).ToList();
    }

    public async Task<GroupDto?> GetGroupDetailAsync(Guid currentUserId, Guid groupId)
    {
        var group = await _context.Groups
            .Include(g => g.Members)
                .ThenInclude(m => m.User)
            .FirstOrDefaultAsync(g => g.Id == groupId && g.Members.Any(m => m.UserId == currentUserId));

        if (group == null) return null;

        return new GroupDto(
            group.Id,
            group.Name,
            group.Category,
            group.AvatarUrl,
            group.InviteCode,
            group.CreatedById,
            group.CreatedAt,
            group.Members.Count,
            group.Members.Select(m => new GroupMemberDto(
                m.UserId,
                m.User.FullName,
                m.User.PhoneNumber,
                m.User.AvatarUrl,
                m.Role.ToString(),
                m.JoinedAt
            )).ToList()
        );
    }

    public async Task<(bool Success, string Message, GroupDto? Data)> JoinGroupByInviteCodeAsync(Guid currentUserId, string inviteCode)
    {
        var cleanCode = inviteCode.Trim().ToUpper();
        var group = await _context.Groups
            .Include(g => g.Members)
            .FirstOrDefaultAsync(g => g.InviteCode == cleanCode);

        if (group == null)
        {
            return (false, "Mã mời nhóm không tồn tại.", null);
        }

        if (group.Members.Any(m => m.UserId == currentUserId))
        {
            return (false, "Bạn đã tham gia nhóm này rồi.", null);
        }

        var member = new GroupMember
        {
            GroupId = group.Id,
            UserId = currentUserId,
            Role = GroupRole.Member,
            JoinedAt = DateTime.UtcNow
        };

        _context.GroupMembers.Add(member);
        await _context.SaveChangesAsync();

        var detail = await GetGroupDetailAsync(currentUserId, group.Id);
        return (true, $"Đã tham gia nhóm {group.Name} thành công!", detail);
    }

    private static string GenerateInviteCode()
    {
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var random = new Random();
        return new string(Enumerable.Repeat(chars, 6).Select(s => s[random.Next(s.Length)]).ToArray());
    }
}
