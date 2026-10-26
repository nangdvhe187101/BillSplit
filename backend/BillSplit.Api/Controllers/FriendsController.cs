using System.Security.Claims;
using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BillSplit.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FriendsController : ControllerBase
{
    private readonly IFriendService _friendService;

    public FriendsController(IFriendService friendService)
    {
        _friendService = friendService;
    }

    private Guid GetCurrentUserId()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(idClaim!);
    }

    [HttpGet]
    public async Task<IActionResult> GetFriends()
    {
        var userId = GetCurrentUserId();
        var friends = await _friendService.GetFriendsWithNetBalanceAsync(userId);
        return Ok(friends);
    }

    [HttpPost("add")]
    public async Task<IActionResult> AddFriend([FromBody] AddFriendRequestDto request)
    {
        var userId = GetCurrentUserId();
        var (success, message, data) = await _friendService.AddFriendByPhoneAsync(userId, request.PhoneNumber);
        if (!success)
        {
            return BadRequest(new { message });
        }
        return Ok(new { message, data });
    }

    [HttpGet("pending")]
    public async Task<IActionResult> GetPendingRequests()
    {
        var userId = GetCurrentUserId();
        var pending = await _friendService.GetPendingRequestsAsync(userId);
        return Ok(pending);
    }

    [HttpPost("{id}/accept")]
    public async Task<IActionResult> AcceptFriend(Guid id)
    {
        var userId = GetCurrentUserId();
        var (success, message) = await _friendService.AcceptFriendRequestAsync(userId, id);
        if (!success)
        {
            return BadRequest(new { message });
        }
        return Ok(new { message });
    }
}
