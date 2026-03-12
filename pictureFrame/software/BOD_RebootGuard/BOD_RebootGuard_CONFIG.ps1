# ============================================================
#  BOD Reboot Guard - Configuration
#  Edit these values before running the scripts
# ============================================================

# Your Resend API key (starts with "re_")
$RESEND_API_KEY = "CHANGE_ME"

# Sender email (must be from a verified domain in your Resend account,
# or use "onboarding@resend.dev" for testing)
$EMAIL_FROM = "onboarding@resend.dev"

# Where to send alerts
$EMAIL_TO = @("john@johnreine.com")

# ============================================================
#  Optional: Test name (shows up in email subject)
# ============================================================
$BOD_TEST_NAME = "AutoBOD SouthBurlington TEST04"
