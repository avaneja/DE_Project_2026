# Phase 4 (CP3): Optimization Report

## 1. Setup and method

| Item | Value |
|---|---|
| Database | `instagram_db`, schema `instagram`, seed data (419,954 likes) |
| PostgreSQL | 18.6 (Homebrew), default server settings (no `work_mem` / `enable_*` changes) |
| Machine | Apple M4, 16 GB RAM |
| Method | `./benchmarks/run_benchmark.sh instagram_db <phase> 3 <workload>`: `EXPLAIN (ANALYZE, BUFFERS)`, 3 runs, average; writes inside `BEGIN … ROLLBACK` |
| Indexes | `sql/05_indexes.sql` (14 indexes, each commented with the queries it serves) |
| Rewrites | `sql/06_optimized_queries.sql` (R10, R13, R17, R18, W04 rewritten; all other queries identical to `queries/workload_30.sql`) |

**Which baseline is used.** The CP2 baseline in `benchmarks/results/baseline/` was recorded on a different
laptop. The brief requires the same machine for before and after, so the baseline was **re-run unchanged on
this laptop** (same schema, same data, no extra indexes) into `benchmarks/results/baseline_rerun/`. All "Before"
numbers below come from that folder, and all "After" numbers from `benchmarks/results/optimized/`. The
original CP2 numbers are left untouched.

Steps to reproduce:
```bash
psql -d instagram_db -c "CREATE SCHEMA instagram;"
PGOPTIONS='-c search_path=instagram' psql -d instagram_db -f sql/01_schema.sql
PGOPTIONS='-c search_path=instagram' psql -d instagram_db -f sql/02_load_data.sql
psql -d instagram_db -c "VACUUM ANALYZE;"
./benchmarks/run_benchmark.sh instagram_db baseline_rerun 3
PGOPTIONS='-c search_path=instagram' psql -d instagram_db -f sql/05_indexes.sql
./benchmarks/run_benchmark.sh instagram_db optimized 3 sql/06_optimized_queries.sql
```

## 2. Optimization table

