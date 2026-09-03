import os
import smtplib
import html
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv
load_dotenv()


MY_EMAIL = os.getenv("MY_EMAIL")
APP_PASSWORD = os.getenv("APP_PASSWORD")


def send_email(subject: str, body_text: str, body_html: str = None, recipients: list = None):
    if recipients is None:
        if not MY_EMAIL:
            raise ValueError("MY_EMAIL environment variable is not set")
        recipients = [MY_EMAIL]
    
    recipients = [r for r in recipients if r is not None]
    if not recipients:
        raise ValueError("No valid recipients provided")
    
    if not MY_EMAIL:
        raise ValueError("MY_EMAIL environment variable is not set")
    if not APP_PASSWORD:
        raise ValueError("APP_PASSWORD environment variable is not set")
    
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = MY_EMAIL
    msg["To"] = ", ".join(recipients)
    
    part1 = MIMEText(body_text, "plain")
    msg.attach(part1)
    
    if body_html:
        part2 = MIMEText(body_html, "html")
        msg.attach(part2)
    
    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
        smtp.login(MY_EMAIL, APP_PASSWORD)
        smtp.sendmail(MY_EMAIL, recipients, msg.as_string())


def markdown_to_html(markdown_text: str) -> str:
    import markdown
    html = markdown.markdown(markdown_text, extensions=['extra', 'nl2br'])

    return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #ffffff;
        }}
        h2 {{
            font-size: 18px;
            font-weight: 600;
            color: #1a1a1a;
            margin-top: 24px;
            margin-bottom: 8px;
            line-height: 1.4;
        }}
        h3 {{
            font-size: 16px;
            font-weight: 600;
            color: #1a1a1a;
            margin-top: 20px;
            margin-bottom: 8px;
            line-height: 1.4;
        }}
        p {{
            margin: 8px 0;
            color: #4a4a4a;
        }}
        strong {{
            font-weight: 600;
            color: #1a1a1a;
        }}
        em {{
            font-style: italic;
            color: #666;
        }}
        a {{
            color: #0066cc;
            text-decoration: none;
            font-weight: 500;
        }}
        a:hover {{
            text-decoration: underline;
        }}
        hr {{
            border: none;
            border-top: 1px solid #e5e5e5;
            margin: 20px 0;
        }}
        .greeting {{
            font-size: 16px;
            font-weight: 500;
            color: #1a1a1a;
            margin-bottom: 12px;
        }}
        .introduction {{
            color: #4a4a4a;
            margin-bottom: 20px;
        }}
        .article-link {{
            display: inline-block;
            margin-top: 8px;
            color: #0066cc;
            font-size: 14px;
        }}
    </style>
</head>
<body>
{html}
</body>
</html>"""


def digest_to_html(digest_response) -> str:
    from app.agent.email_agent import EmailDigestResponse
    
    if not isinstance(digest_response, EmailDigestResponse):
        return markdown_to_html(digest_response.to_markdown() if hasattr(digest_response, 'to_markdown') else str(digest_response))
    
    html_parts = []
    greeting_html = markdown.markdown(digest_response.introduction.greeting, extensions=['extra', 'nl2br'])
    introduction_html = markdown.markdown(digest_response.introduction.introduction, extensions=['extra', 'nl2br'])
    html_parts.append(f'<div class="greeting">{greeting_html}</div>')
    html_parts.append(f'<div class="introduction">{introduction_html}</div>')
    html_parts.append('<hr>')
    
    for article in digest_response.articles:
        html_parts.append(f'<h3>{html.escape(article.title)}</h3>')
        summary_html = markdown.markdown(article.summary, extensions=['extra', 'nl2br'])
        html_parts.append(f'<div>{summary_html}</div>')
        html_parts.append(f'<p><a href="{html.escape(article.url)}" class="article-link">Read more →</a></p>')
        html_parts.append('<hr>')
    
    html_content = '\n'.join(html_parts)
    
    return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #ffffff;
        }}
        h3 {{
            font-size: 16px;
            font-weight: 600;
            color: #1a1a1a;
            margin-top: 20px;
            margin-bottom: 8px;
            line-height: 1.4;
        }}
        p {{
            margin: 8px 0;
            color: #4a4a4a;
        }}
        strong {{
            font-weight: 600;
            color: #1a1a1a;
        }}
        em {{
            font-style: italic;
            color: #666;
        }}
        a {{
            color: #0066cc;
            text-decoration: none;
            font-weight: 500;
        }}
        a:hover {{
            text-decoration: underline;
        }}
        hr {{
            border: none;
            border-top: 1px solid #e5e5e5;
            margin: 20px 0;
        }}
        .greeting {{
            font-size: 16px;
            font-weight: 500;
            color: #1a1a1a;
            margin-bottom: 12px;
        }}
        .introduction {{
            color: #4a4a4a;
            margin-bottom: 20px;
        }}
        .article-link {{
            display: inline-block;
            margin-top: 8px;
            color: #0066cc;
            font-size: 14px;
        }}
        .greeting p {{
            margin: 0;
        }}
        .introduction p {{
            margin: 0;
        }}
        div {{
            margin: 8px 0;
            color: #4a4a4a;
        }}
        div p {{
            margin: 4px 0;
        }}
    </style>
</head>
<body>
{html_content}
</body>
</html>"""


