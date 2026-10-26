using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BillSplit.Domain.Entities;

[Table("Banks")]
public class Bank
{
    [Key]
    [MaxLength(10)]
    public string Bin { get; set; } = string.Empty;

    [Required]
    [MaxLength(50)]
    public string ShortName { get; set; } = string.Empty;

    [Required]
    [MaxLength(150)]
    public string FullName { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? LogoUrl { get; set; }

    public bool IsSupported { get; set; } = true;
}
