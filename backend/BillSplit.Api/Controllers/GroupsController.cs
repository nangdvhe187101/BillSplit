using System.Security.Claims;
using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BillSplit.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class GroupsController : ControllerBase
{
    private readonly IGroupService _groupService;

    public GroupsController(IGroupService groupService)
    {
        _groupService = groupService;
    }

    private Guid GetCurrentUserId()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(idClaim!);
    }

    [HttpPost]
    public async Task<IActionResult> CreateGroup([FromBody] CreateGroupRequestDto request)
    {
        var userId = GetCurrentUserId();
        var (success, message, data) = await _groupService.CreateGroupAsync(userId, request);
        if (!success)
        {
            return BadRequest(new { message });
        }
        return CreatedAtAction(nameof(GetGroupDetail), new { id = data!.Id }, new { message, data });
    }

    [HttpGet]
    public async Task<IActionResult> GetMyGroups()
    {
        var userId = GetCurrentUserId();
        var groups = await _groupService.GetUserGroupsAsync(userId);
        return Ok(groups);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetGroupDetail(Guid id)
    {
        var userId = GetCurrentUserId();
        var group = await _groupService.GetGroupDetailAsync(userId, id);
        if (group == null)
        {
            return NotFound(new { message = "Không tìm thấy nhóm hoặc bạn không phải thành viên." });
        }
        return Ok(group);
    }

    [HttpPost("join")]
    public async Task<IActionResult> JoinGroup([FromBody] JoinGroupRequestDto request)
    {
        var userId = GetCurrentUserId();
        var (success, message, data) = await _groupService.JoinGroupByInviteCodeAsync(userId, request.InviteCode);
        if (!success)
        {
            return BadRequest(new { message });
        }
        return Ok(new { message, data });
    }
}
