using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using ZYF.autoCAD.Services;

namespace ZYF.autoCAD.UI
{
    public enum UpdatePromptResult
    {
        Later,
        DownloadAndInstall,
        OpenDownload,
        SkipVersion
    }

    public class UpdatePromptForm : Form
    {
        public UpdatePromptResult Result { get; private set; } = UpdatePromptResult.Later;

        public UpdatePromptForm(UpdateManifest manifest, string localVersion, bool allowSkip)
        {
            const int margin = 18;
            const int buttonTop = 260;
            const int buttonGap = 8;

            Text = manifest.Title;
            StartPosition = FormStartPosition.CenterScreen;
            MinimizeBox = false;
            MaximizeBox = false;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            ClientSize = new Size(520, 320);

            var title = new Label
            {
                AutoSize = false,
                Font = new Font(Font.FontFamily, 12f, FontStyle.Bold),
                Location = new Point(margin, 18),
                Size = new Size(ClientSize.Width - margin * 2, 28),
                Text = $"发现新版本 {manifest.LatestVersion}"
            };

            var version = new Label
            {
                AutoSize = false,
                Location = new Point(margin, 52),
                Size = new Size(ClientSize.Width - margin * 2, 24),
                Text = $"当前版本：{localVersion}    发布日期：{manifest.ReleaseDate}"
            };

            var changelog = new TextBox
            {
                Location = new Point(margin, 84),
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Size = new Size(ClientSize.Width - margin * 2, 150),
                Text = BuildDetailText(manifest)
            };

            var buttons = new System.Collections.Generic.List<Button>();

            var installButton = new Button
            {
                Size = new Size(104, 32),
                Text = manifest.IsExternalDistribution ? "打开下载" : "下载并安装"
            };
            installButton.Click += (sender, args) =>
            {
                Result = manifest.IsExternalDistribution ? UpdatePromptResult.OpenDownload : UpdatePromptResult.DownloadAndInstall;
                Close();
            };
            buttons.Add(installButton);

            var openButton = new Button
            {
                Size = new Size(82, 32),
                Text = manifest.IsExternalDistribution ? "下载页" : "立即查看"
            };
            openButton.Click += (sender, args) =>
            {
                Result = UpdatePromptResult.OpenDownload;
                Close();
            };
            buttons.Add(openButton);

            if (allowSkip)
            {
                var skipButton = new Button
                {
                    Size = new Size(74, 32),
                    Text = "跳过"
                };
                skipButton.Click += (sender, args) =>
                {
                    Result = UpdatePromptResult.SkipVersion;
                    Close();
                };
                buttons.Add(skipButton);
            }

            var laterButton = new Button
            {
                Size = new Size(74, 32),
                Text = "稍后"
            };
            laterButton.Click += (sender, args) =>
            {
                Result = UpdatePromptResult.Later;
                Close();
            };
            buttons.Add(laterButton);

            Controls.Add(title);
            Controls.Add(version);
            Controls.Add(changelog);

            int currentRight = ClientSize.Width - margin;
            for (int i = buttons.Count - 1; i >= 0; i--)
            {
                var btn = buttons[i];
                btn.Location = new Point(currentRight - btn.Width, buttonTop);
                currentRight -= btn.Width + buttonGap;
                Controls.Add(btn);
            }
        }

        private static string BuildDetailText(UpdateManifest manifest)
        {
            var lines = manifest.Changelog.Select(item => $"- {item}").ToList();

            if (manifest.IsExternalDistribution)
            {
                lines.Add(string.Empty);
                lines.Add($"文件名：{manifest.FileName}");
                if (manifest.FileSize > 0)
                {
                    lines.Add($"文件大小：{manifest.FileSize} 字节");
                }
                if (!string.IsNullOrWhiteSpace(manifest.DownloadCode))
                {
                    lines.Add($"网盘提取码：{manifest.DownloadCode}");
                }
                lines.Add($"SHA-256：{manifest.Sha256}");
                lines.Add("请下载后自行核对 SHA-256。");
            }

            return string.Join("\r\n", lines);
        }
    }
}
