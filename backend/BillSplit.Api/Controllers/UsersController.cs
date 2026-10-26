using System.Security.Claims;
using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BillSplit.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly IStorageService _storageService;

    public UsersController(IUserService userService, IStorageService storageService)
    {
        _userService = userService;
        _storageService = storageService;
    }

    private Guid GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(claim!);
    }

    [HttpGet("profile")]
    public async Task<IActionResult> GetProfile()
    {
        var userId = GetUserId();
        var profile = await _userService.GetProfileAsync(userId);
        if (profile == null)
        {
            return NotFound(new { message = "Không tìm thấy hồ sơ người dùng." });
        }
        return Ok(profile);
    }

    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequestDto request)
    {
        var userId = GetUserId();
        var result = await _userService.UpdateProfileAsync(userId, request);
        if (!result.Success)
        {
            return BadRequest(new { message = result.Message });
        }
        return Ok(new { message = result.Message, data = result.Data });
    }

    [HttpPost("avatar")]
    public async Task<IActionResult> UploadAvatar(IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "Vui lòng chọn file ảnh hợp lệ." });
        }

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!allowedExtensions.Contains(ext))
        {
            return BadRequest(new { message = "Chỉ chấp nhận file ảnh định dạng JPG, PNG hoặc WEBP." });
        }

        if (file.Length > 5 * 1024 * 1024)
        {
            return BadRequest(new { message = "Dung lượng ảnh không được vượt quá 5MB." });
        }

        var userId = GetUserId();
        var profile = await _userService.GetProfileAsync(userId);
        if (profile == null)
        {
            return NotFound(new { message = "Không tìm thấy hồ sơ người dùng." });
        }

        using var stream = file.OpenReadStream();
        var avatarUrl = await _storageService.UploadFileAsync(stream, file.FileName, file.ContentType, "avatars");

        // Cập nhật avatar vào thông tin user giữ nguyên các trường khác
        var updateResult = await _userService.UpdateProfileAsync(userId, new UpdateProfileRequestDto(
            FullName: profile.FullName,
            BankBin: profile.BankBin,
            BankAccountNo: profile.BankAccountNo,
            BankAccountName: profile.BankAccountName,
            AvatarUrl: avatarUrl
        ));

        return Ok(new
        {
            message = "Tải ảnh đại diện lên Cloudflare R2 thành công.",
            avatarUrl = avatarUrl
        });
    }
}
