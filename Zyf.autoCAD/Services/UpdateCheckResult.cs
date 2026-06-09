namespace ZYF.autoCAD.Services
{
    public enum UpdateCheckStatus
    {
        Latest,
        UpdateAvailable,
        FrequencySkipped,
        VersionSkipped,
        InvalidManifest,
        Failed
    }

    public class UpdateCheckResult
    {
        public UpdateCheckStatus Status { get; set; }
        public UpdateManifest Manifest { get; set; }
        public string LocalVersion { get; set; }
        public string Message { get; set; }
        public bool IsForced { get; set; }

        public bool HasUpdate => Status == UpdateCheckStatus.UpdateAvailable && Manifest != null;
    }
}