Improvement % = (before − after) / before × 100.

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---:|:---:|
| R01 | 12.719 | Seq Scan on 60k posts, then sort of all followees' posts | `posts_user_created_idx (user_id, created_at DESC)`: per-followee index probe | 0.428 | 96.6% (29.7×) | ✅ |
| R02 | 6.293 | Seq Scan on posts + sort for one user | `posts_user_created_idx`: direct lookup of user 217's posts | 0.068 | 98.9% (92.5×) | ✅ |
| R03 | 2.998 | Seq Scan on 30k users (no index on username) | `users_username_uq` UNIQUE B-tree | 0.078 | 97.4% (38.4×) | ✅ |
| R04 | 17.034 | Seq Scan on 150k comments twice (post filter + reply join) | `comments_post_created_idx` + `comments_parent_idx` | 0.415 | 97.6% (41.0×) | ✅ |
| R05 | 14.436 | Seq Scan on 150k post_hashtags | `post_hashtags_hashtag_post_idx (hashtag_id, post_id)` (Index Only) + `posts_created_idx` | 2.498 | 82.7% (5.8×) | ✅ |
| R06 | 12.707 | Seq Scan + sort of 30k users | `users_rank_idx` in ORDER BY order: stops after 20 matches | 1.185 | 90.7% (10.7×) | ✅ |
| R07 | 7.227 | Seq Scan on 420k likes for one post | `likes_post_created_idx (post_id, created_at DESC)` | 0.628 | 91.3% (11.5×) | ✅ (3 rows tied on sort key may swap) |
| R08 | 0.135 | Already index-only via `follows_pkey` | None needed (sub-ms; difference is timer noise) | 0.422 | -212.6% (0.3×) | ✅ |
| R09 | 4.371 | follows_pkey scan, filter on followee in memory | `follows_followee_status_created_idx` gives rows already ordered | 0.779 | 82.2% (5.6×) | ✅ |
| R10 | 6.057 | Seq Scan on stories; `DATE()` not sargable | Rewrite to half-open range + `stories_user_created_idx` | 0.290 | 95.2% (20.9×) | ✅ |
| R11 | 10.673 | Seq Scan on users + posts | `users_creator_idx` (partial, Index Only) + `posts_created_idx`; still aggregates ~20k 2026 posts | 7.792 | 27.0% (1.4×) | ✅ |
| R12 | 6.880 | Seq Scan on posts | `posts_created_idx` range scan | 2.717 | 60.5% (2.5×) | ✅ |
| R13 | 30.353 | Seq Scan on 150k comments per NOT IN; **wrong result (0 rows)** | Rewrite to `NOT EXISTS` + `comments_parent_idx` | 0.255 | 99.2% (119.0×) | ❌ intentionally: bug fixed (0 → 12 rows) |
| R14 | 3.065 | follows_pkey full probe | `follows_followee_status_created_idx` | 0.723 | 76.4% (4.2×) | ✅ |
| R15 | 30.977 | Seq Scan on all 250k follows (must count every follower) | Partial user indexes; follows must still be read in full | 40.381 | -30.4% (0.8×) | ✅ |
| R16 | 4.776 | Seq Scan on posts | `posts_created_idx` (June range is most selective) | 0.398 | 91.7% (12.0×) | ✅ |
| R17 | 10.016 | Seq Scan on posts; `EXTRACT(YEAR)` not sargable | Rewrite to range + `posts_created_idx` + `users_creator_idx` | 3.310 | 67.0% (3.0×) | ✅ |
| R18 | 4.925 | Seq Scan; `::date` cast not sargable | Rewrite to range + `posts_created_idx` | 1.212 | 75.4% (4.1×) | ✅ |
| R19 | 5938.586 | Correlated subqueries: Seq Scan on 420k likes **per verified user** (294×) | `users_verified_idx` + `posts_user_created_idx` + `likes_post_created_idx` (Index Only) | 11.006 | 99.8% (539.6×) | ✅ |
| R20 | 14.101 | Seq Scan on comments + hash join | `posts_created_idx`; comments still scanned (see below) | 13.388 | 5.1% (1.1×) | ✅ |
| R21 | 5.944 | follows_pkey probe | `follows_followee_status_created_idx` | 1.840 | 69.0% (3.2×) | ✅ |
| R22 | 6.158 | Seq Scan + sort of 150k comments | Partial `comments_hidden_created_idx` (3,046 rows) | 3.018 | 51.0% (2.0×) | ✅ |
| R23 | 0.036 | Already Index Only on `likes_pkey` | None needed (sub-ms; timer noise) | 0.107 | -197.2% (0.3×) | ✅ |
| R24 | 2.812 | Seq Scan on stories | `stories_created_idx INCLUDE (user_id, view_count)`: Index Only | 2.308 | 17.9% (1.2×) | ✅ |
| W01 | 1.030 | Plain INSERT | None (now also maintains 2 new posts indexes) | 2.099 | -103.8% (0.5×) | ✅ |
| W02 | 1.337 | INSERT ON CONFLICT on PK | None (now maintains `likes_post_created_idx`) | 1.968 | -47.2% (0.7×) | ✅ |
| W03 | 0.209 | PK lookup | None | 0.271 | -29.7% (0.8×) | ✅ |
| W04 | 88.000 | Hash join 30k users × 250k follows, then group | Rewrite: aggregate follows first, then join | 60.279 | 31.5% (1.5×) | ✅ (same 1,200 rows updated, same md5) |
| W05 | 7.527 | Deletes 94% of stories: Seq Scan is correct | None (intentionally no index on expires_at) | 6.847 | 9.0% (1.1×) | ✅ |
| W06 | 3.842 | follows_pkey scan | `follows_followee_status_created_idx` | 0.597 | 84.5% (6.4×) | ✅ |
| **Total** | **6255.224** | | | **167.307** | **97.3% (37.4×)** | |


**Headline:** the whole workload went from **6255.2 ms to 167.3 ms**. R19, the
deliberately slow query, went from 5939 ms to 11.0 ms.

