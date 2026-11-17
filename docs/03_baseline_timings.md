
# DE Project — CP2 Baseline Timings

## Benchmark setup

- **Database:** `instagram_db`
- **Schema:** `instagram`
- **Workload:** `queries/workload_30.sql` (24 read queries R01–R24 and 6 write queries W01–W06)
- **Measurement:** `EXPLAIN (ANALYZE, BUFFERS)`; three runs per query; execution times are in milliseconds.
- **Write queries:** The benchmark helper wraps each write query in a transaction and rolls it back.
- **Evidence:** `benchmarks/results/baseline/summary.csv` and the 30 corresponding raw plan files.

## Validation of collected evidence

- The summary CSV contains 30 query rows, plus its header.
- All 30 raw plan files are present.
- Each raw plan file contains three recorded `Execution Time` measurements.
- The arithmetic mean of the three raw-plan measurements matches `avg_ms` in the CSV to three decimal places for all 30 queries.

## Results

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan nodes recorded by helper |
|---|---|---:|---:|---:|---:|---|
| **R01** — Home feed — latest posts from followed accounts | READ | 9.706 | 6.013 | 6.015 | 7.245 | Seq Scan on posts; Index Scan using follows_pkey on follows |
| **R02** — Profile grid — latest posts by one user | READ | 3.409 | 3.378 | 3.414 | 3.400 | Seq Scan on posts |
| **R03** — Profile lookup by username | READ | 1.893 | 1.367 | 1.354 | 1.538 | Seq Scan on users |
| **R04** — Top-level comments and reply counts for a post | READ | 10.147 | 8.222 | 7.946 | 8.772 | Seq Scan on comments |
| **R05** — Travel hashtag posts since June 2026 | READ | 12.492 | 9.166 | 9.230 | 10.296 | Seq Scan on post_hashtags; Seq Scan on hashtags; Index Scan using posts_pkey on posts |
| **R06** — Username/name search using ILIKE | READ | 16.901 | 16.479 | 16.947 | 16.776 | Seq Scan on users |
| **R07** — Users who liked a post and follow-state lookup | READ | 8.382 | 5.753 | 5.784 | 6.640 | Seq Scan on likes; Index Scan using users_pkey on users; Index Scan using follows_pkey on follows |
| **R08** — Friends-of-friends suggestions | READ | 3.665 | 0.128 | 0.171 | 1.321 | Index Scan using follows_pkey on follows; Index Only Scan using follows_pkey on follows |
| **R09** — Pending follow requests for an account | READ | 17.192 | 2.337 | 2.321 | 7.283 | Index Scan using follows_pkey on follows; Index Scan using users_pkey on users |
| **R10** — Stories from followed accounts in June 2026 | READ | 2.194 | 1.968 | 1.994 | 2.052 | Seq Scan on stories; Index Scan using follows_pkey on follows |
| **R11** — Creator engagement per follower | READ | 5.216 | 5.096 | 5.003 | 5.105 | Seq Scan on posts; Seq Scan on users |
| **R12** — Trending hashtags in the date range | READ | 3.794 | 3.079 | 3.210 | 3.361 | Seq Scan on posts; Index Only Scan using post_hashtags_pkey on post_hashtags; Index Scan using hashtags_pkey on hashtags |
| **R13** — Comments without replies on a post | READ | 23.387 | 22.785 | 26.029 | 24.067 | Seq Scan on comments |
| **R14** — Accounts following user 217 who user 217 does not follow | READ | 9.865 | 2.867 | 2.392 | 5.041 | Index Scan using follows_pkey on follows; Index Only Scan using follows_pkey on follows |
| **R15** — Stored vs actual follower-count comparison | READ | 30.881 | 28.425 | 29.593 | 29.633 | Seq Scan on follows; Seq Scan on users |
| **R16** — Posts at locations containing 'goa' in June 2026 | READ | 8.364 | 6.796 | 6.885 | 7.348 | Seq Scan on posts |
| **R17** — Creator reels longer than 60 seconds | READ | 14.030 | 8.832 | 8.784 | 10.549 | Seq Scan on posts; Index Scan using users_pkey on users; Index Scan using post_media_pkey on post_media |
| **R18** — Posts per day and type in June 2026 | READ | 5.532 | 4.823 | 4.815 | 5.057 | Seq Scan on posts |
| **R19** — Verified-account last-post time and likes received | READ | 5391.453 | 5403.641 | 5376.878 | 5390.657 | Seq Scan on users; Seq Scan on posts; Seq Scan on likes |
| **R20** — Most-commented posts since June 2026 | READ | 13.789 | 12.704 | 12.414 | 12.969 | Seq Scan on comments; Seq Scan on posts |
| **R21** — Ghost followers of user 217 | READ | 14.876 | 3.705 | 3.646 | 7.409 | Index Scan using follows_pkey on follows; Index Only Scan using likes_pkey on likes; Index Scan using posts_pkey on posts |
| **R22** — Hidden comments, newest first, page 61 | READ | 5.121 | 5.094 | 5.027 | 5.081 | Seq Scan on comments |
| **R23** — Whether user 1042 liked post 59689 | READ | 0.289 | 0.026 | 0.025 | 0.113 | Index Only Scan using likes_pkey on likes |
| **R24** — Story counts and views by account | READ | 1.465 | 1.455 | 1.510 | 1.477 | Seq Scan on stories |
| **W01** — Insert a new photo post | WRITE | 0.961 | 0.369 | 0.395 | 0.575 | (no scan) |
| **W02** — Insert a like if it does not already exist | WRITE | 0.545 | 0.449 | 0.423 | 0.472 | (no scan) |
| **W03** — Increment a post's like counter | WRITE | 0.263 | 0.108 | 0.097 | 0.156 | Index Scan using posts_pkey on posts |
| **W04** — Recompute follower counts for all users | WRITE | 67.988 | 58.331 | 60.596 | 62.305 | Seq Scan on users; Seq Scan on follows |
| **W05** — Delete stories expired before June 2026 | WRITE | 18.638 | 6.569 | 6.342 | 10.516 | Seq Scan on stories |
| **W06** — Accept pending follow requests for account 338 | WRITE | 2.810 | 2.615 | 2.496 | 2.640 | Index Scan using follows_pkey on follows |

