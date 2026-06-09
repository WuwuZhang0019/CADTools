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
            Text = manifest.Title;
            StartPosition = FormStartPosition.CenterScreen;
            MinimizeBox = false;
            MaximizeBox = false;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            ClientSize = new Size(460, 320);

            var title = new Label
            {
                AutoSize = false,
                Font = new Font(Font.FontFamily, 12f, FontStyle.Bold),
                Location = new Point(18, 18),
                Size = new Size(420, 28),
                Text = $"发现新版本 {manifest.LatestVersion}"
            };

            var version = new Label
            {
                AutoSize = false,
                Location = new Point(18, 52),
                Size = new Size(420, 24),
                Text = $"当前版本：{localVersion}    发布日期：{manifest.ReleaseDate}"
            };

            var changelog = new TextBox
            {
                Location = new Point(18, 84),
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Size = new Size(420, 150),
                Text = BuildDetailText(manifest)
            };

            var installButton = new Button
            {
                Location = new Point(130, 260),
                Size = new Size(98, 32),
                Text = manifest.IsExternalDistribution ? "打开网盘" : "下载并安装"
            };
            installButton.Click += (sender, args) =>
            {
                Result = manifest.IsExternalDistribution ? UpdatePromptResult.OpenDownload : UpdatePromptResult.DownloadAndInstall;
                Close();
            };

            var openButton = new Button
            {
                Location = new Point(236, 260),
                Size = new Size(74, 32),
                Text = manifest.IsExternalDistribution ? "官网" : "立即查看"
            };
            openButton.Click += (sender, args) =>
            {
                Result = UpdatePromptResult.OpenDownload;
                Close();
            };

            var laterButton = new Button
            {
                Location = new Point(390, 260),
                Size = new Size(90, 32),
                Text = "稍后"
            };
            laterButton.Click += (sender, args) =>
            {
                Result = UpdatePromptResult.Later;
                Close();
            };

            Controls.Add(title);
            Controls.Add(version);
            Controls.Add(changelog);
            Controls.Add(installButton);
            Controls.Add(openButton);
            Controls.Add(laterButton);

            if (allowSkip)
            {
                var skipButton = new Button
                {
                    Location = new Point(318, 260),
                    Size = new Size(64, 32),
                    Text = "跳过"
                };
                skipButton.Click += (sender, args) =>
                {
                    Result = UpdatePromptResult.SkipVersion;
                    Close();
                };
                Controls.Add(skipButton);
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
                lines.Add("请从网盘下载后自行核对 SHA-256。");
            }

            return string.Join("\r\n", lines);
        }
    }
}
