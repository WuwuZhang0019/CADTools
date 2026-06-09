using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using ZYF.autoCAD.UI;

namespace ZYF.autoCAD.Services
{
    public static class UpdateService
    {
        public const string AppId = "zyf-cad-toolkit";
        public const string HomepageUrl = "https://www.nextoken.top/simple/cad-tools";
        public const string ManifestUrl = "https://www.nextoken.top/downloads/cad-tools/zyf-cad-toolkit.latest.json";

        private static readonly HttpClient HttpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(5)
        };

        public static async Task<UpdateCheckResult> CheckForUpdatesAsync(bool isManual)
        {
            var settings = UpdateSettings.Load();
            string localVersion = GetLocalVersion();

            if (!isManual && settings.LastCheckUpdateDate.HasValue &&
                DateTimeOffset.Now - settings.LastCheckUpdateDate.Value < TimeSpan.FromDays(30))
            {
                return new UpdateCheckResult
                {
                    Status = UpdateCheckStatus.FrequencySkipped,
                    LocalVersion = localVersion,
                    Message = "距离上次检查不足 30 天。"
                };
            }

            try
            {
                string url = isManual ? $"{ManifestUrl}?t={DateTime.Now:yyyyMMddHHmmss}" : ManifestUrl;
                string json = await HttpClient.GetStringAsync(url).ConfigureAwait(false);
                UpdateManifest manifest = ParseManifest(json);

                settings.LastCheckUpdateDate = DateTimeOffset.Now;
                settings.Save();

                if (!IsManifestValid(manifest))
                {
                    return new UpdateCheckResult
                    {
                        Status = UpdateCheckStatus.InvalidManifest,
                        LocalVersion = localVersion,
                        Manifest = manifest,
                        Message = "版本清单格式不完整或 appId 不匹配。"
                    };
                }

                Version local = ParseVersion(localVersion);
                Version online = ParseVersion(manifest.LatestVersion);
                bool isForced = IsForcedUpdate(local, manifest);

                Log($"check local={localVersion} online={manifest.LatestVersion} success=true");

                if (online <= local)
                {
                    return new UpdateCheckResult
                    {
                        Status = UpdateCheckStatus.Latest,
                        LocalVersion = localVersion,
                        Manifest = manifest,
                        Message = "当前已是最新版本。"
                    };
                }

                if (!isManual && !isForced && string.Equals(settings.SkippedVersion, manifest.LatestVersion, StringComparison.OrdinalIgnoreCase))
                {
                    return new UpdateCheckResult
                    {
                        Status = UpdateCheckStatus.VersionSkipped,
                        LocalVersion = localVersion,
                        Manifest = manifest,
                        Message = "已跳过此版本。"
                    };
                }

                return new UpdateCheckResult
                {
                    Status = UpdateCheckStatus.UpdateAvailable,
                    LocalVersion = localVersion,
                    Manifest = manifest,
                    IsForced = isForced,
                    Message = $"发现新版本 {manifest.LatestVersion}。"
                };
            }
            catch (Exception ex)
            {
                Log($"check local={localVersion} success=false error={ex.GetType().Name}");
                return new UpdateCheckResult
                {
                    Status = UpdateCheckStatus.Failed,
                    LocalVersion = localVersion,
                    Message = "检查更新失败，请稍后重试。"
                };
            }
        }

        public static void ShowAutomaticResult(UpdateCheckResult result)
        {
            if (result?.HasUpdate == true)
            {
                ShowUpdatePrompt(result, allowSkip: !result.IsForced);
            }
        }

        public static void ShowManualResult(UpdateCheckResult result)
        {
            if (result == null)
            {
                MessageBox.Show("检查更新失败，请稍后重试。", "检查更新", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            if (result.HasUpdate)
            {
                ShowUpdatePrompt(result, allowSkip: !result.IsForced);
                return;
            }

            MessageBoxIcon icon = result.Status == UpdateCheckStatus.Latest ? MessageBoxIcon.Information : MessageBoxIcon.Warning;
            string message = result.Status == UpdateCheckStatus.Failed
                ? $"{result.Message}\n\n官网：{HomepageUrl}"
                : result.Message;

            MessageBox.Show(message, "检查更新", MessageBoxButtons.OK, icon);
        }

        public static string GetLocalVersion()
        {
            Assembly assembly = typeof(UpdateService).Assembly;
            string version = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
            return string.IsNullOrWhiteSpace(version) ? assembly.GetName().Version.ToString() : version;
        }

        public static void OpenUrl(string url)
        {
            string target = string.IsNullOrWhiteSpace(url) ? HomepageUrl : url;
            Process.Start(new ProcessStartInfo
            {
                FileName = target,
                UseShellExecute = true
            });
        }

        public static void SkipVersion(string version)
        {
            if (string.IsNullOrWhiteSpace(version))
            {
                return;
            }

            UpdateSettings settings = UpdateSettings.Load();
            settings.SkippedVersion = version;
            settings.Save();
        }

        private static void ShowUpdatePrompt(UpdateCheckResult result, bool allowSkip)
        {
            using (var form = new UpdatePromptForm(result.Manifest, result.LocalVersion, allowSkip))
            {
                form.ShowDialog();
                if (form.Result == UpdatePromptResult.OpenDownload)
                {
                    OpenUrl(string.IsNullOrWhiteSpace(result.Manifest.DownloadUrl) ? result.Manifest.HomepageUrl : result.Manifest.DownloadUrl);
                }
                else if (form.Result == UpdatePromptResult.SkipVersion)
                {
                    SkipVersion(result.Manifest.LatestVersion);
                }
            }
        }

        private static UpdateManifest ParseManifest(string json)
        {
            var serializer = new JavaScriptSerializer();
            var values = serializer.Deserialize<Dictionary<string, object>>(json);
            return UpdateManifest.FromDictionary(values);
        }

        private static bool IsManifestValid(UpdateManifest manifest)
        {
            return manifest != null &&
                   string.Equals(manifest.AppId, AppId, StringComparison.OrdinalIgnoreCase) &&
                   !string.IsNullOrWhiteSpace(manifest.LatestVersion) &&
                   !string.IsNullOrWhiteSpace(manifest.DownloadUrl) &&
                   !string.IsNullOrWhiteSpace(manifest.HomepageUrl);
        }

        private static Version ParseVersion(string versionText)
        {
            string clean = (versionText ?? string.Empty).Split('+')[0].Split('-')[0].Trim();
            if (Version.TryParse(clean, out Version version))
            {
                return version;
            }

            return new Version(0, 0, 0);
        }

        private static bool IsForcedUpdate(Version localVersion, UpdateManifest manifest)
        {
            if (manifest.Mandatory)
            {
                return true;
            }

            if (string.IsNullOrWhiteSpace(manifest.MinimumSupportedVersion))
            {
                return false;
            }

            return localVersion < ParseVersion(manifest.MinimumSupportedVersion);
        }

        private static void Log(string message)
        {
            try
            {
                string logDirectory = Path.Combine(UpdateSettings.ConfigDirectory, "logs");
                Directory.CreateDirectory(logDirectory);
                string line = $"{DateTimeOffset.Now:O} {message}{Environment.NewLine}";
                File.AppendAllText(Path.Combine(logDirectory, "update.log"), line);
            }
            catch
            {
                try
                {
                    Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\n更新日志写入失败。");
                }
                catch
                {
                    // AutoCAD 尚未准备好时忽略日志错误。
                }
            }
        }
    }
}
