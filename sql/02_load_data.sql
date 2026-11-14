-- Load users data
\copy users FROM 'seed_data/users.csv' WITH (FORMAT CSV, HEADER TRUE);

-- Load hashtags data
\copy hashtags FROM 'seed_data/hashtags.csv' WITH (FORMAT CSV, HEADER TRUE);

-- Load posts data
\copy posts FROM 'seed_data/posts.csv' WITH (FORMAT CSV, HEADER TRUE);

-- Load follows data
\copy follows FROM 'seed_data/follows.csv' WITH (FORMAT CSV, HEADER TRUE);

-- Load stories data
\copy stories FROM 'seed_data/stories.csv' WITH (FORMAT CSV, HEADER TRUE);

-- Load post_media data
\copy post_media FROM 'seed_data/post_media.csv' WITH (FORMAT CSV, HEADER TRUE);

-- Load likes data
\copy likes FROM 'seed_data/likes.csv' WITH (FORMAT CSV, HEADER TRUE);

-- Load comments data
\copy comments FROM 'seed_data/comments.csv' WITH (FORMAT CSV, HEADER TRUE);

-- Load post_hashtags data
\copy post_hashtags FROM 'seed_data/post_hashtags.csv' WITH (FORMAT CSV, HEADER TRUE);
