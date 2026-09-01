import logging
from dotenv import load_dotenv

load_dotenv()

from app.agent.email_agent import EmailAgent, RankedArticleDetail, EmailDigestResponse
from app.agent.curator_agent import CuratorAgent
from app.profiles.user_profile import USER_PROFILE
from app.database.repository import Repository
from app.services.email import send_email, digest_to_html

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


def generate_email_digest(hours: int = 24, top_n: int = 10) -> EmailDigestResponse:
    curator = CuratorAgent(USER_PROFILE)
    email_agent = EmailAgent(USER_PROFILE)
    repo = Repository()

    digests = repo.get_recent_digests(hours=hours)
    total = len(digests)

    if total == 0:
        raise ValueError("No digests available")

    logger.info(f"Ranking {total} digests for email generation")
    ranked_articles = curator.rank_digests(digests)

    if not ranked_articles:
        logger.error("Failed to rank digests")
        raise ValueError("Failed to rank articles")

    logger.info(f"Generating email digest with top {top_n} articles")

    article_details = [
        RankedArticleDetail(
            digest_id=a.digest_id,
            rank=a.rank,
            relevance_score=a.relevance_score,
            reasoning=a.reasoning,
            title=next((d["title"] for d in digests if d["id"] == a.digest_id), ""),
            summary=next((d["summary"] for d in digests if d["id"] == a.digest_id), ""),
            url=next((d["url"] for d in digests if d["id"] == a.digest_id), ""),
            article_type=next(
                (d["article_type"] for d in digests if d["id"] == a.digest_id), ""
            ),
        )
        for a in ranked_articles
    ]

    email_digest = email_agent.create_email_digest_response(
        ranked_articles=article_details, total_ranked=len(ranked_articles), limit=top_n
    )

    logger.info("Email digest generated successfully")
    logger.info("\n=== Email Introduction ===")
    logger.info(email_digest.introduction.greeting)
    logger.info(f"\n{email_digest.introduction.introduction}")

    return email_digest


def send_digest_email(hours: int = 24, top_n: int = 10) -> dict:
    repo = Repository()
    digests = repo.get_recent_digests(hours=hours)

    if len(digests) == 0:
        logger.info("No new digests to send. Nothing to send.")
        return {
            "success": True,
            "skipped": True,
            "message": "No new digests available",
            "articles_count": 0,
        }

    try:
        result = generate_email_digest(hours=hours, top_n=top_n)
        markdown_content = result.to_markdown()
        html_content = digest_to_html(result)

        subject = f"Daily AI News Digest - {result.introduction.greeting.split('for ')[-1] if 'for ' in result.introduction.greeting else 'Today'}"

        subscribers = repo.get_active_subscribers()
        recipient_emails = [sub.email for sub in subscribers]
        
        from app.services.email import MY_EMAIL, APP_PASSWORD
        if not recipient_emails:
            logger.info("No registered subscribers found in database. Using default/admin email if available.")
            if MY_EMAIL:
                recipient_emails = [MY_EMAIL]
            else:
                recipient_emails = ["fakejishil@gmail.com"]

        if not MY_EMAIL or not APP_PASSWORD:
            logger.warning("MY_EMAIL or APP_PASSWORD not configured. Printing digest to console and skipping email dispatch.")
            print("\n================== COMPILED DAILY DIGEST ==================")
            for email_addr in recipient_emails:
                gmail_name = email_addr.split("@")[0]
                personalized_intro = EmailIntroduction(
                    greeting=f"Hey {gmail_name}, here is your daily digest of AI news for {result.introduction.greeting.split('for ')[-1] if 'for ' in result.introduction.greeting else 'Today'}.",
                    introduction=result.introduction.introduction,
                )
                personalized_resp = EmailDigestResponse(
                    introduction=personalized_intro,
                    articles=result.articles,
                    total_ranked=result.total_ranked,
                    top_n=result.top_n,
                )
                print(f"--- Recipient: {email_addr} (Greeting: 'Hey {gmail_name}') ---")
                print(personalized_resp.to_markdown())
            print("===========================================================\n")
            digest_ids = [article.digest_id for article in result.articles]
            marked_count = repo.mark_digests_as_sent(digest_ids)
            return {
                "success": True,
                "subject": subject,
                "recipients": recipient_emails,
                "articles_count": len(result.articles),
                "marked_as_sent": marked_count,
            }

        logger.info(f"Sending daily digest to {len(recipient_emails)} subscribers...")
        for email_addr in recipient_emails:
            gmail_name = email_addr.split("@")[0]
            personalized_intro = EmailIntroduction(
                greeting=f"Hey {gmail_name}, here is your daily digest of AI news for {result.introduction.greeting.split('for ')[-1] if 'for ' in result.introduction.greeting else 'Today'}.",
                introduction=result.introduction.introduction,
            )
            personalized_resp = EmailDigestResponse(
                introduction=personalized_intro,
                articles=result.articles,
                total_ranked=result.total_ranked,
                top_n=result.top_n,
            )
            send_email(
                subject=subject,
                body_text=personalized_resp.to_markdown(),
                body_html=digest_to_html(personalized_resp),
                recipients=[email_addr],
            )
            logger.info(f"✓ Sent personalized digest to {email_addr} (Hey {gmail_name})")

        digest_ids = [article.digest_id for article in result.articles]
        marked_count = repo.mark_digests_as_sent(digest_ids)

        logger.info(f"All emails sent successfully to {len(recipient_emails)} recipients! Marked {marked_count} digests as sent.")
        return {
            "success": True,
            "subject": subject,
            "recipients_count": len(recipient_emails),
            "articles_count": len(result.articles),
            "marked_as_sent": marked_count,
        }
    except ValueError as e:
        logger.error(f"Error sending email: {e}")
        return {"success": False, "error": str(e)}


if __name__ == "__main__":
    result = send_digest_email(hours=24, top_n=10)
    if result["success"]:
        print("\n=== Email Digest Sent ===")
        print(f"Subject: {result['subject']}")
        print(f"Articles: {result['articles_count']}")
    else:
        print(f"Error: {result['error']}")
