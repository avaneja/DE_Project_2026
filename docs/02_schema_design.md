# Instagram Social Media Database – Schema Design

## 1. Introduction

In this project, I have divided the Instagram database into nine different tables. Each table stores information about a particular part of the platform, such as users, posts, comments, likes and stories.

I created these tables using PostgreSQL and connected them using primary keys and foreign keys. This helps keep related information connected and makes it easier to retrieve data using SQL queries.

The following sections explain each table and its role in the database.

## 2. Tables Overview

The database contains nine tables. Each table is responsible for storing a different type of information.

| Table Name | Purpose |
|---|---|
| users | Stores user details such as username, email, bio and account type. |
| posts | Stores posts created by users, including captions, post type and timestamps. |
| comments | Stores comments made by users on posts, including replies to other comments. |
| follows | Stores follow relationships between users and their request status. |
| hashtags | Stores the available hashtag names. |
| likes | Stores which users have liked which posts. |
| post_hashtags | Connects posts with the hashtags used in them. |
| post_media | Stores media details related to posts, such as image or video information. |
| stories | Stores story details uploaded by users. |

I have kept the information in separate tables so that each type of data can be managed easily.

## 3. Primary Keys and Foreign Keys

### Primary Keys

A primary key is used to uniquely identify each record in a table. In this project, I have used the following primary keys:

| Table | Primary Key |
|---|---|
| users | user_id |
| posts | post_id |
| comments | comment_id |
| follows | follower_id, followee_id |
| hashtags | hashtag_id |
| likes | user_id, post_id |
| post_hashtags | post_id, hashtag_id |
| post_media | post_id, position |
| stories | story_id |

Some tables use a combination of two columns as their primary key. These are called composite primary keys.

### Foreign Keys

Foreign keys are used to connect related tables. They help maintain relationships between records.

The following foreign-key relationships are used in my database:

| Table | Foreign Key | References |
|---|---|---|
| posts | user_id | users(user_id) |
| comments | post_id | posts(post_id) |
| comments | user_id | users(user_id) |
| comments | parent_comment_id | comments(comment_id) |
| follows | follower_id | users(user_id) |
| follows | followee_id | users(user_id) |
| likes | user_id | users(user_id) |
| likes | post_id | posts(post_id) |
| post_hashtags | post_id | posts(post_id) |
| post_hashtags | hashtag_id | hashtags(hashtag_id) |
| stories | user_id | users(user_id) |
| post_media | post_id | posts(post_id) |

The comments table also has a relationship with itself because a comment can be a reply to another comment.

## 4. Relationships Between Tables

In this database, different tables are connected to each other through primary keys and foreign keys. These relationships help connect information stored in different tables.

The main relationships are:

1. **Users and Posts:** One user can create multiple posts. Each post belongs to a particular user.
2. **Users and Comments:** A user can write multiple comments, and each comment is associated with a user.
3. **Posts and Comments:** One post can have multiple comments.
4. **Users and Likes:** A user can like multiple posts. The likes table keeps track of these activities.
5. **Users and Follows:** Users can follow other users. The follows table stores both the follower and the followee.
6. **Posts and Hashtags:** A post can contain multiple hashtags, and the same hashtag can be used in multiple posts. The post_hashtags table connects them.
7. **Posts and Media:** A post can have multiple media items. The post_media table stores details about these items.
8. **Users and Stories:** A user can upload multiple stories.
9. **Comments and Replies:** A comment can have replies. The parent_comment_id column connects a reply to its parent comment.

These relationships help represent how users interact with posts and with each other on the platform.

## 5. Important Columns in Each Table

### 1. users
Stores information about registered users.

- `user_id`: Unique ID of each user.
- `username`: User's username.
- `full_name`: Full name of the user.
- `email`: User's email address.
- `bio`: Short description of the user.
- `account_type`: Type of account.
- `is_private`: Shows whether the account is private.
- `is_verified`: Shows whether the account is verified.
- `followers_count`: Number of followers.
- `following_count`: Number of users followed.
- `created_at`: Account creation date and time.

