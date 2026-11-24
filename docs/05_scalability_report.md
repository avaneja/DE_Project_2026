# Phase 5 (CP4): Scalability Report — Large Dataset

## 1. Setup and method

| Item | Value |
|---|---|
| Database | `instagram_large`, schema `instagram` (new database, same laptop as Phase 4) |
| PostgreSQL | 18.6 (Homebrew), default settings (`shared_buffers` 128 MB, `work_mem` 4 MB) |
| Machine | Apple M4, 16 GB RAM (same as Phase 3/4) |
| Data | `large_data/`: 600,000 users · 1,200,000 posts · 8,399,946 likes · 3,000,000 comments · 5,195,968 follows · 800,000 stories · 1,800,749 post_media · 3,000,000 post_hashtags · 50 hashtags |
| Load time | 2 min 27 s for all 9 `\copy` commands; `05_indexes.sql` + `VACUUM ANALYZE` 26 s |
| Workload | `sql/06_optimized_queries.sql` only (the original 30 were **not** run on the large data) |
| Method | `run_benchmark.sh`: `EXPLAIN (ANALYZE, BUFFERS)`, 3 runs, average; writes inside `BEGIN … ROLLBACK` |

Steps to reproduce:
```bash
createdb instagram_large
psql -d instagram_large -c "CREATE SCHEMA instagram;"
PGOPTIONS='-c search_path=instagram' psql -d instagram_large -f sql/01_schema.sql
# 02_load_data.sql with the folder name changed from seed_data/ to large_data/
sed 's#seed_data/#large_data/#' sql/02_load_data.sql > /tmp/load_large.sql
PGOPTIONS='-c search_path=instagram' psql -d instagram_large -f /tmp/load_large.sql
PGOPTIONS='-c search_path=instagram' psql -d instagram_large -f sql/05_indexes.sql   # ends with VACUUM ANALYZE
./benchmarks/run_benchmark.sh instagram_large large 3 sql/06_optimized_queries.sql
psql -d instagram_large -f sql/08_partitioning.sql                                   # partitioning demo
```

Result folders:

| Folder | What it is |
|---|---|
| `benchmarks/results/large_first_run/` | First run on the large data, Phase 4 queries unchanged, cache cold after loading. **R01 missed its target here.** |
| `benchmarks/results/large/` | Final run: R01 rewritten (§3), one un-recorded warm-up pass first so every query is measured with a warm cache, the same way the seed numbers were measured. |
| `benchmarks/results/partitioning/` | Output of `sql/08_partitioning.sql` (pruning plans, partition sizes). |

## 2. Results table

"Seed" = Phase 4 optimized results (`benchmarks/results/optimized/summary.csv`). "Large (first)" = `large_first_run`, "Large (final)" = `large`. Growth = Large (final) ÷ Seed.

