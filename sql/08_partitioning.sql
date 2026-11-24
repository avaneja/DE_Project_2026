-- =====================================================================
-- Phase 5: partitioning the likes table (8,399,946 rows on the large data)
-- Run on the large database AFTER 01_schema.sql, the load and 05_indexes.sql:
--   psql -d instagram_large -f sql/08_partitioning.sql
-- It builds the partitioned copies in a separate schema (instagram_part) so the
-- benchmarked instagram schema is not changed. See docs/05_scalability_report.md §5.
--
-- PRIMARY-KEY RULE FOR PARTITIONED TABLES
--   A PRIMARY KEY / UNIQUE constraint on a partitioned table must contain every
--   partition-key column (each partition only enforces uniqueness locally).
--   * HASH (post_id):        PK (user_id, post_id) contains post_id   -> allowed, rule kept.
--   * RANGE (created_at):    PK (user_id, post_id) does NOT contain created_at -> rejected;
--                            it would have to become (user_id, post_id, created_at), which
--                            lets the same user like the same post twice (in two months).
-- =====================================================================

DROP SCHEMA IF EXISTS instagram_part CASCADE;
CREATE SCHEMA instagram_part;
SET search_path TO instagram_part, instagram;

-- ---------------------------------------------------------------------
-- 1. Chosen design: HASH partitioning by post_id, 16 partitions
--    Why post_id: the hot reads are per post (R07 "liked by", R19/R21 likes of
--    an author's posts, R23/W02 like button = user_id + post_id). All of them have
--    post_id = constant, so they prune to 1 of 16 partitions, and the one-like-per-
--    user-per-post rule stays a real PRIMARY KEY.
-- ---------------------------------------------------------------------
CREATE TABLE likes (
    user_id    INTEGER NOT NULL REFERENCES instagram.users(user_id),
    post_id    INTEGER NOT NULL REFERENCES instagram.posts(post_id),
    created_at TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (user_id, post_id)
) PARTITION BY HASH (post_id);

DO $$
BEGIN
  FOR i IN 0..15 LOOP
    EXECUTE format('CREATE TABLE likes_p%s PARTITION OF likes
                    FOR VALUES WITH (MODULUS 16, REMAINDER %s)', lpad(i::text, 2, '0'), i);
  END LOOP;
END $$;

-- Same secondary index as 05_indexes.sql; created on the parent, cascades to every partition.
CREATE INDEX likes_post_created_idx ON likes (post_id, created_at DESC);

INSERT INTO likes SELECT user_id, post_id, created_at FROM instagram.likes;

-- ---------------------------------------------------------------------
-- 2. Alternative for archiving: RANGE by created_at, one partition per quarter.
--    Shown to demonstrate time pruning and cheap archiving (DETACH / DROP an old
--    quarter instead of a huge DELETE). Note: no PRIMARY KEY (user_id, post_id)
--    is possible here (see rule above), so uniqueness would have to be enforced
--    elsewhere - this is why it is NOT our main design.
-- ---------------------------------------------------------------------
CREATE TABLE likes_by_time (
    user_id    INTEGER NOT NULL,
    post_id    INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (user_id, post_id, created_at)      -- must include created_at
) PARTITION BY RANGE (created_at);

CREATE TABLE likes_2025q1 PARTITION OF likes_by_time FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');
CREATE TABLE likes_2025q2 PARTITION OF likes_by_time FOR VALUES FROM ('2025-04-01') TO ('2025-07-01');
CREATE TABLE likes_2025q3 PARTITION OF likes_by_time FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE likes_2025q4 PARTITION OF likes_by_time FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE likes_2026q1 PARTITION OF likes_by_time FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE likes_2026q2 PARTITION OF likes_by_time FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE likes_2026q3 PARTITION OF likes_by_time FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE likes_by_time_default PARTITION OF likes_by_time DEFAULT;
CREATE INDEX likes_by_time_post_idx ON likes_by_time (post_id, created_at DESC);

INSERT INTO likes_by_time SELECT user_id, post_id, created_at FROM instagram.likes;

ANALYZE likes;
ANALYZE likes_by_time;

-- ---------------------------------------------------------------------
-- 3. Partition pruning checks (output recorded in docs/05_scalability_report.md)
-- ---------------------------------------------------------------------
-- R07 on the HASH table: only one partition (likes_pXX) appears in the plan.
EXPLAIN (ANALYZE, BUFFERS)
SELECT l.user_id, u.username, (f.follower_id IS NOT NULL) AS you_follow, l.created_at
FROM likes l
JOIN instagram.users u ON u.user_id = l.user_id
LEFT JOIN instagram.follows f ON f.follower_id = 1042 AND f.followee_id = l.user_id AND f.status = 'ACCEPTED'
WHERE l.post_id = 59689
ORDER BY you_follow DESC, l.created_at DESC;

-- R23 on the HASH table: one partition, Index Only Scan on its PK.
EXPLAIN (ANALYZE, BUFFERS)
SELECT EXISTS (SELECT 1 FROM likes WHERE user_id = 1042 AND post_id = 59689) AS liked;

-- Time window on the RANGE table: only the 2026q2 partition is scanned.
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM likes_by_time
WHERE created_at >= '2026-06-01' AND created_at < '2026-07-01';

-- Archiving on the RANGE table (metadata-only, instead of DELETE of ~1.4M rows):
--   ALTER TABLE likes_by_time DETACH PARTITION likes_2025q1 CONCURRENTLY;
--   -- dump / move likes_2025q1 to cold storage, then DROP TABLE likes_2025q1;

-- Partition sizes
SELECT inhrelid::regclass AS partition,
       pg_size_pretty(pg_total_relation_size(inhrelid)) AS total_size
FROM pg_inherits
WHERE inhparent IN ('instagram_part.likes'::regclass, 'instagram_part.likes_by_time'::regclass)
ORDER BY 1;
