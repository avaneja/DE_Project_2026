-- Create users table

CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    username VARCHAR(100),
    full_name VARCHAR(150),
    email VARCHAR(255),
    bio TEXT,
    account_type VARCHAR(50),
    is_private BOOLEAN,
    is_verified BOOLEAN,
    followers_count INTEGER,
    following_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
);

-- Create posts table

CREATE TABLE posts (
    post_id INTEGER PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    post_type VARCHAR(50),
    caption TEXT,
    location_name VARCHAR(255),
    like_count INTEGER,
    comment_count INTEGER,
    is_archived BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
);

-- Create comments table

CREATE TABLE comments (
    comment_id INTEGER PRIMARY KEY,
    post_id INTEGER REFERENCES posts(post_id),
    user_id INTEGER REFERENCES users(user_id),
    parent_comment_id INTEGER REFERENCES comments(comment_id),
    body TEXT,
    is_hidden BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
);

-- Create follows table

CREATE TABLE follows (
    follower_id INTEGER REFERENCES users(user_id),
    followee_id INTEGER REFERENCES users(user_id),
    status VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (follower_id, followee_id)
);

-- Create hashtags table

CREATE TABLE hashtags (
    hashtag_id INTEGER PRIMARY KEY,
    tag VARCHAR(100)
);

-- Create likes table

CREATE TABLE likes (
    user_id INTEGER REFERENCES users(user_id),
    post_id INTEGER REFERENCES posts(post_id),
    created_at TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (user_id, post_id)
);

-- Create post_hashtags table

CREATE TABLE post_hashtags (
    post_id INTEGER REFERENCES posts(post_id),
    hashtag_id INTEGER REFERENCES hashtags(hashtag_id),
    PRIMARY KEY (post_id, hashtag_id)
);

-- Create post_media table

CREATE TABLE post_media (
    post_id INTEGER REFERENCES posts(post_id),
    position INTEGER,
    media_type VARCHAR(50),
    media_url TEXT,
    width INTEGER,
    height INTEGER,
    duration_sec NUMERIC,
    PRIMARY KEY (post_id, position)
);

-- Create stories table

CREATE TABLE stories (
    story_id INTEGER PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    media_type VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    view_count INTEGER
);