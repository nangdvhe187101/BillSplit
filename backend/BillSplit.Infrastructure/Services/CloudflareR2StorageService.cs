using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;
using BillSplit.Application.Interfaces;
using Microsoft.Extensions.Configuration;

namespace BillSplit.Infrastructure.Services;

public class CloudflareR2StorageService : IStorageService
{
    private readonly IAmazonS3 _s3Client;
    private readonly string _bucketName;
    private readonly string _publicUrl;

    public CloudflareR2StorageService(IConfiguration configuration)
    {
        var r2Config = configuration.GetSection("CloudflareR2");
        var accessKey = r2Config["AccessKeyId"] ?? throw new InvalidOperationException("Thiếu cấu hình CloudflareR2:AccessKeyId");
        var secretKey = r2Config["SecretAccessKey"] ?? throw new InvalidOperationException("Thiếu cấu hình CloudflareR2:SecretAccessKey");
        var serviceUrl = r2Config["ServiceUrl"] ?? throw new InvalidOperationException("Thiếu cấu hình CloudflareR2:ServiceUrl");

        _bucketName = r2Config["BucketName"] ?? "sono-media";
        _publicUrl = (r2Config["PublicUrl"] ?? string.Empty).TrimEnd('/');

        var credentials = new BasicAWSCredentials(accessKey, secretKey);
        var s3Config = new AmazonS3Config
        {
            ServiceURL = serviceUrl,
            ForcePathStyle = true, // Bắt buộc cho Cloudflare R2
        };

        _s3Client = new AmazonS3Client(credentials, s3Config);
    }

    public async Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string folder = "avatars")
    {
        var extension = Path.GetExtension(fileName);
        var uniqueFileName = $"{folder}/{DateTime.UtcNow:yyyyMMdd}_{Guid.NewGuid():N}{extension}";

        var putRequest = new PutObjectRequest
        {
            BucketName = _bucketName,
            Key = uniqueFileName,
            InputStream = fileStream,
            ContentType = contentType,
            DisablePayloadSigning = true
        };

        await _s3Client.PutObjectAsync(putRequest);
        return $"{_publicUrl}/{uniqueFileName}";
    }

    public async Task<bool> DeleteFileAsync(string fileUrl)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(fileUrl) || !fileUrl.StartsWith(_publicUrl))
            {
                return false;
            }

            var key = fileUrl.Substring(_publicUrl.Length).TrimStart('/');
            await _s3Client.DeleteObjectAsync(_bucketName, key);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