### 2. posts
Stores posts created by users.

- `post_id`: Unique ID of each post.
- `user_id`: ID of the user who created the post.
- `post_type`: Type of post.
- `caption`: Text written with the post.
- `location_name`: Location associated with the post.
- `like_count`: Number of likes.
- `comment_count`: Number of comments.
- `is_archived`: Shows whether the post is archived.
- `created_at`: Post creation date and time.

### 3. comments
Stores comments and replies on posts.

- `comment_id`: Unique ID of each comment.
- `post_id`: ID of the related post.
- `user_id`: ID of the user who wrote the comment.
- `parent_comment_id`: ID of the parent comment, if it is a reply.
- `body`: Comment text.
- `is_hidden`: Shows whether the comment is hidden.
- `created_at`: Comment creation date and time.

### 4. follows
Stores follow relationships between users.

- `follower_id`: ID of the user who sends the follow request.
- `followee_id`: ID of the user receiving the request.
- `status`: Current status of the follow relationship.
- `created_at`: Date and time of the follow request.

### 5. hashtags
Stores hashtags used on the platform.

- `hashtag_id`: Unique ID of each hashtag.
- `tag`: Hashtag name.

### 6. likes
Stores information about likes on posts.

- `user_id`: ID of the user who liked the post.
- `post_id`: ID of the liked post.
- `created_at`: Date and time when the post was liked.

### 7. post_hashtags
Connects posts with their hashtags.

- `post_id`: ID of the post.
- `hashtag_id`: ID of the hashtag.

### 8. post_media
Stores media information related to posts.

- `post_id`: ID of the related post.
- `position`: Position of the media item in the post.
- `media_type`: Type of media, such as image or video.
- `media_url`: Location or URL of the media.
- `width`: Media width.
- `height`: Media height.
- `duration_sec`: Media duration in seconds.

### 9. stories
Stores stories uploaded by users.

- `story_id`: Unique ID of each story.
- `user_id`: ID of the user who uploaded the story.
- `media_type`: Type of media in the story.
- `created_at`: Story creation date and time.
- `expires_at`: Time when the story expires.
- `view_count`: Number of views.

## 6. Loading Data into the Database

I received the project data in CSV format. These files contained information about users, posts, comments, likes, follows, hashtags, media and stories.

I used PostgreSQL's `\copy` command to load the CSV data into the tables I had created. Before importing the data, I made sure that the tables were ready and that the required relationships were in place.

After loading the data, I checked the number of records in each table to make sure the data had been imported properly.

The database now contains more than 1.1 million records across all nine tables.

## 7. Data Validation

After importing the CSV files into PostgreSQL, I performed validation checks to verify that the data was loaded correctly and that the relationships between tables were maintained.

The validation checks included:

1. Checking whether posts are connected to existing users.
2. Checking whether comments refer to valid posts and users.
3. Checking whether likes refer to valid users and posts.
4. Checking whether follow relationships refer to existing users.
5. Checking whether post hashtags are connected to valid posts and hashtags.
6. Checking whether post media records are connected to existing posts.
7. Checking whether stories belong to existing users.
8. Checking whether replies are connected to valid parent comments.

The foreign-key validation queries returned zero invalid references for these checks. This indicates that the checked relationships were maintained correctly after importing the data.

Additional data-quality checks, such as identifying duplicate values, negative numeric values, and differences between stored like/comment counts and actual records, can be performed for further validation.

## 8. Schema Design Summary

Through this project, I have created a database structure consisting of nine tables to manage different types of Instagram-related data.

Each table has its own purpose, and the relationships between them help connect information about users and their activities. I have used primary keys and foreign keys to organize these relationships.

Working on this schema has helped me understand how a social media platform can organize a large amount of related data. It has also given me practical experience in creating tables and working with PostgreSQL.

