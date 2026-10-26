using System.ComponentModel.DataAnnotations;

namespace BillSplit.Application.DTOs;

public class RegisterRequestDto
{
    [Required]
    [RegularExpression(@"^(0[3|5|7|8|9])+([0-9]{8})$", ErrorMessage = "Số điện thoại không đúng định dạng Việt Nam")]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required]
    [EmailAddress(ErrorMessage = "Email không đúng định dạng")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
    [RegularExpression(
        @"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^a-zA-Z\d]).{8,}$",
        ErrorMessage = "Mật khẩu phải từ 8 ký tự trở lên, bao gồm chữ hoa, chữ thường, số và ký tự đặc biệt.")]
    public string Password { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string FullName { get; set; } = string.Empty;

    [Required]
    [MaxLength(10)]
    public string BankBin { get; set; } = string.Empty;

    [Required]
    [MaxLength(30)]
    public string BankAccountNo { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string BankAccountName { get; set; } = string.Empty;
}

public class LoginRequestDto
{
    [Required(ErrorMessage = "Vui lòng nhập số điện thoại hoặc email")]
    public string Identifier { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
    public string Password { get; set; } = string.Empty;
}

public class UserDto
{
    public Guid Id { get; set; }
    public string PhoneNumber { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
    public string BankBin { get; set; } = string.Empty;
    public string BankAccountNo { get; set; } = string.Empty;
    public string BankAccountName { get; set; } = string.Empty;
}

public class AuthResponseDto
{
    public string Token { get; set; } = string.Empty;
    public UserDto User { get; set; } = null!;
}

public class BankDto
{
    public string Bin { get; set; } = string.Empty;
    public string ShortName { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string? LogoUrl { get; set; }
    public bool IsSupported { get; set; }
}

public class SendOtpRequestDto
{
    [Required(ErrorMessage = "Email là bắt buộc")]
    [EmailAddress(ErrorMessage = "Email không đúng định dạng")]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// Mục đích nhận OTP: "register" hoặc "forgot_password"
    /// </summary>
    public string Purpose { get; set; } = "register";
}

public class VerifyOtpRequestDto
{
    [Required(ErrorMessage = "Email là bắt buộc")]
    [EmailAddress(ErrorMessage = "Email không đúng định dạng")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Mã OTP là bắt buộc")]
    [StringLength(6, MinimumLength = 6, ErrorMessage = "Mã OTP gồm đúng 6 chữ số")]
    public string OtpCode { get; set; } = string.Empty;

    public string Purpose { get; set; } = "register";
}

public class ResetPasswordRequestDto
{
    [Required(ErrorMessage = "Email là bắt buộc")]
    [EmailAddress(ErrorMessage = "Email không đúng định dạng")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Mã OTP là bắt buộc")]
    [StringLength(6, MinimumLength = 6, ErrorMessage = "Mã OTP gồm đúng 6 chữ số")]
    public string OtpCode { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới")]
    [RegularExpression(
        @"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^a-zA-Z\d]).{8,}$",
        ErrorMessage = "Mật khẩu mới phải từ 8 ký tự trở lên, bao gồm chữ hoa, chữ thường, số và ký tự đặc biệt.")]
    public string NewPassword { get; set; } = string.Empty;
}
