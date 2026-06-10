using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Windows.Forms;
using ZYF.autoCAD.Services;

namespace ZYF.autoCAD.UI
{
    public class AboutForm : Form
    {
        public AboutForm()
        {
            Text = "关于张裕锋工具集";
            StartPosition = FormStartPosition.CenterScreen;
            MinimizeBox = false;
            MaximizeBox = false;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            ClientSize = new Size(500, 360);

            var title = new Label
            {
                AutoSize = false,
                Font = new Font(Font.FontFamily, 14f, FontStyle.Bold),
                Location = new Point(18, 18),
                Size = new Size(450, 32),
                Text = "张裕锋工具集"
            };

            var summary = new Label
            {
                AutoSize = false,
                Location = new Point(18, 58),
                Size = new Size(462, 210),
                Text = BuildSummaryText()
            };

            var checkButton = new Button
            {
                Location = new Point(74, 296),
                Size = new Size(90, 32),
                Text = "检查更新"
            };
            checkButton.Click += (sender, args) =>
            {
                Cursor oldCursor = Cursor.Current;
                try
                {
                    Cursor.Current = Cursors.WaitCursor;
                    UpdateCheckResult result = UpdateService.CheckForUpdatesAsync(isManual: true).GetAwaiter().GetResult();
                    summary.Text = BuildSummaryText();
                    UpdateService.ShowManualResult(result);
                }
                finally
                {
                    Cursor.Current = oldCursor;
                }
            };

            var websiteButton = new Button
            {
                Location = new Point(176, 296),
                Size = new Size(90, 32),
                Text = "打开官网"
            };
            websiteButton.Click += (sender, args) => UpdateService.OpenUrl(UpdateService.HomepageUrl);

            var uninstallButton = new Button
            {
                Location = new Point(278, 296),
                Size = new Size(90, 32),
                Text = "卸载软件"
            };
            uninstallButton.Click += (sender, args) => LaunchUninstaller();

            var closeButton = new Button
            {
                Location = new Point(390, 296),
                Size = new Size(90, 32),
                Text = "关闭"
            };
            closeButton.Click += (sender, args) => Close();

            Controls.Add(title);
            Controls.Add(summary);
            Controls.Add(checkButton);
            Controls.Add(websiteButton);
            Controls.Add(uninstallButton);
            Controls.Add(closeButton);
        }

        private static string BuildSummaryText()
        {
            string acadVersion = ReadAutoCadVersion();
            Assembly assembly = typeof(AboutForm).Assembly;

            string latestVersionStr = "最新版本：点击【检查更新】获取";
            string releaseDateStr = "发布时间：--";

            var cached = UpdateService.CachedResult;
            if (cached != null)
            {
                if (cached.Status == UpdateCheckStatus.Failed)
                {
                    latestVersionStr = "最新版本：获取失败";
                }
                else if (cached.Status == UpdateCheckStatus.Latest)
                {
                    latestVersionStr = "最新版本：已是最新版本";
                }
                else if (cached.Manifest != null)
                {
                    latestVersionStr = $"最新版本：{cached.Manifest.LatestVersion}";
                    if (!string.IsNullOrWhiteSpace(cached.Manifest.ReleaseDate))
                    {
                        releaseDateStr = $"发布时间：{cached.Manifest.ReleaseDate}";
                    }
                }
            }

            return string.Join(Environment.NewLine, new[]
            {
                $"当前版本：{UpdateService.GetLocalVersion()}",
                latestVersionStr,
                releaseDateStr,
                $"官网：{UpdateService.HomepageUrl}",
                "作者：张裕锋",
                "版权所有 © 张裕锋",
                string.Empty,
                $"AutoCAD 版本：{acadVersion}",
                $"插件加载路径：{assembly.Location}",
                $".NET 运行时版本：{Environment.Version}"
            });
        }

        private static string ReadAutoCadVersion()
        {
            try
            {
                object value = Autodesk.AutoCAD.ApplicationServices.Core.Application.GetSystemVariable("ACADVER");
                return Convert.ToString(value) ?? "未知";
            }
            catch
            {
                return "未知";
            }
        }

        private static void LaunchUninstaller()
        {
            try
            {
                string processName = Path.GetFileNameWithoutExtension("09 CAD开图自动选字体.exe");
                foreach (Process process in Process.GetProcessesByName(processName))
                {
                    process.Kill();
                    process.WaitForExit(1000);
                }

                string uninstallPath = @"C:\ProgramData\Autodesk\ApplicationPlugins\ZYF.bundle\unins000.exe";
                if (!File.Exists(uninstallPath))
                {
                    MessageBox.Show("找不到卸载程序。", "卸载软件", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }

                Process.Start(uninstallPath);
                MessageBox.Show("软件卸载程序已启动，请按照提示完成卸载。", "卸载软件", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"启动卸载程序失败：{ex.Message}", "卸载软件", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
