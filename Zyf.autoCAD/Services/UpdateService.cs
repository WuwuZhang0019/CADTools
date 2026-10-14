using System;
using System.ComponentModel;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Security.Cryptography;
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

        private static readonly HttpClient DownloadHttpClient = new HttpClient
        {
            Timeout = TimeSpan.FromMinutes(10)
        };

        public static UpdateCheckResult CachedResult { get; private set; }
        private static bool _hasNotifiedThisSession = false;

        public static void CheckAndNotifyUpdateOnCommandRun()
        {
            if (_hasNotifiedThisSession) return;

            if (CachedResult != null && CachedResult.HasUpdate)
            {
                _hasNotifiedThisSession = true;
                MessageBox.Show(
                    "检测到新版本可用，您可以在空闲时前往菜单栏的【关于】面板进行检查更新与升级。",
                    "张裕锋工具",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }
        }

        public static async Task<UpdateCheckResult> CheckForUpdatesAsync(bool isManual)
        {
            var settings = UpdateSettings.Load();
            string localVersion = GetLocalVersion();
            UpdateCheckResult result;

            try
            {
                string url = isManual ? $"{ManifestUrl}?t={DateTime.Now:yyyyMMddHHmmss}" : ManifestUrl;
                string json = await HttpClient.GetStringAsync(url).ConfigureAwait(false);
                UpdateManifest manifest = ParseManifest(json);

                settings.LastCheckUpdateDate = DateTimeOffset.Now;
                settings.Save();

                if (!IsManifestValid(manifest))
                {
                    result = new UpdateCheckResult
                    {
                        Status = UpdateCheckStatus.InvalidManifest,
                        LocalVersion = localVersion,
                        Manifest = manifest,
                        Message = "版本清单格式不完整或 appId 不匹配。"
                    };
                }
                else
                {
                    Version local = ParseVersion(localVersion);
                    Version online = ParseVersion(manifest.LatestVersion);
                    bool isForced = IsForcedUpdate(local, manifest);

                    Log($"check local={localVersion} online={manifest.LatestVersion} success=true");

                    if (online <= local)
                    {
                        result = new UpdateCheckResult
                        {
                            Status = UpdateCheckStatus.Latest,
                            LocalVersion = localVersion,
                            Manifest = manifest,
                            Message = "当前已是最新版本。"
                        };
                    }
                    else if (!isManual && !isForced && string.Equals(settings.SkippedVersion, manifest.LatestVersion, StringComparison.OrdinalIgnoreCase))
                    {
                        result = new UpdateCheckResult
                        {
                            Status = UpdateCheckStatus.VersionSkipped,
                            LocalVersion = localVersion,
                            Manifest = manifest,
                            Message = "已跳过此版本。"
                        };
                    }
                    else
                    {
                        result = new UpdateCheckResult
                        {
                            Status = UpdateCheckStatus.UpdateAvailable,
                            LocalVersion = localVersion,
                            Manifest = manifest,
                            IsForced = isForced,
                            Message = $"发现新版本 {manifest.LatestVersion}。"
                        };
                    }
                }
            }
            catch (Exception ex)
            {
                Log($"check local={localVersion} success=false error={ex.GetType().Name}");
                result = new UpdateCheckResult
                {
                    Status = UpdateCheckStatus.Failed,
                    LocalVersion = localVersion,
                    Message = "检查更新失败，请稍后重试。"
                };
            }

            CachedResult = result;
            return result;
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
            string localVersion = string.IsNullOrWhiteSpace(version) ? assembly.GetName().Version.ToString() : version;
            int metadataIndex = localVersion.IndexOf('+');
            return metadataIndex > 0 ? localVersion.Substring(0, metadataIndex) : localVersion;
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
                else if (form.Result == UpdatePromptResult.DownloadAndInstall)
                {
                    if (result.Manifest.IsExternalDistribution)
                    {
                        OpenUrl(string.IsNullOrWhiteSpace(result.Manifest.DownloadUrl) ? result.Manifest.HomepageUrl : result.Manifest.DownloadUrl);
                        return;
                    }

                    DownloadAndInstallAsync(result.Manifest).GetAwaiter().GetResult();
                }
                else if (form.Result == UpdatePromptResult.SkipVersion)
                {
                    SkipVersion(result.Manifest.LatestVersion);
                }
            }
        }

        private static async Task DownloadAndInstallAsync(UpdateManifest manifest)
        {
            if (manifest == null || string.IsNullOrWhiteSpace(manifest.DownloadUrl))
            {
                MessageBox.Show("版本清单没有提供安装包下载地址。", "下载更新", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            try
            {
                string installerPath = await DownloadInstallerAsync(manifest).ConfigureAwait(false);
                if (!ValidateInstallerHash(installerPath, manifest))
                {
                    TryDelete(installerPath);
                    MessageBox.Show("安装包校验失败，已阻止安装。请从官网重新下载。", "下载更新", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                var settings = UpdateSettings.Load();
                settings.LastDownloadPath = installerPath;
                settings.Save();

                DialogResult startInstall = MessageBox.Show(
                    "安装包已下载完成。请保存图纸并关闭 AutoCAD，然后开始安装。\n\n是否现在启动安装器？",
                    "下载更新",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Information);

                if (startInstall == DialogResult.Yes)
                {
                    LaunchInstaller(installerPath);
                }
            }
            catch (Exception ex)
            {
                Log($"download success=false url={manifest.DownloadUrl} error={ex.GetType().Name} message={ex.Message}");
                DialogResult openDownload = MessageBox.Show(
                    $"安装包下载失败：{ex.Message}\n\n是否打开下载页面手动下载？",
                    "下载更新",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning);

                if (openDownload == DialogResult.Yes)
                {
                    OpenUrl(string.IsNullOrWhiteSpace(manifest.DownloadUrl) ? manifest.HomepageUrl : manifest.DownloadUrl);
                }
            }
        }

        private static async Task<string> DownloadInstallerAsync(UpdateManifest manifest)
        {
            string downloadDirectory = Path.Combine(Path.GetTempPath(), "ZYFTools", "Downloads");
            Directory.CreateDirectory(downloadDirectory);

            string fileName = GetInstallerFileName(manifest);
            string installerPath = Path.Combine(downloadDirectory, fileName);
            string partialPath = installerPath + ".partial";

            TryDelete(partialPath);

            using (HttpResponseMessage response = await DownloadHttpClient.GetAsync(manifest.DownloadUrl).ConfigureAwait(false))
            {
                response.EnsureSuccessStatusCode();
                using (Stream source = await response.Content.ReadAsStreamAsync().ConfigureAwait(false))
                using (var target = new FileStream(partialPath, FileMode.Create, FileAccess.Write, FileShare.None, 81920, useAsync: true))
                {
                    await source.CopyToAsync(target).ConfigureAwait(false);
                }
            }

            TryDelete(installerPath);
            File.Move(partialPath, installerPath);
            Log($"download path={installerPath} success=true");
            return installerPath;
        }

        private static bool ValidateInstallerHash(string installerPath, UpdateManifest manifest)
        {
            if (string.IsNullOrWhiteSpace(manifest.Sha256))
            {
                DialogResult result = MessageBox.Show(
                    "版本清单没有提供 SHA-256 校验值，无法确认安装包完整性。\n\n测试环境可继续，正式发布前必须补齐校验值。是否继续安装？",
                    "下载更新",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning);

                return result == DialogResult.Yes;
            }

            string actualHash = ComputeSha256(installerPath);
            bool isMatch = string.Equals(actualHash, manifest.Sha256, StringComparison.OrdinalIgnoreCase);
            Log($"verify success={isMatch}");
            return isMatch;
        }

        private static void LaunchInstaller(string installerPath)
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = installerPath,
                    UseShellExecute = true,
                    Verb = "runas"
                });
                Log("installer launch=true");
            }
            catch (Win32Exception)
            {
                MessageBox.Show("安装已取消。", "下载更新", MessageBoxButtons.OK, MessageBoxIcon.Information);
                Log("installer launch=false canceled=true");
            }
        }

        private static string ComputeSha256(string filePath)
        {
            using (SHA256 sha256 = SHA256.Create())
            using (FileStream stream = File.OpenRead(filePath))
            {
                byte[] hash = sha256.ComputeHash(stream);
                return BitConverter.ToString(hash).Replace("-", string.Empty).ToLowerInvariant();
            }
        }

        private static string GetInstallerFileName(UpdateManifest manifest)
        {
            try
            {
                string fileName = Path.GetFileName(new Uri(manifest.DownloadUrl).LocalPath);
                if (!string.IsNullOrWhiteSpace(fileName))
                {
                    return fileName;
                }
            }
            catch
            {
                // 使用版本号生成兜底文件名。
            }

            return $"zyf-cad-toolkit-{manifest.LatestVersion}.exe";
        }

        private static void TryDelete(string path)
        {
            try
            {
                if (File.Exists(path))
                {
                    File.Delete(path);
                }
            }
            catch
            {
                // 删除失败时让后续文件操作给出明确异常。
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
