namespace BillSplit.Application.Interfaces;

public interface IStorageService
{
    /// <summary>
    /// Upload file ảnh lên Cloudflare R2 và trả về URL CDN công khai
    /// </summary>
    Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string folder = "avatars");

    /// <summary>
    /// Xóa file vật lý khỏi Cloudflare R2
    /// </summary>
    Task<bool> DeleteFileAsync(string fileUrl);
}
