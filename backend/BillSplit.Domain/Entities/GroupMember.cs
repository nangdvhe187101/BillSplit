using System.ComponentModel.DataAnnotations.Schema;
using BillSplit.Domain.Enums;

namespace BillSplit.Domain.Entities;

[Table("GroupMembers")]
public class GroupMember
{
    public Guid GroupId { get; set; }

    [ForeignKey(nameof(GroupId))]
    public Group Group { get; set; } = null!;

    public Guid UserId { get; set; }

    [ForeignKey(nameof(UserId))]
    public User User { get; set; } = null!;

    public GroupRole Role { get; set; } = GroupRole.Member;

    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
}