| Query | Optimized on seed (ms) | Large, first run (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Target | Meets target? | If not, what you changed |
|---|---:|---:|---:|---:|---:|:---:|---|
| R01 | 0.428 | 7.811 | 0.336 | 0.8× | < 5 | ✅ | **Missed in first run (7.8 ms).** Rewritten with `LATERAL … LIMIT 30` per followee (§3.1) |
| R02 | 0.068 | 0.110 | 0.088 | 1.3× | < 5 | ✅ | — |
| R03 | 0.078 | 0.357 | 0.102 | 1.3× | < 5 | ✅ | — |
| R04 | 0.415 | 0.295 | 0.165 | 0.4× | < 5 | ✅ | — |
| R05 | 2.498 | 28.451 | 24.783 | 9.9× | < 250 | ✅ | — |
| R06 | 1.185 | 1.111 | 1.032 | 0.9× | < 250 | ✅ | — |
| R07 | 0.628 | 0.472 | 0.091 | 0.1× | < 5 | ✅ | — |
| R08 | 0.422 | 1.009 | 0.279 | 0.7× | < 250 | ✅ | — |
| R09 | 0.779 | 4.893 | 1.013 | 1.3× | < 5 | ✅ | First run was cold cache (run 1 ≈ 13 ms, run 3 = 0.7 ms); no change needed (§3.2) |
| R10 | 0.290 | 0.407 | 0.470 | 1.6× | < 250 | ✅ | — |
| R11 | 7.792 | 49.273 | 52.574 | 6.7× | < 5,000 | ✅ | — |
| R12 | 2.717 | 59.658 | 57.729 | 21.2× | < 5,000 | ✅ | — |
| R13 | 0.255 | 0.033 | 0.036 | 0.1× | < 250 | ✅ | — |
| R14 | 0.723 | 2.202 | 1.036 | 1.4× | < 250 | ✅ | — |
| R15 | 40.381 | 259.546 | 235.180 | 5.8× | < 5,000 | ✅ | — |
| R16 | 0.398 | 7.715 | 7.823 | 19.7× | < 250 | ✅ | — |
| R17 | 3.310 | 26.502 | 30.656 | 9.3× | < 5,000 | ✅ | — |
| R18 | 1.212 | 16.833 | 17.055 | 14.1× | < 5,000 | ✅ | — |
| R19 | 11.006 | 175.700 | 176.525 | 16.0× | < 5,000 | ✅ | — |
| R20 | 13.388 | 110.447 | 103.575 | 7.7× | < 5,000 | ✅ | — |
| R21 | 1.840 | 2.694 | 1.948 | 1.1× | < 250 | ✅ | — |
| R22 | 3.018 | 2.455 | 2.489 | 0.8× | < 250 | ✅ | OFFSET kept (§3.4) |
| R23 | 0.107 | 0.117 | 0.041 | 0.4× | < 5 | ✅ | — |
| R24 | 2.308 | 15.157 | 14.404 | 6.2× | < 5,000 | ✅ | — |
| W01 | 2.099 | 1.044 | 0.968 | 0.5× | < 5 | ✅ | — |
| W02 | 1.968 | 2.084 | 1.863 | 0.9× | < 5 | ✅ | — |
| W03 | 0.271 | 0.989 | 0.721 | 2.7× | < 5 | ✅ | — |
| W04 | 60.279 | 2,027.457 | 2,046.441 | 33.9× | < 3,000 | ✅ | Meets target; hash spills to disk at scale, `work_mem` fix measured (§3.3) |
| W05 | 6.847 | 679.722 | 684.873 | 100.0× | < 3,000 | ✅ | Meets target; archiving via partitions recommended (§5.4) |
| W06 | 0.597 | 5.087 | 2.153 | 3.6× | < 5 | ✅ | First run was cold cache (5.09 ms); warm 2.15 ms (§3.2) |

**All 30 queries meet their targets on the large dataset.** Every query returns the same result as in Phase 4 (R01's rewrite was checked with `EXCEPT` on both datasets: 0 differing rows).

Note on R01 on seed: the new LATERAL version takes 0.85–0.92 ms on the seed data (warm), a little slower than the 0.428 ms join version, because on the seed each followee has only ~17 posts so the plain join was already cheap. The table keeps the Phase 4 number in the seed column; the rewrite is worth it because it no longer grows with posts per author.

## 3. What broke at scale and how it was fixed

### 3.1 R01 home feed — the only real scale problem

**Why it broke.** The data grew 20× in posts but users only 20× too, so each account has about the same number of *followees* (8 for user 1042) but far more *posts per author* (~250 on large vs ~17 on seed). The Phase 4 plan fetches **every** post of every followee, then top-N sorts them to keep 30. Its cost is proportional to posts per author, which only becomes visible at scale.

Before (Phase 4 query, large data, `large_first_run/R01.txt`, run 3):
```
Limit (actual time=4.874..4.880 rows=30)
  ->  Sort  Sort Key: p.created_at DESC  Sort Method: top-N heapsort
        ->  Nested Loop (actual rows=1990)                    <- 1,990 posts read to keep 30
              ->  Index Scan using follows_pkey on follows f (rows=8)
              ->  Bitmap Heap Scan on posts p (rows=248.75 loops=8)
                    Heap Blocks: exact=1948   Buffers: shared hit=1981
                    ->  Bitmap Index Scan on posts_user_created_idx
Execution Time: 4.920 ms      (3-run average 7.811 ms -> target < 5 ms missed)
```

**Fix (query rewrite, no new index).** Take only the newest 30 posts *of each followee* from `posts_user_created_idx`, which is already ordered `(user_id, created_at DESC)`, then the newest 30 of those. The global top 30 must be inside the union of the per-followee top 30s, so the result is identical.
```sql
SELECT p.post_id, p.user_id, p.post_type, p.caption, p.like_count, p.created_at
FROM follows f
CROSS JOIN LATERAL (
    SELECT post_id, user_id, post_type, caption, like_count, created_at
    FROM posts
    WHERE user_id = f.followee_id AND NOT is_archived
    ORDER BY created_at DESC
    LIMIT 30) p
WHERE f.follower_id = 1042 AND f.status = 'ACCEPTED'
ORDER BY p.created_at DESC
LIMIT 30;
```
After (`large/R01.txt`):
```
Limit (actual time=1.052..1.057 rows=30)
  ->  Sort  top-N heapsort
        ->  Nested Loop
              ->  Index Scan using follows_pkey on follows f (rows=8)
              ->  Limit (rows=12.38 loops=8)
                    ->  Index Scan using posts_user_created_idx on posts (rows=12.38 loops=8)   <- ~100 rows instead of 1,990
Execution Time: 0.3–1.1 ms    (3-run average 0.336 ms)
```
The cost is now bounded by `followees × 30` index entries, no matter how many posts each author has.

### 3.2 R09 and W06 — cold cache, not a plan problem

In `large_first_run`, R09 (4.89 ms) and W06 (5.09 ms) were at or over the 5 ms line. The plans show the right index (`follows_followee_status_created_idx`, 67 rows) and **run 3 was 0.715 ms (R09) and 0.639 ms (W06)**. The high average came from run 1, which read the index pages from disk right after a 2.7 GB load. Once warm, the averages are 1.01 ms and 2.15 ms. No change was made. (In production these pages stay hot because the requests screen is used constantly.)

### 3.3 W04 nightly follower count — spills to disk

W04 grew 33.9×, more than the data. The plan (`large/W04.txt`) shows why: the `HashAggregate` over 5,008,203 accepted follows now produces **588,106 groups** (seed: ~29k), which does not fit in the default `work_mem` = 4 MB:
```
HashAggregate ... Batches: 21  Memory Usage: 8257kB  Disk Usage: 65296kB
Hash ... Batches: 8 (originally 2)
Buffers: ... temp read=21922 written=28018
Execution Time: 1642 ms (3-run avg 2,046 ms)
```
It still meets the 3,000 ms batch target. For the nightly job we measured `SET work_mem = '64MB'` (session only, not server-wide): no disk batches, **1,500 ms and 1,529 ms** (runs 2–3; run 1 3,094 ms was cold). Recommendation: run the nightly job with `SET LOCAL work_mem = '64MB'`. The long-term fix is to keep `followers_count` correct with the W06/follow write path (or a trigger) so the full recount is only a weekly safety check.

### 3.4 R22 moderation console — OFFSET kept

R22 still uses `OFFSET 1500 LIMIT 25` on the partial index `comments_hidden_created_idx`. It stayed flat (3.0 → 2.5 ms) because the index only holds hidden comments and the query walks just 1,525 entries for page 61, whatever the table size. We did not switch to keyset pagination, so no "last seen" value is needed for this report. If moderators had to page deep (page 2,000+), keyset would be the fix: the client sends the `(created_at, comment_id)` of the last row on the current page and the next page is `WHERE is_hidden AND (created_at, comment_id) < ($last_created_at, $last_id) ORDER BY created_at DESC, comment_id DESC LIMIT 25`.

## 4. Growth analysis

The data grew ~20× (likes 420k → 8.40M = 20.0×, posts 60k → 1.2M = 20×, follows 250k → 5.20M = 20.8×).

| Group | Queries | Why |
|---|---|---|
| **Stayed about the same (≤ 3×)** | R01 (after fix), R02, R03, R04, R06, R07, R08, R09, R10, R13, R14, R21, R22, R23, W01, W02, W03, W06 | Index lookups on a key (`username`, `post_id`, `user_id`, `followee_id`). A B-tree's depth grows with log n (one extra level at most for 20×), and the number of rows returned per key barely changed: R02 still reads 12 index entries and stops (LIMIT 12), post 59689 has 5 likes, account 338 has 67 pending requests. R06 stops after 20 matches in index order. R22 reads a fixed 1,525 entries. Some even got faster: the seed numbers include sub-ms timer noise and the specific post/user ids happen to have fewer rows on the large data. |
| **Grew less than 20× (5–16×)** | R05, R11, R15, R17, R19, R20, R24 | They read a fixed *share* of a table (a date window, all verified users, all accepted follows), so the work grows with the data. They grow **less** than 20× because at this size PostgreSQL starts **parallel workers** (Gather / Parallel Hash Join with 2 workers in R11, R15, R20) that it did not use on the small data, and fixed overhead (planning, hash setup) is a smaller part of the total. R19 grew 16× because verified users grew 294 → 4,879 (16.6×) and the work is one index probe set per verified user. |
| **Grew about 20×** | R12 (21.2×), R16 (19.7×), R18 (14.1×) | Range scans on `posts_created_idx` (last 7 days / June 2026) followed by a per-row filter or aggregate: 20× more posts in the window = 20× more index entries and heap rows. Linear, as expected, and far below target (R16 7.8 ms of 250; R12 58 ms of 5,000). |
| **Grew more than 20×** | W04 (33.9×), W05 (100×) | **W04**: the hash aggregate and hash join outgrew `work_mem` and spilled to temp files (§3.3). **W05**: deletes 754,579 rows (seed 37,729: 20×) but the time grew 100×. Each deleted row touches a heap buffer (761,057 buffer hits in the plan) and writes a tuple header; on the seed all of `stories` (2.7 MB heap) sits in CPU cache and shared buffers, on the large data the heap + indexes are 117 MB, close to `shared_buffers` (128 MB), so pages are dirtied and evicted. It still meets the 3,000 ms target (685 ms). The scalable fix is not deleting rows at all: partition stories by `expires_at`/`created_at` and drop old partitions (§5.4). |

## 5. Storage

Sizes of the `instagram` schema (`pg_table_size` / `pg_indexes_size`):

| Table | Seed table | Seed indexes | Large table | Large indexes | Growth (total) |
|---|---:|---:|---:|---:|---:|
| likes | 18 MB | 21 MB | 355 MB | 429 MB | 19.8× |
| follows | 15 MB | 16 MB | 298 MB | 313 MB | 19.7× |
| comments | 10 MB | 9.2 MB | 197 MB | 183 MB | 19.8× |
| post_media | 8.8 MB | 1.9 MB | 176 MB | 39 MB | 20.1× |
| post_hashtags | 5.2 MB | 6.5 MB | 104 MB | 129 MB | 19.9× |
| posts | 6.0 MB | 4.9 MB | 120 MB | 98 MB | 19.8× |
| users | 4.3 MB | 4.0 MB | 96 MB | 83 MB | 21.4× |
| stories | 2.6 MB | 3.3 MB | 52 MB | 65 MB | 19.7× |
| hashtags | 40 kB | 16 kB | 40 kB | 16 kB | 1× |
| **Total** | **70 MB** | **67 MB** | **1,399 MB** | **1,338 MB** | **20.0×** |

- Whole seed database: 145 MB. Whole large database: 4,526 MB, of which ~2.7 GB is the `instagram` schema and the rest is the partitioning demo schema `instagram_part` (two partitioned copies of `likes`, ~1.7 GB).
- **Indexes are 49% of the storage** (1,338 of 2,737 MB). On `likes`, `follows` and `post_hashtags` the indexes are larger than the table, because these are narrow tables (2–4 columns) and each has two composite indexes (PK + one reverse index).
- At 2.7 GB the working set is already **21× bigger than `shared_buffers` (128 MB)**. It still fits in the 16 GB of RAM (OS page cache), which is why warm runs are fast. At 100× (~270 GB) it would not.

## 6. Architecture for 100× (≈ 840M likes, 120M posts, 520M follows, 60M users)

Using our measured growth: storage grows ~1:1 with rows → **~270 GB** for the `instagram` schema at 100×, `likes` alone **~78 GB** (784 MB × 100). Query groups that grew ~20× here (R12, R16, R18, R19, R15, W04, W05) would grow another ~5× from today's numbers; index-lookup queries would stay at ~1 ms.

### 6.1 Partitioning (`sql/08_partitioning.sql`, output in `benchmarks/results/partitioning/`)

**Table: `likes`. Method: HASH on `post_id`, 16 partitions.**

Why:
- The hot reads on likes are per post: R07 (`post_id = 59689`), R19/R21 (likes of an author's posts, looked up by `post_id`), R23/W02 (`user_id + post_id`). All have an equality on `post_id`, so all prune to **one** partition.
- Hash spreads rows evenly: our 16 partitions are 52–53 MB each (≈ 525k rows). At 100× that is ~4.9 GB per partition, small enough for fast VACUUM and index builds (~2.7 GB per partition with 16; use 64 partitions at 100×).
- **Primary-key rule:** a PRIMARY KEY or UNIQUE constraint on a partitioned table must include all partition-key columns. `PRIMARY KEY (user_id, post_id)` contains `post_id`, so the one-like-per-user-per-post rule (which `W02 ON CONFLICT` depends on) is kept.

DDL (full script in `sql/08_partitioning.sql`):
```sql
CREATE TABLE likes (
    user_id    INTEGER NOT NULL REFERENCES instagram.users(user_id),
    post_id    INTEGER NOT NULL REFERENCES instagram.posts(post_id),
    created_at TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (user_id, post_id)
) PARTITION BY HASH (post_id);
CREATE TABLE likes_p00 PARTITION OF likes FOR VALUES WITH (MODULUS 16, REMAINDER 0);
-- … likes_p01 … likes_p15
CREATE INDEX likes_post_created_idx ON likes (post_id, created_at DESC);
```

Partition pruning (8,399,946 rows copied in):
```
-- R07 "liked by" post 59689: only likes_p09 is scanned (15 of 16 partitions pruned)
->  Bitmap Heap Scan on likes_p09 l (actual rows=5)
      ->  Bitmap Index Scan on likes_p09_post_id_created_at_idx
Execution Time: 2.686 ms (cold)

-- R23 like-button state: one partition, index-only on its local PK
->  Index Only Scan using likes_p09_pkey on likes_p09 likes
      Index Cond: ((user_id = 1042) AND (post_id = 59689))   Heap Fetches: 0
Execution Time: 0.423 ms (cold)
```

**Alternative considered: RANGE on `created_at`** (`likes_by_time`, one partition per quarter, also in the script). It prunes time windows well (June 2026 count scans only `likes_2026q2`, 31.6 ms) and makes archiving a metadata operation (`DETACH PARTITION … CONCURRENTLY`, then `DROP`). But by the PK rule the key would have to become `(user_id, post_id, created_at)`, which **no longer prevents a double like** (same user, same post, different quarter), and W02's `ON CONFLICT (user_id, post_id)` would stop working. The quarters are also uneven (98 MB → 206 MB, as activity grows). So we choose HASH(post_id) for `likes`, and use RANGE partitioning for tables that are queried and expired by time and have no such uniqueness need: **`stories` by `created_at`** (W05 becomes `DROP PARTITION`, R10/R24 prune to the last month) and `comments`/`posts` archives by year if needed.

### 6.2 Sharding: by user (author), not by post

**Choice: shard by `user_id` of the owner** — a post, its media, hashtags, likes and comments live on the shard of the post's author; follows live on the shard of the follower (outgoing edges) with a copy of the reverse edge on the followee's shard.

Reasons from the workload:
- **Profile and owner queries become single-shard:** R02, R03, R09, R14, R21, R11/R19 per author, W04/W06 per account.
- **Post page R04, R07, R13, R23, W02, W03:** the post id → author is known from the post URL/feed item (we embed the shard id in the post id), so these go to one shard — the author's — which also holds all likes and comments of that post.
- Sharding by `post_id` would split one author's posts over all shards, so R02 (profile grid), R19 and R21 would become scatter-gather on every request; that is worse because the profile grid is one of the most frequent queries.

**Cross-shard queries and how to handle them:**
| Query | Why cross-shard | Handling |
|---|---|---|
| R01 home feed | Followees live on many shards | **Fan-out on write**: when an author posts (W01), push `(post_id, created_at)` into a per-follower feed table/cache on the follower's shard; R01 reads one shard. For celebrity authors (followers > ~100k) use fan-out on read: query their shard and merge (our LATERAL top-30-per-followee form is exactly this merge, and is bounded at 30 rows per followee). |
| R08 suggestions, R10 stories of followees | Friends-of-friends / followees on many shards | Precompute suggestions nightly; stories fan-out like the feed (they expire in 24 h, so a cache fits). |
| R05, R12, R16, R18, R20 explore/trending/analytics | Global time windows | Scatter-gather in parallel to all shards, then merge top-N (each shard returns its top 30/10), or serve from a summary table / analytics warehouse fed by CDC. |
| R15, R06 search | All users | R06 → a search index (Elasticsearch/OpenSearch); R15 → batch on each shard (it is a data-quality report). |
| R07 "you follow" flag | Liker's follow edge may be on another shard | The reverse-edge copy on the followee shard, or look up 1042's follow list once (8 rows) and pass it to the post shard. |

### 6.3 Read replicas and caching

| Send to | Queries | Reason |
|---|---|---|
| **Cache (Redis/CDN)** | R01 feed, R03 profile header, R02 grid, R12 trending, R05 explore, R16 places | Read very often, a few seconds of staleness is fine; trending/explore are the same for every user and change slowly (refresh every 1–5 min). |
| **Read replica** | R04, R06, R07, R08, R10, R11, R13, R14, R17, R18, R19, R20, R21, R22, R24, R15 | Reads where a lag of < 1 s is acceptable. All reports/analytics (R11, R15, R17–R20, R24 — our slowest reads, 15–235 ms) must go to a replica so they never compete with writes on the primary. |
| **Primary** | All writes W01–W06; R23 like-button state and R09 pending requests **right after the user acts** | R23 must reflect a like just made (read-your-own-write); R09 must not show a request that was just accepted by W06. These can go to a replica again once replication lag is known to be past the write. |

### 6.4 Maintenance

- **Autovacuum for `likes`** (8.4M rows → 840M): the default `autovacuum_vacuum_scale_factor = 0.2` would wait for 168M dead rows at 100×. Set per table (per partition):
  ```sql
  ALTER TABLE likes SET (autovacuum_vacuum_scale_factor = 0.01, autovacuum_vacuum_threshold = 10000,
                         autovacuum_analyze_scale_factor = 0.02, autovacuum_vacuum_insert_scale_factor = 0.05);
  ```
  likes is mostly insert-only, so the insert threshold matters: it keeps the visibility map current, which R19, R21 and R23 need for their **Index Only Scans** (`Heap Fetches: 0`). Partitioning helps here too: each partition is vacuumed separately (~525k rows each today).
  Also raise `autovacuum_max_workers` and `maintenance_work_mem` (e.g. 1 GB) so index vacuuming of the 429 MB → 43 GB likes indexes finishes in one pass.
- **`posts` and `users`** get frequent counter updates (W03 `like_count + 1`, W04 `followers_count`): set `fillfactor = 90` so updates stay HOT (same page, no index update), and the same aggressive autovacuum settings.
- **Archiving:** stories older than their expiry (W05 deletes 94% of the table) → RANGE partitions by `created_at`, `DROP` old partitions instead of `DELETE` (no dead tuples, no vacuum). Likes/comments older than ~2 years → move to a cold archive table or the warehouse.
- **Summary tables:** a materialized view for trending (R12) and per-author totals (likes received for R19, follower counts for R15/W04), refreshed with `REFRESH MATERIALIZED VIEW CONCURRENTLY` every few minutes (needs a unique index) or kept incrementally by the write path. This turns the "grows 20×" queries into constant-time lookups.
- **Bigger memory settings** on a real server: `shared_buffers` ≈ 25% of RAM, `effective_cache_size` ≈ 75%, and `work_mem` raised only for the nightly batch session (§3.3).

## 7. Conclusion

**Yes, the database is ready for next year's 20× volume.** On 8.4M likes / 1.2M posts / 5.2M follows all 30 optimized queries meet their targets on the same laptop: every real-time query is ≤ 2.2 ms (target 5), every interactive query ≤ 25 ms (target 250), every report ≤ 236 ms (target 5,000), and the batch jobs 685 ms and 2,046 ms (target 3,000). Only one query (R01) needed a change at scale, and the fix makes it independent of posts per author.

Remaining risks:
1. **W04 is the closest to its limit** (2,046 of 3,000 ms) and grows faster than the data because of disk spills. Run it with a larger session `work_mem` (measured 1.5 s) and move to incremental follower counts before the next growth step.
2. **Linear queries** (R12, R16, R18, R19, R15, W05) grew ~20× and will grow again at 100×; R15 and R19 would reach ~1–2 s. Summary tables / replicas are the plan for these.
3. **Memory:** the 2.7 GB working set already exceeds `shared_buffers` 21×; the cold-cache first run showed real-time queries reaching 5–8 ms. Production needs RAM ≥ the hot set and tuned `shared_buffers`.
4. **Hot keys:** celebrity accounts (≈ 59k followers for user 1 in the data) make fan-out on write expensive and concentrate likes in a few posts; the hybrid feed in §6.2 is needed.
5. **Single node:** at 100× (~270 GB, ~78 GB for likes) one server is no longer enough; partitioning (§6.1) is the first step and sharding by author (§6.2) the next.
