using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BillSplit.Domain.Entities;

[Table("Expenses")]
public class Expense
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(150)]
    public string Title { get; set; } = string.Empty;

    [Column(TypeName = "decimal(18,2)")]
    public decimal TotalAmount { get; set; }

    [Required]
    public Guid PayerId { get; set; }

    [ForeignKey(nameof(PayerId))]
    public User Payer { get; set; } = null!;

    public Guid? GroupId { get; set; }

    [ForeignKey(nameof(GroupId))]
    public Group? Group { get; set; }

    [MaxLength(50)]
    public string Category { get; set; } = "Food";

    [MaxLength(500)]
    public string? ReceiptImageUrl { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<Debt> Debts { get; set; } = new List<Debt>();
}
