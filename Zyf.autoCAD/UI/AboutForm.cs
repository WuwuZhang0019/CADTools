using System;
using System.Drawing;
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
                Size = new Size(450, 72),
                Text = $"当前版本：{UpdateService.GetLocalVersion()}\r\n官网：{UpdateService.HomepageUrl}\r\n作者：WuwuZhang\r\n版权所有 © WuwuZhang"
            };

            var detail = new TextBox
            {
                Location = new Point(18, 138),
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Size = new Size(462, 130),
                Text = BuildDetailText()
            };

            var checkButton = new Button
            {
                Location = new Point(176, 296),
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
                    UpdateService.ShowManualResult(result);
                }
                finally
                {
                    Cursor.Current = oldCursor;
                }
            };

            var websiteButton = new Button
            {
                Location = new Point(278, 296),
                Size = new Size(90, 32),
                Text = "打开官网"
            };
            websiteButton.Click += (sender, args) => UpdateService.OpenUrl(UpdateService.HomepageUrl);

            var closeButton = new Button
            {
                Location = new Point(390, 296),
                Size = new Size(90, 32),
                Text = "关闭"
            };
            closeButton.Click += (sender, args) => Close();

            Controls.Add(title);
            Controls.Add(summary);
            Controls.Add(detail);
            Controls.Add(checkButton);
            Controls.Add(websiteButton);
            Controls.Add(closeButton);
        }

        private static string BuildDetailText()
        {
            string acadVersion = ReadAutoCadVersion();
            Assembly assembly = typeof(AboutForm).Assembly;

            return string.Join(Environment.NewLine, new[]
            {
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
    }
}
