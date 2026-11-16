# Instagram Social Media Database

## 1. Project Overview

Instagram is one of those apps that many of us use to share pictures, videos and stories. Apart from that, we can also like and comment on other users' posts, follow them and explore different topics using hashtags.

As part of this project, I am developing a database system that works in a way similar to Instagram. While working on it, I am dealing with different types of data, including users, posts, comments, likes, followers and stories.

I have always been curious about how all these things are connected and how a database system can manage such a large amount of data. Through this project, I am getting practical experience in creating tables, connecting them and working with actual data.

## 2. Project Objectives

The main objectives of this project are:

1. To create a PostgreSQL database for an Instagram-like social media platform.
2. To store information about users, posts, comments, likes, followers, hashtags and stories.
3. To create relationships between different tables using primary keys and foreign keys.
4. To import the provided CSV files into the database.
5. To write SQL queries to retrieve and analyze information from the database.
6. To check the data and make sure the relationships between tables are working correctly.

## 3. Project Scope

This project mainly focuses on managing the data of an Instagram-like social media platform using PostgreSQL.

The database covers different activities that happen on the platform, such as creating user accounts, sharing posts, liking and commenting on posts, following other users, using hashtags and uploading stories.

The project includes creating tables, defining relationships between them, importing the provided CSV data and writing SQL queries to retrieve useful information.

The main focus is on the database side of the platform rather than developing a complete Instagram application or user interface.


## 4. Dataset Overview

The project uses the CSV files provided with the assignment. These files contain sample data related to different activities on an Instagram-like platform.

There are 9 CSV files in total, covering users, posts, comments, follows, hashtags, likes, post media, post hashtags and stories.

I imported these files into their respective PostgreSQL tables. The database contains more than 1.14 million records across all 9 tables.

The data helps in understanding how different activities on the platform are connected and gives us a chance to work with a large dataset using SQL.

## 5. Tools and Technologies Used

During this project, I used the following tools and technologies:

1. **PostgreSQL:** Used to create the database, tables and relationships, and to store the project data.
2. **SQL:** Used to insert, retrieve and check data in different tables.
3. **Visual Studio Code:** Used to write and manage SQL files and project documentation.
4. **CSV Files:** Used as the source of data for all nine database tables.
5. **Git and GitHub:** Used to manage the project files and maintain the project repository.

These tools helped me work with the database, organize the project files and manage the provided dataset.

## 6. Database Requirements

The database should be able to store and manage information related to users and their activities on the platform.

The main requirements are:

1. Store user details such as username, email, account type and profile information.
2. Store posts, including captions, post types and creation dates.
3. Maintain information about likes and comments on posts.
4. Keep track of followers and follow requests between users.
5. Store hashtags and connect them with the posts where they are used.
6. Manage media files related to posts and stories.
7. Maintain relationships between tables so that related information can be retrieved easily.
8. Allow SQL queries to retrieve and analyze the stored data.

These requirements help define what information the database needs to store and how its tables should be connected.

## 7. Assumptions and Business Rules

The database design is based on the following assumptions and business rules:

1. **User Identification:** Each user is uniquely identified by a `user_id`. Usernames and email addresses are stored as part of the user's profile information.

2. **User Activity:** A user can create multiple posts, comments, and stories. Each post, comment, and story is associated with a specific user.

3. **Posts and Interactions:** Each post belongs to one user and can receive multiple likes and comments from different users.

4. **Following System:** A user can follow multiple users and can also have multiple followers. The `follows` table stores the follower, followee, and the status of their relationship. A user cannot have duplicate records for the same follower-followee pair.

5. **Hashtags:** A post can contain multiple hashtags, and the same hashtag can be used in multiple posts.

6. **Post Media:** A post can contain multiple media items. Each media item is associated with a post and has a position to maintain its order.

7. **Comments and Replies:** A comment belongs to a post and is created by a user. Comments can also have replies, which are connected to their parent comment using `parent_comment_id`.

8. **Stories:** Each story belongs to a user and contains an expiry time to represent when the story should no longer be active.

9. **Data Integrity:** Primary keys and foreign keys are used to maintain relationships between tables and prevent invalid references.

These assumptions define the expected relationships and rules used while designing the Instagram database schema.