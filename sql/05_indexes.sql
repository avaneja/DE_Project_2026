-- =====================================================================
-- Phase 4: indexes for the 30-query workload
-- Run after 01_schema.sql + 02_load_data.sql:
--   psql -d instagram_db -f sql/05_indexes.sql
--
-- Already present before this file (created automatically by PK constraints):
--   users_pkey(user_id), posts_pkey(post_id), comments_pkey(comment_id),
--   follows_pkey(follower_id, followee_id), hashtags_pkey(hashtag_id),
--   likes_pkey(user_id, post_id), post_hashtags_pkey(post_id, hashtag_id),
--   post_media_pkey(post_id, position), stories_pkey(story_id)
-- Those already serve: R08/R10/R01 (follows by follower_id), R23/W02 (likes by
-- user_id+post_id), R17 (post_media by post_id, position=1), W03 (posts by post_id).
-- Rule used for composite B-trees: equality columns first, then the range/sort column.
-- =====================================================================
SET search_path TO instagram;

-- ---------------------------------------------------------------------
-- USERS
-- ---------------------------------------------------------------------

-- R03 (open a profile by username): equality lookup on username.
-- UNIQUE because usernames are handles (verified: 0 duplicates in seed data),
-- so it also enforces a business rule the original schema was missing.
CREATE UNIQUE INDEX IF NOT EXISTS users_username_uq
    ON users (username);

-- R06 (search bar): the two ILIKE conditions match ~1,200 users (4%), too many
-- for a trigram GIN bitmap to beat a seq scan (we tested pg_trgm GIN on username
-- and full_name: the planner still chose Seq Scan, 18 ms). Instead this index is in
-- exactly the ORDER BY order (is_verified DESC, followers_count DESC): the planner
-- walks it from the top and stops after the first 20 matches (~500 entries read)
-- instead of filtering + sorting all 30k users. username/full_name are INCLUDEd
-- because the ILIKE filter needs them for every entry it walks past.
CREATE INDEX IF NOT EXISTS users_rank_idx
    ON users (is_verified DESC, followers_count DESC) INCLUDE (username, full_name);

-- R11, R17 (creator reports), R15 (creators OR verified): only 3,271 of 30,000
-- users are CREATOR. Partial index on just those rows, INCLUDE the columns the
-- reports read, so R11 is an Index Only Scan instead of a 30k-row Seq Scan.
CREATE INDEX IF NOT EXISTS users_creator_idx
    ON users (user_id) INCLUDE (username, followers_count)
    WHERE account_type = 'CREATOR';

-- R19 (verified-account report), R15 (verified OR creator -> BitmapOr with the
-- index above): only 294 users are verified, so this partial index is tiny.
CREATE INDEX IF NOT EXISTS users_verified_idx
    ON users (user_id) INCLUDE (username, followers_count)
    WHERE is_verified;

-- ---------------------------------------------------------------------
-- POSTS
-- ---------------------------------------------------------------------

-- R01 (home feed), R02 (profile grid), R19 (last post per verified user),
-- R21/R19 (posts of one author): equality on user_id, then created_at DESC so
-- "latest N posts of a user" is read straight from the index in order with no sort.
-- INCLUDE(is_archived) lets the NOT is_archived filter be checked without a heap visit.
CREATE INDEX IF NOT EXISTS posts_user_created_idx
    ON posts (user_id, created_at DESC) INCLUDE (is_archived);

-- R05, R12, R16, R18, R20, R11, R17 (date-window analytics): every one of them
-- filters posts by a created_at range (June 2026, last 7 days, 2026). B-tree
-- on the timestamp turns the full scan into a range scan.
CREATE INDEX IF NOT EXISTS posts_created_idx
    ON posts (created_at);

-- R16 (places): no trigram index. The June-2026 date range (3,296 posts) is far
-- more selective than '%goa%', so posts_created_idx already makes R16 < 1 ms;
-- a GIN trigram index on location_name was tested and not chosen by the planner.

-- ---------------------------------------------------------------------
-- FOLLOWS
-- ---------------------------------------------------------------------

-- The PK (follower_id, followee_id) only helps "who does X follow".
-- R09 (pending requests of 338, newest first), R14 & R21 (followers of 217),
-- R15 & W04 (count ACCEPTED followers per followee), W06 (accept pending of 338):
-- all look up by followee_id + status. created_at DESC last gives R09 its
-- ORDER BY for free, and the three columns make R15/W04 index-only scans.
CREATE INDEX IF NOT EXISTS follows_followee_status_created_idx
    ON follows (followee_id, status, created_at DESC);

-- ---------------------------------------------------------------------
-- COMMENTS
-- ---------------------------------------------------------------------

-- R04 (comments of a post in time order), R13 (comments of a post),
-- R20 (comments per June post): equality on post_id, then created_at for R04's ORDER BY.
CREATE INDEX IF NOT EXISTS comments_post_created_idx
    ON comments (post_id, created_at);

-- R04 (reply count per comment) and the fixed R13 (NOT EXISTS a reply):
-- find replies by parent_comment_id. Without it every probe scans 150k comments.
CREATE INDEX IF NOT EXISTS comments_parent_idx
    ON comments (parent_comment_id);

-- R22 (moderation console): only 3,046 of 150,000 comments are hidden.
-- Partial index on just those rows, ordered created_at DESC, so OFFSET 1500
-- LIMIT 25 walks ~1,525 small index entries instead of sorting 150k rows.
CREATE INDEX IF NOT EXISTS comments_hidden_created_idx
    ON comments (created_at DESC)
    WHERE is_hidden;

-- ---------------------------------------------------------------------
-- LIKES
-- ---------------------------------------------------------------------

-- R07 ("liked by" a post, newest first) and R19 (likes received per post):
-- the PK starts with user_id, so "all likes of post X" was a 420k-row seq scan.
-- post_id first (equality), then created_at DESC for R07's secondary sort.
CREATE INDEX IF NOT EXISTS likes_post_created_idx
    ON likes (post_id, created_at DESC);

-- ---------------------------------------------------------------------
-- POST_HASHTAGS
-- ---------------------------------------------------------------------

-- R05 (posts tagged #travel): the PK is (post_id, hashtag_id) and cannot be used
-- for "all posts with hashtag X". Reverse order composite = index-only lookup.
CREATE INDEX IF NOT EXISTS post_hashtags_hashtag_post_idx
    ON post_hashtags (hashtag_id, post_id);

-- ---------------------------------------------------------------------
-- STORIES
-- ---------------------------------------------------------------------

-- R10 (June stories of followed accounts): after looking up the ~followees in
-- follows_pkey, fetch each followee's stories in the date range.
-- Equality user_id first, then the created_at range.
CREATE INDEX IF NOT EXISTS stories_user_created_idx
    ON stories (user_id, created_at DESC);

-- R24 (story views in the last 30 days): range on created_at; INCLUDE the two
-- columns the query aggregates so it is an index-only scan.
CREATE INDEX IF NOT EXISTS stories_created_idx
    ON stories (created_at) INCLUDE (user_id, view_count);

-- NOTE: no index for W05 (delete stories with expires_at < 2026-06-01).
-- It deletes 37,729 of 40,000 rows (94%), so a sequential scan is the right
-- plan and an extra index would only add delete cost.

-- Fresh statistics + visibility map (needed for index-only scans).
VACUUM ANALYZE;
