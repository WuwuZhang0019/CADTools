using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace ZYF.autoCAD.UI
{
    internal sealed class UpdateReminderForm : Form
    {
        private readonly Icon _reminderIcon;
        private readonly Bitmap _reminderImage;

        public UpdateReminderForm()
        {
            AutoScaleDimensions = new SizeF(96f, 96f);
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = SystemFonts.MessageBoxFont;
            Text = "更新提醒";
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MinimizeBox = false;
            MaximizeBox = false;
            ShowInTaskbar = false;
            BackColor = SystemColors.Window;
            ClientSize = new Size(480, 142);

            string iconPath = Path.Combine(
                Path.GetDirectoryName(typeof(UpdateReminderForm).Assembly.Location),
                "Resource", "Icon", "home.ico");
            if (File.Exists(iconPath))
            {
                _reminderIcon = new Icon(iconPath, new Size(32, 32));
                _reminderImage = _reminderIcon.ToBitmap();
                Icon = _reminderIcon;
            }

            var icon = new PictureBox
            {
                Image = _reminderImage,
                Location = new Point(24, 34),
                Size = new Size(32, 32),
                SizeMode = PictureBoxSizeMode.Zoom,
                TabStop = false
            };

            var title = new Label
            {
                Font = new Font(Font.FontFamily, 12f, FontStyle.Bold),
                Location = new Point(68, 16),
                Size = new Size(388, 26),
                Text = "张裕锋工具集"
            };

            var message = new Label
            {
                Location = new Point(68, 48),
                Size = new Size(388, 40),
                Text = "检测到新版本可用，您可以在空闲时前往菜单栏的【关于】面板进行检查更新与升级。"
            };

            var buttonPanel = new Panel
            {
                BackColor = SystemColors.Control,
                Dock = DockStyle.Bottom,
                Height = 50
            };
            var okButton = new Button
            {
                DialogResult = DialogResult.OK,
                Location = new Point(ClientSize.Width - 108, 12),
                Size = new Size(84, 26),
                Text = "确定",
                UseVisualStyleBackColor = true
            };
            buttonPanel.Controls.Add(okButton);

            Controls.Add(icon);
            Controls.Add(title);
            Controls.Add(message);
            Controls.Add(buttonPanel);
            AcceptButton = okButton;
            CancelButton = okButton;
        }

        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            if (disposing)
            {
                _reminderImage?.Dispose();
                _reminderIcon?.Dispose();
            }
        }
    }
}