def send_email_to_self(subject: str, body: str):
    if not MY_EMAIL:
        raise ValueError("MY_EMAIL environment variable is not set. Please set it in your .env file.")
    send_email(subject, body, recipients=[MY_EMAIL])


def send_welcome_email(recipient_email: str) -> bool:
    """
    Dispatches a formalized welcome email with branding and logo
    to a newly registered subscriber.
    """
    try:
        user_name = recipient_email.split("@")[0].capitalize()
        subject = "🎉 Welcome to AI News Aggregator — Your Daily Intelligence Briefing is Active"
        
        logo_url = "https://raw.githubusercontent.com/gggshil/ai-news-aggregator/main/mobile_client/assets/images/navbar_logo.png"
        
        body_text = f"""Hello {user_name},

Congratulations & Welcome to AI News Aggregator!

Your daily AI news subscription has been activated successfully. 
Starting today, you will receive our autonomous, AI-curated intelligence briefing delivered directly to your inbox every morning at 5:00 AM UTC.

WHAT YOU CAN EXPECT DAILY:
• Multi-Source Ingestion: Top announcements and papers scraped from OpenAI, Anthropic, DeepSeek, Google DeepMind, and arXiv.
• AI Synthesis: The most significant breakthroughs analyzed and prioritized for signal over noise.
• Mobile & Web Synchronization: Access your daily digests anytime via your mobile Android and Web app.

Thank you for joining our community of builders and researchers.

Best regards,
The AI News Aggregator Team
"""

        body_html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to AI News Aggregator</title>
</head>
<body style="margin: 0; padding: 0; background-color: #08090D; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #E2E8F0;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #08090D; padding: 32px 16px;">
        <tr>
            <td align="center">
                <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 600px; background-color: #10121A; border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 16px; overflow: hidden; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6);">
                    
                    <!-- Header with Logo -->
                    <tr>
                        <td align="center" style="padding: 36px 24px 20px; background: linear-gradient(180deg, #141724 0%, #10121A 100%); border-bottom: 1px solid rgba(255, 255, 255, 0.06);">
                            <img src="{logo_url}" alt="AI News Aggregator Logo" width="68" height="68" style="display: block; margin-bottom: 14px; border-radius: 12px;" />
                            <h1 style="margin: 0; font-size: 22px; font-weight: 700; color: #FFFFFF; letter-spacing: -0.3px;">AI News Aggregator</h1>
                            <p style="margin: 6px 0 0; font-size: 13px; color: #818CF8; letter-spacing: 0.5px; text-transform: uppercase; font-weight: 600;">Autonomous Daily AI Intelligence</p>
                        </td>
                    </tr>

                    <!-- Body Content -->
                    <tr>
                        <td style="padding: 32px 30px;">
                            <h2 style="margin: 0 0 14px; font-size: 19px; font-weight: 600; color: #F1F5F9;">Congratulations & Welcome!</h2>
                            <p style="margin: 0 0 16px; font-size: 15px; line-height: 1.6; color: #94A3B8;">
                                Hello <strong style="color: #F8FAFC;">{user_name}</strong>,
                            </p>
                            <p style="margin: 0 0 24px; font-size: 15px; line-height: 1.6; color: #94A3B8;">
                                Your subscription has been activated. Starting today, you will receive our autonomous, AI-curated intelligence briefing delivered directly to your inbox every morning at <strong style="color: #F8FAFC;">5:00 AM UTC</strong>.
                            </p>

                            <!-- Features Card -->
                            <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #0B0D14; border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 12px; padding: 20px; margin-bottom: 28px;">
                                <tr>
                                    <td>
                                        <p style="margin: 0 0 12px; font-size: 12px; font-weight: 700; color: #818CF8; letter-spacing: 0.8px; text-transform: uppercase;">What You Will Receive Daily</p>
                                        
                                        <div style="margin-bottom: 12px;">
                                            <strong style="font-size: 14px; color: #F8FAFC;">⚡ Multi-Source Ingestion</strong>
                                            <p style="margin: 3px 0 0; font-size: 13px; color: #94A3B8; line-height: 1.5;">Direct scraping from OpenAI, Anthropic, DeepSeek, Google DeepMind, and top arXiv machine learning papers.</p>
                                        </div>

                                        <div style="margin-bottom: 12px;">
                                            <strong style="font-size: 14px; color: #F8FAFC;">🧠 AI-Powered Synthesis</strong>
                                            <p style="margin: 3px 0 0; font-size: 13px; color: #94A3B8; line-height: 1.5;">Every article is analyzed, scored, and ranked by Gemini to give you pure signal without promotional noise.</p>
                                        </div>

                                        <div>
                                            <strong style="font-size: 14px; color: #F8FAFC;">📱 Synchronized Mobile Access</strong>
                                            <p style="margin: 3px 0 0; font-size: 13px; color: #94A3B8; line-height: 1.5;">Your digests are instantly synced and readable inside your Android APK and Web dashboard.</p>
                                        </div>
                                    </td>
                                </tr>
                            </table>

                            <p style="margin: 0 0 8px; font-size: 14px; line-height: 1.6; color: #94A3B8;">
                                No further setup is required on your part. Your first morning edition will arrive tomorrow!
                            </p>
                            
                            <p style="margin: 24px 0 0; font-size: 14px; line-height: 1.6; color: #CBD5E1;">
                                Warm regards,<br />
                                <strong style="color: #FFFFFF;">The AI News Aggregator Team</strong>
                            </p>
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td align="center" style="padding: 20px 24px; background-color: #0A0C12; border-top: 1px solid rgba(255, 255, 255, 0.05); font-size: 12px; color: #64748B;">
                            <p style="margin: 0 0 4px;">You received this email because you subscribed at <strong>AI News Aggregator</strong>.</p>
                            <p style="margin: 0;">© 2026 AI News Aggregator • Built for Builders & Researchers</p>
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</body>
</html>
"""

        send_email(
            subject=subject,
            body_text=body_text,
            body_html=body_html,
            recipients=[recipient_email]
        )
        return True
    except Exception as e:
        import logging
        logging.getLogger("ai_news_api").warning(f"Could not send welcome email to {recipient_email}: {e}")
        return False


def send_otp_email(recipient_email: str, otp_code: str) -> bool:
    """
    Dispatches a secure 6-digit verification code OTP email.
    """
    try:
        subject = "Your AI News Aggregator verification code"
        logo_url = "https://raw.githubusercontent.com/gggshil/ai-news-aggregator/main/mobile_client/assets/images/navbar_logo.png"

        body_text = f"""Hello,