Notes on the rows with a negative improvement:
- **R08, R23**: the plan is identical before and after (`follows_pkey` / `likes_pkey`). Both run in a fraction
  of a millisecond, where a single cold run dominates the average. This is timer noise, not a regression.
- **R15**: the plan still has to read all 250,729 accepted follows (see §6). Runs 2 and 3 (35.6 and 29.7 ms)
  equal the baseline (≈30 ms). The average is pulled up by a cold first run (55.9 ms).
- **W01, W02, W03**: real write overhead from the new indexes (see §5).

## 3. The wrong-result query: R13

**Original:**
```sql
AND c.comment_id NOT IN (SELECT r.parent_comment_id FROM comments r);
```
The subquery returns all 150,000 `parent_comment_id` values, and **125,840 of them are NULL** (every top-level
comment has no parent). SQL uses three-valued logic: `x NOT IN (a, b, NULL)` means
`x <> a AND x <> b AND x <> NULL`, and `x <> NULL` is `UNKNOWN`. So the whole predicate is never `TRUE`, and
the query **always returns 0 rows**. That is exactly problem P6 ("comments without replies always shows
nothing").

**Fix** (`sql/06_optimized_queries.sql`, R13):
```sql
AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.parent_comment_id = c.comment_id);
```
`NOT EXISTS` only asks whether a matching reply row exists. A NULL `parent_comment_id` never equals anything,
so it simply doesn't match. The fixed query returns **12 rows** for post 59689 (original: 0). It is also
119× faster, because each probe is an index-only lookup on `comments_parent_idx` instead of hashing the
full 150k-row subquery. An alternative fix would be `… NOT IN (SELECT parent_comment_id FROM comments WHERE parent_comment_id IS NOT NULL)`, but
`NOT EXISTS` is preferred because it is NULL-safe by construction.

## 4. Proof that results are unchanged

For every read query, two checksums were computed:
1. **Without any of our indexes**, running the original `queries/workload_30.sql`
2. **With all indexes**, running `sql/06_optimized_queries.sql`

For each query: `count(*)`, an order-independent checksum
`md5(string_agg(row::text, '|' ORDER BY row::text))` (same set of rows), and an ordered checksum (same order).

| Query | Rows before | Rows after | Same rows (md5) | Same order |
|---|---:|---:|:---:|:---:|
| R01 | 30 | 30 | ✅ `3894be23` | ✅ |
| R02 | 11 | 11 | ✅ `eb248b6c` | ✅ |
| R03 | 1 | 1 | ✅ `22fdc4aa` | ✅ |
| R04 | 12 | 12 | ✅ `4b6fc019` | ✅ |
| R05 | 30 | 30 | ✅ `877869a2` | ✅ |
| R06 | 20 | 20 | ✅ `66ce55bf` | ✅ |
| R07 | 9 | 9 | ✅ `cecf7718` | ties only (see below) |
| R08 | 20 | 20 | ✅ `d448b8d6` | ✅ |
| R09 | 15 | 15 | ✅ `74648140` | ✅ |
| R10 | 6 | 6 | ✅ `71258eb1` | ✅ |
| R11 | 20 | 20 | ✅ `679a9874` | ✅ |
| R12 | 10 | 10 | ✅ `c5f474ce` | ✅ |
| R13 | 0 | 12 | ❌ (intended fix) `54fa096f` | n/a |
| R14 | 81 | 81 | ✅ `590352a0` | ✅ |
| R15 | 136 | 136 | ✅ `7a98feae` | ✅ |
| R16 | 81 | 81 | ✅ `9f098e85` | ✅ |
| R17 | 50 | 50 | ✅ `f6831e1a` | ✅ |
| R18 | 120 | 120 | ✅ `65d6ae8d` | ✅ |
| R19 | 294 | 294 | ✅ `ae2a5042` | ✅ |
| R20 | 10 | 10 | ✅ `6f960323` | ✅ |
| R21 | 81 | 81 | ✅ `590352a0` | ✅ |
| R22 | 25 | 25 | ✅ `70d4ab51` | ✅ |
| R23 | 1 | 1 | ✅ `dcd750ca` | ✅ |
| R24 | 20 | 20 | ✅ `a71726c7` | ✅ |

- **R07**: same 9 rows. The only order difference is among three likes with the identical sort key
  (`you_follow = false`, `created_at = 2026-06-30 23:59:00+05:30`: users 17054, 28148, 3020). The query's
  `ORDER BY` does not decide between them, so any order is correct.
- **R20**: kept as the original SQL on purpose. Several June posts tie at 10 comments around rank 10, so the
  top 10 is not deterministic. A faster `LATERAL` rewrite (13.4 → 4.5 ms in testing) was rejected because its
  "same result" could not be guaranteed.
- **W04** (write rewrite): both versions were run in a transaction, followed by
  `SELECT count(*), md5(string_agg(user_id||':'||followers_count, ',' ORDER BY user_id)) FROM users`, then rolled back.
  Both report `UPDATE 1200` and the identical checksum `d5d00588c94e23e1fcfe1d12d2dee414`.
- **W01–W03, W05, W06**: SQL unchanged, so indexes cannot change their effect.
- Date rewrites (R10, R17, R18): `DATE(ts)`, `ts::date` and the literal `'2026-06-01'` are all evaluated in
  the session time zone (`Asia/Kolkata`), so `DATE(ts) BETWEEN '2026-06-01' AND '2026-06-30'` ≡
  `ts >= '2026-06-01' AND ts < '2026-07-01'` exactly. The checksums confirm it.

## 5. Before/after plans for the 5 biggest improvements

### R19: 5938.586 ms → 11.006 ms

Correlated subqueries: for each of the 294 verified users, Postgres scanned all 419,954 likes. Fixed by indexes alone: `likes_post_created_idx` turns each probe into an index-only lookup of that user's posts' likes.

**Before** (`benchmarks/results/baseline_rerun/R19.txt`, run 3):
```
Sort  (cost=3120465.75..3120466.49 rows=294 width=36) (actual time=5957.732..5957.740 rows=294.00 loops=1)
  Sort Key: ((SubPlan 2)) DESC
  Sort Method: quicksort  Memory: 40kB
  ->  Seq Scan on users u  (cost=0.00..3120453.70 rows=294 width=36) (actual time=28.468..5957.445 rows=294.00 loops=1)
        Filter: is_verified
        Rows Removed by Filter: 29706
        SubPlan 1
          ->  Aggregate  (cost=1519.01..1519.02 rows=1 width=8) (actual time=1.677..1.678 rows=1.00 loops=294)
                ->  Seq Scan on posts p  (cost=0.00..1519.00 rows=3 width=8) (actual time=0.640..1.670 rows=10.63 loops=294)
                      Filter: (user_id = u.user_id)
                      Rows Removed by Filter: 59989
        SubPlan 2
          ->  Aggregate  (cost=9092.09..9092.10 rows=1 width=8) (actual time=18.575..18.575 rows=1.00 loops=294)
                ->  Hash Join  (cost=1519.04..9092.03 rows=21 width=0) (actual time=2.712..18.563 rows=74.26 loops=294)
                      Hash Cond: (l.post_id = p_1.post_id)
                      ->  Seq Scan on likes l  (cost=0.00..6470.54 rows=419954 width=4) (actual time=0.001..9.154 rows=419954.00 loops=247)
                      ->  Hash  (cost=1519.00..1519.00 rows=3 width=4) (actual time=1.575..1.575 rows=10.63 loops=294)
                            Buckets: 1024  Batches: 1  Memory Usage: 21kB
                            ->  Seq Scan on posts p_1  (cost=0.00..1519.00 rows=3 width=4) (actual time=0.588..1.571 rows=10.63 loops=294)
                                  Filter: (user_id = u.user_id)
                                  Rows Removed by Filter: 59989
Execution Time: 5957.790 ms
```
**After** (`benchmarks/results/optimized/R19.txt`, run 3):
```
Sort  (cost=10915.23..10915.96 rows=294 width=36) (actual time=8.685..8.691 rows=294.00 loops=1)
  Sort Key: ((SubPlan 3)) DESC
  Sort Method: quicksort  Memory: 40kB
  ->  Index Only Scan using users_verified_idx on users u  (cost=0.27..10903.18 rows=294 width=36) (actual time=1.046..8.637 rows=294.00 loops=1)
        Heap Fetches: 0
        SubPlan 2
          ->  Result  (cost=3.10..3.11 rows=1 width=8) (actual time=0.002..0.002 rows=1.00 loops=294)
                InitPlan 1
                  ->  Limit  (cost=0.41..3.10 rows=1 width=8) (actual time=0.002..0.002 rows=0.84 loops=294)
                        ->  Index Only Scan using posts_user_created_idx on posts p  (cost=0.41..8.47 rows=3 width=8) (actual time=0.002..0.002 rows=0.84 loops=294)
                              Index Cond: ((user_id = u.user_id) AND (created_at IS NOT NULL))
                              Heap Fetches: 1
        SubPlan 3
          ->  Aggregate  (cost=33.89..33.90 rows=1 width=8) (actual time=0.027..0.027 rows=1.00 loops=294)
                ->  Nested Loop  (cost=4.86..33.84 rows=21 width=0) (actual time=0.004..0.025 rows=74.26 loops=294)
                      ->  Bitmap Heap Scan on posts p_1  (cost=4.44..15.91 rows=3 width=4) (actual time=0.002..0.005 rows=10.63 loops=294)
                            Recheck Cond: (user_id = u.user_id)
                            Heap Blocks: exact=2975
                            ->  Bitmap Index Scan on posts_user_created_idx  (cost=0.00..4.44 rows=3 width=0) (actual time=0.001..0.001 rows=10.63 loops=294)
                                  Index Cond: (user_id = u.user_id)
                      ->  Index Only Scan using likes_post_created_idx on likes l  (cost=0.42..5.90 rows=8 width=4) (actual time=0.001..0.001 rows=6.99 loops=3125)
                            Index Cond: (post_id = p_1.post_id)
                            Heap Fetches: 0
Execution Time: 8.729 ms
```

### R13: 30.353 ms → 0.255 ms

`NOT IN` against a subquery with 125,840 NULLs: Seq Scan of the whole table and a wrong answer. `NOT EXISTS` + `comments_parent_idx` gives a correct answer via index-only probes.

**Before** (`benchmarks/results/baseline_rerun/R13.txt`, run 3):
```
Seq Scan on comments c  (cost=3134.00..6643.00 rows=2 width=24) (actual time=25.342..25.343 rows=0.00 loops=1)
  Filter: ((NOT (ANY (comment_id = (hashed SubPlan 1).col1))) AND (post_id = 59689))
  Rows Removed by Filter: 150000
  SubPlan 1
    ->  Seq Scan on comments r  (cost=0.00..2759.00 rows=150000 width=4) (actual time=0.005..6.317 rows=150000.00 loops=1)
Execution Time: 25.375 ms
```
**After** (`benchmarks/results/optimized/R13.txt`, run 3):
```
Nested Loop Anti Join  (cost=4.74..33.00 rows=3 width=24) (actual time=0.045..0.148 rows=12.00 loops=1)
  ->  Bitmap Heap Scan on comments c  (cost=4.44..16.04 rows=3 width=24) (actual time=0.033..0.075 rows=13.00 loops=1)
        Recheck Cond: (post_id = 59689)
        Heap Blocks: exact=13
        ->  Bitmap Index Scan on comments_post_created_idx  (cost=0.00..4.44 rows=3 width=0) (actual time=0.015..0.015 rows=13.00 loops=1)
              Index Cond: (post_id = 59689)
  ->  Index Only Scan using comments_parent_idx on comments r  (cost=0.29..4.31 rows=1 width=4) (actual time=0.005..0.005 rows=0.08 loops=13)
        Index Cond: (parent_comment_id = c.comment_id)
        Heap Fetches: 0
Execution Time: 0.205 ms
```

### R02: 6.293 ms → 0.068 ms

Seq Scan of 60k posts + sort, replaced by a direct range in `posts_user_created_idx`.

**Before** (`benchmarks/results/baseline_rerun/R02.txt`, run 3):
```
Limit  (cost=1519.02..1519.03 rows=3 width=26) (actual time=6.202..6.204 rows=11.00 loops=1)
  ->  Sort  (cost=1519.02..1519.03 rows=3 width=26) (actual time=6.202..6.203 rows=11.00 loops=1)
        Sort Key: created_at DESC
        Sort Method: quicksort  Memory: 25kB
        ->  Seq Scan on posts  (cost=0.00..1519.00 rows=3 width=26) (actual time=1.951..6.183 rows=11.00 loops=1)
              Filter: ((NOT is_archived) AND (user_id = 217))
              Rows Removed by Filter: 59989
Execution Time: 6.226 ms
```
**After** (`benchmarks/results/optimized/R02.txt`, run 3):
```
Limit  (cost=15.94..15.94 rows=3 width=26) (actual time=0.039..0.040 rows=11.00 loops=1)
  ->  Sort  (cost=15.94..15.94 rows=3 width=26) (actual time=0.039..0.039 rows=11.00 loops=1)
        Sort Key: created_at DESC
        Sort Method: quicksort  Memory: 25kB
        ->  Bitmap Heap Scan on posts  (cost=4.44..15.91 rows=3 width=26) (actual time=0.012..0.030 rows=11.00 loops=1)
              Recheck Cond: (user_id = 217)
              Filter: (NOT is_archived)
              Heap Blocks: exact=11
              ->  Bitmap Index Scan on posts_user_created_idx  (cost=0.00..4.44 rows=3 width=0) (actual time=0.006..0.006 rows=11.00 loops=1)
                    Index Cond: (user_id = 217)
Execution Time: 0.053 ms
```

### R04: 17.034 ms → 0.415 ms

Two Seq Scans of 150k comments (post filter + reply join), replaced by two index lookups.

**Before** (`benchmarks/results/baseline_rerun/R04.txt`, run 3):
```
Sort  (cost=5735.34..5735.34 rows=3 width=40) (actual time=11.010..11.815 rows=12.00 loops=1)
  Sort Key: c.created_at
  Sort Method: quicksort  Memory: 25kB
  ->  GroupAggregate  (cost=5735.26..5735.31 rows=3 width=40) (actual time=10.995..11.804 rows=12.00 loops=1)
        Group Key: c.comment_id
        ->  Sort  (cost=5735.26..5735.27 rows=3 width=36) (actual time=10.988..11.793 rows=12.00 loops=1)
              Sort Key: c.comment_id
              Sort Method: quicksort  Memory: 25kB
              ->  Gather  (cost=3361.97..5735.24 rows=3 width=36) (actual time=10.934..11.778 rows=12.00 loops=1)
                    Workers Planned: 1
                    Workers Launched: 1
                    ->  Parallel Hash Right Join  (cost=2361.97..4734.94 rows=2 width=36) (actual time=8.814..9.654 rows=6.00 loops=2)
                          Hash Cond: (r.parent_comment_id = c.comment_id)
                          ->  Parallel Seq Scan on comments r  (cost=0.00..2141.35 rows=88235 width=8) (actual time=0.004..2.697 rows=75000.00 loops=2)
                          ->  Parallel Hash  (cost=2361.94..2361.94 rows=2 width=32) (actual time=3.973..3.973 rows=6.00 loops=2)
                                Buckets: 1024  Batches: 1  Memory Usage: 72kB
                                ->  Parallel Seq Scan on comments c  (cost=0.00..2361.94 rows=2 width=32) (actual time=0.510..3.951 rows=6.00 loops=2)
                                      Filter: ((parent_comment_id IS NULL) AND (NOT is_hidden) AND (post_id = 59689))
                                      Rows Removed by Filter: 74994
Execution Time: 11.849 ms
```
**After** (`benchmarks/results/optimized/R04.txt`, run 3):
```
Sort  (cost=41.11..41.12 rows=3 width=40) (actual time=0.234..0.236 rows=12.00 loops=1)
  Sort Key: c.created_at
  Sort Method: quicksort  Memory: 25kB
  ->  GroupAggregate  (cost=41.03..41.09 rows=3 width=40) (actual time=0.196..0.210 rows=12.00 loops=1)
        Group Key: c.comment_id
        ->  Sort  (cost=41.03..41.04 rows=3 width=36) (actual time=0.189..0.191 rows=12.00 loops=1)
              Sort Key: c.comment_id
              Sort Method: quicksort  Memory: 25kB
              ->  Nested Loop Left Join  (cost=4.74..41.01 rows=3 width=36) (actual time=0.040..0.169 rows=12.00 loops=1)
                    ->  Bitmap Heap Scan on comments c  (cost=4.44..16.04 rows=3 width=32) (actual time=0.032..0.096 rows=12.00 loops=1)
                          Recheck Cond: (post_id = 59689)
                          Filter: ((parent_comment_id IS NULL) AND (NOT is_hidden))
                          Rows Removed by Filter: 1
                          Heap Blocks: exact=13
                          ->  Bitmap Index Scan on comments_post_created_idx  (cost=0.00..4.44 rows=3 width=0) (actual time=0.014..0.015 rows=13.00 loops=1)
                                Index Cond: (post_id = 59689)
                    ->  Index Scan using comments_parent_idx on comments r  (cost=0.29..8.31 rows=1 width=8) (actual time=0.005..0.005 rows=0.08 loops=12)
                          Index Cond: (parent_comment_id = c.comment_id)
Execution Time: 0.313 ms
```

### R03: 2.998 ms → 0.078 ms

Seq Scan of 30k users, replaced by a unique B-tree lookup.

**Before** (`benchmarks/results/baseline_rerun/R03.txt`, run 3):
```
Seq Scan on users  (cost=0.00..861.00 rows=1 width=43) (actual time=0.028..2.968 rows=1.00 loops=1)
  Filter: ((username)::text = 'karan_singh217'::text)
  Rows Removed by Filter: 29999
Execution Time: 2.991 ms
```
**After** (`benchmarks/results/optimized/R03.txt`, run 3):
```
Index Scan using users_username_uq on users  (cost=0.29..8.30 rows=1 width=43) (actual time=0.040..0.041 rows=1.00 loops=1)
  Index Cond: ((username)::text = 'karan_singh217'::text)
Execution Time: 0.082 ms
```

## 6. Write overhead

| Query | Before (ms) | After (ms) | Change (ms) |
|---|---:|---:|---:|
| W01 | 1.030 | 2.099 | +1.069 |
| W02 | 1.337 | 1.968 | +0.631 |
| W03 | 0.209 | 0.271 | +0.062 |
| W04 | 88.000 | 60.279 | -27.721 |
| W05 | 7.527 | 6.847 | -0.680 |
| W06 | 3.842 | 0.597 | -3.245 |

- **W01 (new post)** got slower by about 1 ms. Each insert now also maintains `posts_user_created_idx` and
  `posts_created_idx`. **Acceptable**: 2.1 ms is still well under the 5 ms real-time target, and those two
  indexes make the feed, profile and every analytics query 3–90× faster. Posts are read far more often than
  they are written.
- **W02 (like)** got slower by about 0.6 ms (maintaining `likes_post_created_idx`, 12 MB). **Acceptable**:
  this index is what makes R07 and R19 fast, and a like is still about 2 ms.
- **W03** changed by +0.06 ms. That's noise: `like_count` is not in any index, so the update is HOT-eligible.
- **W04** got **faster** (31%) because of the rewrite. **W06** got **faster** (6×) because
  `follows_followee_status_created_idx` finds the pending rows directly. The gain in finding the rows is
  larger than the cost of updating `status` (an indexed column) in the new index.
- **W05** is unchanged. We deliberately added **no** index on `stories.expires_at`: the delete removes 37,729
  of 40,000 rows (94%), so a Seq Scan is optimal and an index would only add work per deleted row.

## 7. Index storage

| Index | Table | Index size | Table size | Index / table |
|---|---|---:|---:|---:|
| `comments_hidden_created_idx` | comments | 88 kB | 10072 kB | 1% |
| `comments_parent_idx` | comments | 1392 kB | 10072 kB | 14% |
| `comments_post_created_idx` | comments | 4632 kB | 10072 kB | 46% |
| `follows_followee_status_created_idx` | follows | 10 MB | 15 MB | 68% |
| `likes_post_created_idx` | likes | 12 MB | 18 MB | 70% |
| `post_hashtags_hashtag_post_idx` | post_hashtags | 3312 kB | 5312 kB | 62% |
| `posts_created_idx` | posts | 1328 kB | 6152 kB | 22% |
| `posts_user_created_idx` | posts | 2400 kB | 6152 kB | 39% |
| `stories_created_idx` | stories | 1248 kB | 2672 kB | 47% |
| `stories_user_created_idx` | stories | 1248 kB | 2672 kB | 47% |
| `users_creator_idx` | users | 168 kB | 4360 kB | 4% |
| `users_rank_idx` | users | 2144 kB | 4360 kB | 49% |
| `users_username_uq` | users | 1120 kB | 4360 kB | 26% |
| `users_verified_idx` | users | 40 kB | 4360 kB | 1% |

The total size of the new indexes is **41.2 MB** on top of the existing primary keys. The largest are
`likes_post_created_idx` (12 MB) and `follows_followee_status_created_idx` (10 MB). They are large because
they index the two biggest tables in full, but they serve 7 queries between them. Partial indexes keep the
selective ones tiny: `comments_hidden_created_idx` is 88 kB (2% of comments) and `users_verified_idx` is 40 kB.

**Indexes tried and removed:** `pg_trgm` GIN indexes on `users.username`, `users.full_name` and
`posts.location_name` (for the `ILIKE` searches R06 and R16). After `VACUUM ANALYZE` the planner did not use them on this data, for two reasons:
- R06 matches about 1,200 users (4%), so the planner rated a Seq Scan cheaper (18 ms measured).
- R16 is already selective through its June date range.

They were dropped to avoid write and storage overhead, and R06 is served by `users_rank_idx` instead (12.7 → 1.2 ms).

## 8. Queries we could not speed up (and why)

| Query | Why it stays at this speed |
|---|---|
| **R15** (wrong follower counts) | It must compare **every** creator/verified user (3,271) with the count of **all** their accepted followers, which means reading all 250,729 accepted follows rows. We tried a per-user `LATERAL` count via the index (index-only): 53 ms, slower than one sequential pass (30 ms). A hash aggregate over one Seq Scan is the cheapest plan. For 20× data, the fix is a summary table or a trigger-maintained counter (Phase 5). |
| **W04** (nightly recount) | Same reason: it recomputes the count for all 30,000 users, so it reads the whole `follows` table. The rewrite only removes the wasted join before grouping (88 → 60 ms). |
| **R20** (most-commented June posts) | It counts comments per June post. We kept the original SQL because of ties at rank 10 (see §4). Its hash join still reads all comments, but it stays at about 13 ms (target for reports: 5,000 ms). |
| **R11** (creator engagement) | It has to aggregate every 2026 post by a creator (~20k posts read via `posts_created_idx`, 2,259 joined). It is now an index-only scan on `users_creator_idx` but remains about 8 ms: the work is proportional to a fixed share of the table. |
| **R24, R12, R05** | Reports that aggregate a date window (all June stories, last-week posts, June #travel posts). They now read only that window by index, but they still have to read every row in the window. |
| **R08, R23, W03** | Already optimal (PK index-only/index scans) in the baseline. No change was possible or needed. |
| **W05** | Deletes 94% of the table. A Seq Scan is the correct plan. |

## 9. Notes for Phase 5 (large data)

- **R22** still uses `OFFSET 1500`, served by the 88 kB partial index (reads 1,525 index entries). To keep page
  cost constant at 20× (≈60k hidden comments), use keyset pagination with `(created_at, comment_id)` from the
  last row of the previous page:
  `WHERE is_hidden AND (created_at, comment_id) < (:last_created_at, :last_comment_id) ORDER BY created_at DESC, comment_id DESC LIMIT 25`.
- **R15/W04** will grow linearly with `follows` (~5.2M rows). They are candidates for a summary table if they miss
  the 5 s / 3 s targets.
