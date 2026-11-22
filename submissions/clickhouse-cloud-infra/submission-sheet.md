# ClickHouse - Cloud Database Infrastructure Engineer (EMEA Remote)

**Application:** https://jobs.ashbyhq.com/clickhouse/086c4dd1-217d-48f8-9d62-e57542e16dbe/application  
**Posting ID:** `086c4dd1-217d-48f8-9d62-e57542e16dbe`  
**Location:** Remote EMEA; Germany explicitly eligible  
**Packet:** `submissions/clickhouse-cloud-infra/lebenslauf.pdf`  
**Form inspected:** 2026-11-22  
**Form ID:** `ab2376ec-4ad1-499d-a609-3515b4b0bb7e`

The live Ashby form has one section, **13 fields**, and one **Submit** control.

## Field mapping

| # | Ashby label | Path | Type | Required | Answer |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 1 | Name | `_systemfield_name` | String | Yes | **Matt Ji** |
| 2 | Email | `_systemfield_email` | Email | Yes | **matt@bountystash.com** |
| 3 | Resume | `_systemfield_resume` | File | Yes | Upload **`submissions/clickhouse-cloud-infra/lebenslauf.pdf`** |
| 4 | Phone | `phone` | String | No | Use the phone number printed on `lebenslauf.pdf` |
| 5 | Cover Letter | `cover_letter` | File | No | **Leave blank**; this packet contains the tailored CV only |
| 6 | LinkedIn or GitHub Profile | `question_15210264004` | String | Yes | **https://github.com/shaoyanji** |
| 7 | Website | `question_15210265004` | String | No | **https://matt.bountystash.com** |
| 8 | Will you require sponsorship or transfer of sponsorship to obtain or extend your right to work in the US? | `question_15210266004` | Boolean | Yes | **No** |
| 9 | Where are you currently located? | `question_15210267004` | String | Yes | **Gutach im Breisgau, Baden-Wuerttemberg, Germany** |
| 10 | Have you worked on database internals or distributed systems? | `question_15210268004` | Boolean | Yes | **Yes** |
| 11 | Do you have experience working with systems-level or database performance tuning or profilers? | `question_15210269004` | Boolean | Yes | **Yes** |
| 12 | If Yes, describe your experience with a specific example(s) | `question_15210270004` | String | Yes | **See the free-text answer below** |
| 13 | By selecting Yes, I am consenting to the use of AI for evaluating my candidacy. | `question_15653548004` | Boolean | Yes | **Yes** |

## Free-text answer for field 12

> On a thirteen-host NixOS fleet, I pin each host's kernel track and kernel parameters and run a sentinel that records disk and PSI pressure every fifteen minutes. I use those signals to separate I/O contention from CPU or memory pressure before changing storage or kernel settings; every generation rolls back with one command. I also operate a PostgreSQL-backed mail archive with IMAP ingestion, a Python classification pass, and a tailnet API. The fleet and the event-sourced Go service are my distributed-systems work; I have not worked on database internals. I have not used perf or eBPF profilers in production; my performance work is metric- and log-driven.

## Answer notes

**Sponsorship - No.** The question asks about US work authorization. Matt is a US citizen, so no sponsorship or transfer is needed. The role itself is EMEA remote.

**Database internals or distributed systems - Yes.** The evidence is distributed fleet operations and event-sourced Go services. Do not claim database internals.

**Performance tuning - Yes, with scope.** The evidence is Linux kernel parameter management, storage pressure analysis through PSI and disk metrics, and PostgreSQL service operations. The free text states plainly that there is no production ClickHouse internals or profiler work.

**AI consent - Yes.** This is the required consent field. Change it to No only if you object to AI-assisted evaluation and accept that the form may block submission.

**Cover letter - intentionally blank.** The field is optional and this packet contains a tailored CV, not a cover letter.

## Submission sequence

1. Open the application URL above.
2. Upload `submissions/clickhouse-cloud-infra/lebenslauf.pdf` to **Resume**.
3. Check Ashby's resume autofill against the name, email, location and phone.
4. Fill the remaining fields from the table and paste the field 12 answer.
5. Leave **Cover Letter** empty.
6. Review the three boolean answers, then submit.
7. After submission, set the application record to `stage=applied` with the submission date.
