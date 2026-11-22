# ClickHouse — Database Reliability Engineer, Core Team

**Application:** https://jobs.ashbyhq.com/clickhouse/c3617664-a679-406a-8fd5-71d51a407243/application  
**Posting ID:** `c3617664-a679-406a-8fd5-71d51a407243`  
**Location:** Remote in Germany, Netherlands or UK  
**Packet:** `submissions/clickhouse/lebenslauf.pdf`  
**Form inspected:** 2026-11-22  
**Form ID:** `5c9b0d2a-3365-4f11-aaa6-1b3866b8790a`

The live Ashby form has one section, **11 fields**, and one **Submit** control. There is no custom essay question.

## Field mapping

| # | Ashby label | Path | Type | Required | Answer |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 1 | Name | `_systemfield_name` | String | Yes | **Matt Ji** |
| 2 | Email | `_systemfield_email` | Email | Yes | **matt@bountystash.com** |
| 3 | Resume | `_systemfield_resume` | File | Yes | Upload **`submissions/clickhouse/lebenslauf.pdf`** |
| 4 | Phone | `phone` | String | No | Use the phone number printed on `lebenslauf.pdf`; leave blank if you prefer not to add it |
| 5 | Cover Letter | `cover_letter` | File | No | **Leave blank** — this packet contains the tailored CV only |
| 6 | LinkedIn Profile | `question_15756194004` | String | No | **https://linkedin.com/in/mattji** |
| 7 | Website or Github | `question_15756195004` | String | No | **https://github.com/shaoyanji** |
| 8 | What is your current location? | `question_15756196004` | String | Yes | **Gutach im Breisgau, Baden-Württemberg, Germany** |
| 9 | Will you require sponsorship from ClickHouse for your right to work in your current location? | `question_15756197004` | Boolean | Yes | **No** |
| 10 | Do you have reliability engineering experience related to ClickHouse or another SQL database in production? | `question_15756198004` | Boolean | Yes | **Yes** |
| 11 | By selecting Yes, I am consenting to the use of AI for evaluating my candidacy. | `question_15756199004` | Boolean | Yes | **Yes** — required to submit; this is a consent choice, not a factual claim |

## Answer notes

**Sponsorship — No.** The CV states: “US citizen with German permanent residence; no sponsorship required.” Germany is one of the three eligible locations.

**SQL reliability — Yes, with a qualification.** The evidence is production SQL work with PostgreSQL and MySQL, not ClickHouse. The CV’s skills section lists SQL, PostgreSQL and MySQL, and the Bountystash work covers operated production services. Do not claim ClickHouse production experience. If the form ever adds an elaboration field, use:

> I have operated PostgreSQL- and MySQL-backed production services and handled their reliability, debugging and operational ownership. I have not run ClickHouse in production; the ClickHouse-specific internals are the area I would ramp on first.

**AI consent — Yes.** This is the only answer that lets the application proceed through the required consent field. Change it to No only if you object to AI-assisted evaluation and are willing to risk the form blocking submission.

**Cover letter — intentionally blank.** The Ashby field is optional. The packet contains a tailored two-page CV and its selection audit, not a cover letter.

## Submission sequence

1. Open the application URL above.
2. Upload `submissions/clickhouse/lebenslauf.pdf` to **Resume**.
3. Confirm Ashby’s resume autofill did not alter the name, email, location or phone.
4. Fill the remaining fields from the table.
5. Leave **Cover Letter** empty.
6. Review the two boolean answers, then submit.
7. After submission, set the application record to `stage=applied` with the submission date.
