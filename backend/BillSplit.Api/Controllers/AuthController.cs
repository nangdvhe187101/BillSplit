using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace BillSplit.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var result = await _authService.RegisterAsync(request);
        if (!result.Success)
        {
            return Conflict(new { message = result.Message });
        }

        return Created(string.Empty, result.Data);
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var result = await _authService.LoginAsync(request);
        if (!result.Success)
        {
            return Unauthorized(new { message = result.Message });
        }

        return Ok(result.Data);
    }

    [HttpPost("send-otp")]
    public async Task<IActionResult> SendOtp([FromBody] SendOtpRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var result = await _authService.SendOtpAsync(request);
        if (!result.Success)
        {
            return BadRequest(new { message = result.Message });
        }

        return Ok(new { message = result.Message });
    }

    [HttpPost("verify-otp")]
    public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var result = await _authService.VerifyOtpAsync(request);
        if (!result.Success)
        {
            return BadRequest(new { message = result.Message });
        }

        return Ok(new { message = result.Message });
    }

    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] SendOtpRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new { message = "Email không được để trống." });
        }

        var result = await _authService.ForgotPasswordAsync(request.Email);
        if (!result.Success)
        {
            return BadRequest(new { message = result.Message });
        }

        return Ok(new { message = result.Message });
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var result = await _authService.ResetPasswordAsync(request);
        if (!result.Success)
        {
            return BadRequest(new { message = result.Message });
        }

        return Ok(new { message = result.Message });
    }
}