## Scan-type observations and reasons

The scan nodes below are the nodes extracted by the benchmark helper from the third run's plan for each query. The explanations describe the access paths reported by those plans. A sequential scan is not automatically inefficient; whether an index would help depends on selectivity, table size, and the workload.

| Query | Observed scan node(s) | Explanation based on the query and recorded plan |
|---|---|---|
| **R01** | Seq Scan on posts; Index Scan using follows_pkey on follows | The plan uses a sequential scan of posts and the follows primary-key index. The posts-side user, archive, and ordering conditions are not supported by an index in this plan. |
| **R02** | Seq Scan on posts | The plan sequentially scans posts to apply the user and archive filters and ordering. |
| **R03** | Seq Scan on users | The username equality condition is evaluated with a sequential scan of users; no username index appears in the plan. |
| **R04** | Seq Scan on comments | The plan sequentially scans comments for the selected post and top-level comment/reply join. |
| **R05** | Seq Scan on post_hashtags; Seq Scan on hashtags; Index Scan using posts_pkey on posts | The plan sequentially scans hashtags and post_hashtags for the tag/join path, then uses the posts primary-key index for post lookup. |
| **R06** | Seq Scan on users | The OR condition with ILIKE predicates is evaluated by a sequential scan of users; no supporting text-search or pattern index appears in the plan. |
| **R07** | Seq Scan on likes; Index Scan using users_pkey on users; Index Scan using follows_pkey on follows | The plan sequentially scans likes for the selected post, while user and follow lookups use their primary-key indexes. |
| **R08** | Index Scan using follows_pkey on follows; Index Only Scan using follows_pkey on follows | The composite primary-key index on follows supports the relationship lookups; one lookup is reported as an index-only scan. |
| **R09** | Index Scan using follows_pkey on follows; Index Scan using users_pkey on users | The plan uses the follows composite primary-key index for the follow relationship and the users primary-key index for usernames. |
| **R10** | Seq Scan on stories; Index Scan using follows_pkey on follows | Stories are sequentially scanned for the date filter; follows is accessed using its primary-key index. |
| **R11** | Seq Scan on posts; Seq Scan on users | The plan sequentially scans posts and users while filtering creator accounts and aggregating engagement. |
| **R12** | Seq Scan on posts; Index Only Scan using post_hashtags_pkey on post_hashtags; Index Scan using hashtags_pkey on hashtags | Posts are sequentially scanned for the date condition; post_hashtags uses an index-only scan and hashtags uses its primary-key index. |
| **R13** | Seq Scan on comments | Comments are sequentially scanned for the selected post and the NOT IN reply test. |
| **R14** | Index Scan using follows_pkey on follows; Index Only Scan using follows_pkey on follows | The follows composite primary-key index supports the outer relationship lookup and the NOT EXISTS check; the latter is index-only. |
| **R15** | Seq Scan on follows; Seq Scan on users | Users and follows are sequentially scanned to calculate accepted follower counts and compare them with stored counts. |
| **R16** | Seq Scan on posts | Posts are sequentially scanned for the location ILIKE and date conditions. |
| **R17** | Seq Scan on posts; Index Scan using users_pkey on users; Index Scan using post_media_pkey on post_media | Posts are sequentially scanned for reel/year conditions; users and post_media are accessed through primary-key indexes. |
| **R18** | Seq Scan on posts | Posts are sequentially scanned for the date condition before grouping by day and type. |
| **R19** | Seq Scan on users; Seq Scan on posts; Seq Scan on likes | The correlated subqueries result in sequential scans of users, posts, and likes; this query has the highest measured baseline time. |
| **R20** | Seq Scan on comments; Seq Scan on posts | Comments and posts are sequentially scanned for the date filter and aggregation by post. |
| **R21** | Index Scan using follows_pkey on follows; Index Only Scan using likes_pkey on likes; Index Scan using posts_pkey on posts | The follows composite index and likes index-only scan support relationship/existence checks; posts is accessed through its primary-key index. |
| **R22** | Seq Scan on comments | Comments are sequentially scanned for hidden rows before sorting and pagination. |
| **R23** | Index Only Scan using likes_pkey on likes | The likes primary-key index supports the exact user/post existence check using an index-only scan. |
| **R24** | Seq Scan on stories | Stories are sequentially scanned for the date filter and grouped by user. |
| **W01** | (no scan) | No scan node is reported for this insert operation. |
| **W02** | (no scan) | No scan node is reported for this insert; the statement uses ON CONFLICT DO NOTHING. |
| **W03** | Index Scan using posts_pkey on posts | The posts primary-key index locates the row being updated. |
| **W04** | Seq Scan on users; Seq Scan on follows | Users and follows are sequentially scanned to aggregate accepted follower counts and update mismatched counters. |
| **W05** | Seq Scan on stories | Stories are sequentially scanned to find rows matching the expiry condition. |
| **W06** | Index Scan using follows_pkey on follows | The follows primary-key index is used to locate pending requests for the account. |

## Baseline observations

- **Slowest read query:** R19 at **5,390.657 ms** average. Its recorded plan includes sequential scans on users, posts, and likes while evaluating correlated subqueries.
- **Slowest write query:** W04 at **62.305 ms** average. Its recorded plan includes sequential scans on users and follows for follower-count recomputation.
- **Fastest read query:** R23 at **0.113 ms** average, using an index-only scan on likes.
- Several queries already use primary-key or composite-primary-key indexes. The later optimization phase should focus on measured bottlenecks and confirm any proposed changes with new execution plans.

## Reproducibility and evidence

- Keep the original `summary.csv` and all 30 raw `.txt` plan files under `benchmarks/results/baseline/`.
- Do not edit `queries/workload_30.sql`.
- This report summarizes the measured baseline; it does not modify or replace the raw benchmark evidence.
