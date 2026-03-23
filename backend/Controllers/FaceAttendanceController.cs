using Microsoft.AspNetCore.Mvc;
using Dapper;
using System.Data;
using System.Text.Json;
using backend.Models;
using backend.Data;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FaceAttendanceController : ControllerBase
{
    private readonly DataBaseConnection _dataBaseConnection;
    private readonly ILogger<FaceAttendanceController> _logger;

    public FaceAttendanceController(DataBaseConnection dataBaseConnection, ILogger<FaceAttendanceController> logger)
    {
        _dataBaseConnection = dataBaseConnection;
        _logger = logger;
    }

    [HttpPost("mark")]
    public async Task<IActionResult> MarkFaceAttendance([FromBody] FaceAttendanceRequest request)
    {
        try
        {
            _logger.LogInformation("Marking attendance for {EmployeeId}", request.EmployeeId);
            using var conn = _dataBaseConnection.CreateConnection();
            
            await conn.ExecuteAsync(
                "sp_MarkFaceAttendance", 
                new { 
                    request.EmployeeId, 
                    Role = request.Role ?? "Unknown", 
                    PunchedInType = request.PunchedInType ?? "face",
                    UserId = request.UserId ?? 1 // Use provided UserId or default to system
                },
                commandType: CommandType.StoredProcedure
            );

            return Ok(new { status = "success", message = "Attendance marked successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error marking face attendance for {EmployeeId}", request.EmployeeId);
            return StatusCode(500, new { status = "error", message = ex.Message });
        }
    }

    [HttpPost("register-embedding")]
    public async Task<IActionResult> RegisterEmbedding([FromBody] FaceEmbeddingRequest request)
    {
        try
        {
            _logger.LogInformation("Registering embedding for {EmployeeId}", request.EmployeeId);
            using var conn = _dataBaseConnection.CreateConnection();
            var embeddingJson = JsonSerializer.Serialize(request.Embedding);
            
            await conn.ExecuteAsync(
                "sp_UpsertFaceEmbedding", 
                new { 
                    request.EmployeeId, 
                    Role = request.Role,
                    Embedding = embeddingJson,
                    UserId = request.UserId
                },
                commandType: CommandType.StoredProcedure
            );

            return Ok(new { status = "success", message = "Face embedding registered successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error registering face embedding for {EmployeeId}", request.EmployeeId);
            return StatusCode(500, new { status = "error", message = ex.Message });
        }
    }

    [HttpPost("match-embedding")]
    public async Task<IActionResult> MatchEmbedding([FromBody] FaceMatchRequest request)
    {
        try
        {
            _logger.LogInformation("Matching face embedding using stored procedure...");
            using var conn = _dataBaseConnection.CreateConnection();
            
            var allEmbeddings = await conn.QueryAsync<dynamic>(
                "sp_GetAllFaceEmbeddings", 
                commandType: CommandType.StoredProcedure
            );

            string? bestMatchEmployeeId = null;
            string? bestMatchRole = null;
            string? bestMatchName = null;
            string? bestMatchCode = null;
            double maxSimilarity = -1.0;
            double threshold = 0.75; 

            foreach (var row in allEmbeddings)
            {
                try {
                    float[] storedEmbedding = JsonSerializer.Deserialize<float[]>(row.embedding);
                    double similarity = CalculateCosineSimilarity(request.QueryEmbedding, storedEmbedding);

                    if (similarity > maxSimilarity)
                    {
                        maxSimilarity = similarity;
                        bestMatchEmployeeId = row.employee_id?.ToString();
                        bestMatchRole = row.role?.ToString();
                        bestMatchName = row.EmployeeName?.ToString();
                        bestMatchCode = row.EmployeeCode?.ToString();
                    }
                } catch (Exception ex) {
                    string empId = row.employee_id?.ToString() ?? "Unknown";
                    _logger.LogWarning("Skipping invalid embedding for employee {EmpId}: {Msg}", empId, ex.Message);
                }
            }

            if (maxSimilarity >= threshold)
            {
                _logger.LogInformation("Match found: {EmployeeName} ({EmployeeCode}) Conf: {Conf}%", bestMatchName, bestMatchCode, Math.Round(maxSimilarity * 100, 2));
                return Ok(new { 
                    status = "success", 
                    employee_id = bestMatchEmployeeId, 
                    employee_code = bestMatchCode,
                    name = bestMatchName,
                    role = bestMatchRole,
                    confidence = Math.Round(maxSimilarity * 100, 2)
                });
            }

            _logger.LogWarning("No match found above threshold {Threshold}. Best was {Best}", threshold, Math.Round(maxSimilarity, 4));
            return Ok(new { status = "error", message = "No matching face found" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error matching face embedding");
            return StatusCode(500, new { status = "error", message = ex.Message });
        }
    }

    private double CalculateCosineSimilarity(float[] vec1, float[] vec2)
    {
        if (vec1 == null || vec2 == null || vec1.Length != vec2.Length) return 0;
        double dotProduct = 0, norm1 = 0, norm2 = 0;
        for (int i = 0; i < vec1.Length; i++)
        {
            dotProduct += (double)vec1[i] * (double)vec2[i];
            norm1 += Math.Pow((double)vec1[i], 2);
            norm2 += Math.Pow((double)vec2[i], 2);
        }
        if (norm1 == 0 || norm2 == 0) return 0;
        return dotProduct / (Math.Sqrt(norm1) * Math.Sqrt(norm2));
    }

    // Request Models
    public class FaceEmbeddingRequest
    {
        public string EmployeeId { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public List<float> Embedding { get; set; } = new();
        public int? UserId { get; set; }
    }

    public class FaceMatchRequest
    {
        public float[] QueryEmbedding { get; set; } = Array.Empty<float>();
    }

    public class FaceAttendanceRequest
    {
        public string EmployeeId { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public string PunchedInType { get; set; } = "face";
        public int? UserId { get; set; }
    }
}