Use the following verification code to sign in to AI News Aggregator:

{otp_code}

This code will expire in 10 minutes.

If you did not request this code, you can safely ignore this email.

Thanks,
AI News Aggregator
"""

        body_html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI News Aggregator Verification Code</title>
</head>
<body style="margin: 0; padding: 0; background-color: #08090D; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #E2E8F0;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #08090D; padding: 36px 16px;">
        <tr>
            <td align="center">
                <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 540px; background-color: #10121A; border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 16px; overflow: hidden; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6);">
                    
                    <!-- Header with Logo -->
                    <tr>
                        <td align="center" style="padding: 32px 24px 20px; background: linear-gradient(180deg, #141724 0%, #10121A 100%); border-bottom: 1px solid rgba(255, 255, 255, 0.06);">
                            <img src="{logo_url}" alt="AI News Aggregator Logo" width="58" height="58" style="display: block; margin-bottom: 12px; border-radius: 12px;" />
                            <h1 style="margin: 0; font-size: 20px; font-weight: 700; color: #FFFFFF; letter-spacing: -0.3px;">AI News Aggregator</h1>
                            <p style="margin: 4px 0 0; font-size: 12px; color: #818CF8; letter-spacing: 0.5px; text-transform: uppercase; font-weight: 600;">Autonomous Daily AI Intelligence</p>
                        </td>
                    </tr>

                    <!-- Body Content -->
                    <tr>
                        <td style="padding: 32px 30px; text-align: center;">
                            <h2 style="margin: 0 0 10px; font-size: 18px; font-weight: 600; color: #F1F5F9;">Your Verification Code</h2>
                            <p style="margin: 0 0 24px; font-size: 14px; line-height: 1.5; color: #94A3B8;">
                                Use the 6-digit verification code below to sign in or confirm your daily digest subscription:
                            </p>

                            <!-- OTP Box -->
                            <div style="background-color: #0B0D14; border: 1px solid #4F46E5; border-radius: 12px; padding: 22px 16px; margin: 0 auto 24px; display: inline-block; min-width: 260px;">
                                <span style="font-family: 'SF Mono', Consolas, Menlo, Monaco, monospace; font-size: 36px; font-weight: 700; letter-spacing: 10px; color: #6366F1; display: block; text-align: center;">
                                    {otp_code}
                                </span>
                            </div>

                            <p style="margin: 0 0 16px; font-size: 13px; color: #94A3B8;">
                                ⏱️ This code will expire in <strong style="color: #F8FAFC;">10 minutes</strong>.
                            </p>
                            
                            <p style="margin: 0 0 4px; font-size: 12px; color: #64748B; line-height: 1.5;">
                                If you did not request this verification code, you can safely ignore this email.
                            </p>
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td align="center" style="padding: 18px 24px; background-color: #0A0C12; border-top: 1px solid rgba(255, 255, 255, 0.05); font-size: 11px; color: #64748B;">
                            <p style="margin: 0 0 4px;">Sent by <strong>AI News Aggregator</strong></p>
                            <p style="margin: 0;">© 2026 AI News Aggregator • Built for Builders & Researchers</p>
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</body>
</html>
"""

        send_email(
            subject=subject,
            body_text=body_text,
            body_html=body_html,
            recipients=[recipient_email]
        )
        return True
    except Exception as e:
        import logging
        logging.getLogger("ai_news_api").warning(f"Could not send OTP email to {recipient_email}: {e}")
        return False
