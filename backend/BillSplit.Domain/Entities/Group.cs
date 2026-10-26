using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BillSplit.Domain.Entities;

[Table("Groups")]
public class Group
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(50)]
    public string Category { get; set; } = "Food"; // House, Trip, Food, Other

    [MaxLength(500)]
    public string? AvatarUrl { get; set; }

    [Required]
    [MaxLength(10)]
    public string InviteCode { get; set; } = string.Empty;

    public Guid CreatedById { get; set; }

    [ForeignKey(nameof(CreatedById))]
    public User CreatedBy { get; set; } = null!;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<GroupMember> Members { get; set; } = new List<GroupMember>();
    public ICollection<Expense> Expenses { get; set; } = new List<Expense>();
}
