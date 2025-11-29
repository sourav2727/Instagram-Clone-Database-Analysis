-- 1.Based on user engagement and activity levels, 
-- which users would you consider the most loyal or valuable? How would you reward or incentivize these users?
WITH TotalLikes AS (
    SELECT u.id, COUNT(distinct l.photo_id) AS total_likes
    FROM users u
    LEFT JOIN likes l ON u.id = l.user_id
    GROUP BY u.id),
TotalComments AS (
    SELECT u.id, COUNT(distinct c.photo_id) AS total_comments
    FROM users u
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY u.id),
PhotosPosted AS (
    SELECT user_id, COUNT(id) AS total_photos_posted
    FROM photos
    GROUP BY user_id),
Followers AS (
    SELECT followee_id AS user_id, COUNT(follower_id) AS total_followers
    FROM follows
    GROUP BY followee_id),
UniqueTags AS (
    SELECT p.user_id, COUNT(DISTINCT pt.tag_id) AS unique_tags_used
    FROM photos p
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    GROUP BY p.user_id)
SELECT u.id AS user_id, u.username,
    COALESCE(tl.total_likes, 0) AS total_likes,
    COALESCE(tc.total_comments, 0) AS total_comments,
    COALESCE(pp.total_photos_posted, 0) AS total_photos_posted,
    COALESCE(f.total_followers, 0) AS total_followers,
    COALESCE(ut.unique_tags_used, 0) AS unique_tags_used,
    (COALESCE(tl.total_likes, 0) + COALESCE(tc.total_comments, 0)) AS total_engagement
FROM users u
LEFT JOIN TotalLikes tl ON u.id = tl.id
LEFT JOIN TotalComments tc ON u.id = tc.id
LEFT JOIN PhotosPosted pp ON u.id = pp.user_id
LEFT JOIN Followers f ON u.id = f.user_id
LEFT JOIN UniqueTags ut ON u.id = ut.user_id
group by u.id 
having total_photos_posted >0
ORDER BY total_engagement DESC, total_followers DESC, total_photos_posted DESC
limit 10;
-- 2.For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?
WITH UserSegments AS (
    -- This CTE mirrors the segmentation logic from the previous query
    SELECT
        CASE
            WHEN COALESCE(p.total_posts, 0) > 0 AND p.last_post_date < DATE_SUB(CURDATE(), INTERVAL 90 DAY)
                THEN 'Inactive Creator'
            WHEN COALESCE(p.total_posts, 0) = 0
                THEN 'Never Posted'
            ELSE 'Active User'
        END AS user_segment
    FROM
        users u
    LEFT JOIN (
        SELECT
            user_id,
            COUNT(id) AS total_posts,
            MAX(created_dat) AS last_post_date
        FROM
            photos
        GROUP BY
            user_id
    ) p ON u.id = p.user_id
)
SELECT
user_segment AS User_Category,
COUNT(user_segment) AS Total_Users_in_Segment
FROM
UserSegments
GROUP BY
user_segment
ORDER BY
Total_Users_in_Segment DESC;
-- 3. Which hashtags or content topics have the highest engagement rates? How can this information guide content strategy and ad campaigns?
WITH PhotoEngagement AS (
    SELECT
        p.id AS photo_id,
        COUNT(distinct l.photo_id) AS total_likes,
        COUNT(DISTINCT c.id) AS total_comments,
        COUNT(distinct l.photo_id) + COUNT(DISTINCT c.user_id) AS total_engagement
    FROM photos p
    LEFT JOIN likes l ON p.user_id = l.user_id
    LEFT JOIN comments c ON p.user_id = c.user_id
    GROUP BY p.id),
HashtagEngagement AS (
    SELECT
        t.id AS tag_id,
        t.tag_name,
        count(pe.total_engagement) AS total_engagement,
        COUNT(DISTINCT pt.photo_id) AS total_photos,
        (count(pe.total_engagement) / COUNT(DISTINCT pt.photo_id) )AS engagement_rate
    FROM tags t
    JOIN photo_tags pt ON t.id = pt.tag_id
    JOIN PhotoEngagement pe ON pt.photo_id = pe.photo_id
    GROUP BY t.id, t.tag_name)
SELECT tag_name, total_photos, total_engagement, engagement_rate
FROM HashtagEngagement
ORDER BY total_engagement DESC
limit 10;

-- 4.Are there any patterns or trends in user engagement based on demographics (age, location, gender) or posting times? How can these insights inform targeted marketing campaigns?
SELECT 
HOUR(p.created_dat) AS post_hour,
DAYOFWEEK(p.created_dat) AS post_day,
COUNT(DISTINCT p.id) AS total_photos_posted,
COUNT(DISTINCT l.photo_id) AS total_likes_received,
COUNT(DISTINCT c.id) AS total_comments_made
FROM photos p
 JOIN likes l ON p.id = l.photo_id
 JOIN comments c ON p.id = c.photo_id
GROUP BY post_hour, post_day
ORDER BY post_hour, post_day;
-- 5.Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns? How would you approach and collaborate with these influencers?
WITH TotalLikes AS (
    SELECT u.id, COUNT(distinct l.photo_id) AS total_likes
    FROM users u
    LEFT JOIN likes l ON u.id = l.user_id
    GROUP BY u.id),
TotalComments AS (
    SELECT u.id, COUNT(distinct c.photo_id) AS total_comments
    FROM users u
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY u.id),
PhotosPosted AS (
    SELECT user_id, COUNT(id) AS total_photos_posted
    FROM photos
    GROUP BY user_id),
Followers AS (
    SELECT followee_id AS user_id, COUNT(follower_id) AS total_followers
    FROM follows
    GROUP BY followee_id)
SELECT u.id AS user_id, u.username,
    COALESCE(tl.total_likes, 0) AS total_likes,
    COALESCE(tc.total_comments, 0) AS total_comments,
    COALESCE(pp.total_photos_posted, 0) AS total_photos_posted,
    COALESCE(f.total_followers, 0) AS total_followers,
    ((COALESCE(tl.total_likes, 0) + COALESCE(tc.total_comments, 0))/(COALESCE(pp.total_photos_posted, 0)))  as engagement_rate
FROM users u
JOIN TotalLikes tl ON u.id = tl.id
JOIN TotalComments tc ON u.id = tc.id
JOIN PhotosPosted pp ON u.id = pp.user_id
JOIN Followers f ON u.id = f.user_id
group by u.id 
having total_photos_posted >0
ORDER BY  engagement_rate desc, total_followers desc,total_photos_posted desc 
limit 10;
-- 6.Based on user behaviour and engagement data, how would you segment the user base for targeted marketing campaigns or personalized recommendations?
SELECT
    u.username,
    COUNT(DISTINCT p.id) AS posts_made,
    COUNT(l_rcvd.user_id) + COUNT(c_rcvd.id) AS engagement_received,
    COUNT(l_gn.photo_id) + COUNT(c_gn.photo_id) AS engagement_given,
    -- Segmentation Logic using direct metrics
    CASE
        -- Segment 1: Influencers/Creators (High posts AND High engagement received)
        WHEN COUNT(DISTINCT p.id) > 4 AND (COUNT(l_rcvd.user_id) + COUNT(c_rcvd.id)) > 160
            THEN 'Influencer/Creator'
        -- Segment 2: Lurkers/Heavy Socializers (Low posts BUT High engagement given)
        WHEN COUNT(DISTINCT p.id) <= 1 AND (COUNT(l_gn.photo_id) + COUNT(c_gn.photo_id)) > 450
            THEN 'Heavy Lurker/Socializer'
        -- Segment 3: Dormant (Zero posts AND Zero engagement given, and old account)
        WHEN COUNT(DISTINCT p.id) = 0 AND (COUNT(l_gn.photo_id) + COUNT(c_gn.photo_id)) = 0 AND u.created_at < DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
            THEN 'Dormant User'
        -- Segment 4: Casual/General User (The rest)
        ELSE 'Casual/General User'
    END AS user_segment
FROM users u
LEFT JOIN photos p ON u.id = p.user_id
-- Likes and Comments RECEIVED on their posts
LEFT JOIN likes l_rcvd ON p.id = l_rcvd.photo_id
LEFT JOIN comments c_rcvd ON p.id = c_rcvd.photo_id
-- Likes and Comments GIVEN by the user
LEFT JOIN likes l_gn ON u.id = l_gn.user_id AND p.id IS NULL 
LEFT JOIN comments c_gn ON u.id = c_gn.user_id AND p.id IS NULL 
GROUP BY u.id, u.username, u.created_at
LIMIT 10;

-- 7. If data on ad campaigns (impressions, clicks, conversions) is available, how would you measure their effectiveness and optimize future campaigns?
CREATE TABLE ad_campaigns (
    campaign_id VARCHAR(50) PRIMARY KEY,
    audience_segment VARCHAR(50) NOT NULL,
    ad_format VARCHAR(50) NOT NULL, -- e.g., 'Video', 'Static', 'Carousel'
    impressions INT NOT NULL,
    clicks INT NOT NULL,
    conversions INT NOT NULL,
    spend DECIMAL(10, 2) NOT NULL,
    revenue DECIMAL(10, 2) -- Necessary for ROAS calculation
);

INSERT INTO ad_campaigns (campaign_id, audience_segment, ad_format, impressions, clicks, conversions, spend, revenue) VALUES
('BCH-RETARGET', 'Heavy Lurker/Socializer', 'Static', 15000, 270, 23, 135.00, 800.00),     -- High CVR, Low CPA (Efficient)
('FOODIE-AFF', 'Influencer/Creator', 'Video', 22000, 440, 31, 286.00, 1100.00),     -- High CTR, Moderate CVR
('DORMANT-REAC', 'Dormant User', 'Static', 50000, 200, 4, 150.00, 50.00),           -- Low CVR, High CPA (Inefficient)
('GENERAL-FEED', 'Casual/General User', 'Carousel', 100000, 300, 15, 330.00, 450.00); 

SELECT
    campaign_id,
    ad_format,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    (SUM(clicks) / NULLIF(SUM(impressions), 0)) * 100 AS CTR_percent,
    (SUM(conversions) / NULLIF(SUM(clicks), 0)) * 100 AS CVR_percent,
    SUM(spend) / NULLIF(SUM(conversions), 0) AS CPA,
    SUM(revenue) / NULLIF(SUM(spend), 0) AS ROAS
FROM
    ad_campaigns
GROUP BY
    campaign_id, ad_format
ORDER BY
    CPA ASC, ROAS DESC;
    
-- 8.How can you use user activity data to identify potential brand ambassadors or advocates who could help promote Instagram's initiatives or events?
WITH ContentMetrics AS (
    -- Gathers post volume, engagement received, and topic diversity
    SELECT p.user_id, 
           COUNT(p.id) AS total_posts,
           COUNT(l.user_id) + COUNT(c.id) AS engagement_received,
           COUNT(DISTINCT pt.tag_id) AS unique_tags
    FROM photos p
    LEFT JOIN likes l ON p.id = l.photo_id
    LEFT JOIN comments c ON p.id = c.photo_id
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    GROUP BY p.user_id
),
ParticipationMetrics AS (
    -- Gathers user loyalty/community participation (engagement given)
    SELECT u.id, COUNT(l.photo_id) + COUNT(c.photo_id) AS engagement_given
    FROM users u
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY u.id
),
AudienceMetrics AS (
    -- Gathers influence/reach metrics
    SELECT followee_id AS user_id, COUNT(follower_id) AS total_followers
    FROM follows
    GROUP BY followee_id
)
SELECT u.username,
       COALESCE(cm.total_posts, 0) AS Content_Volume,
       (COALESCE(cm.engagement_received, 0) / NULLIF(COALESCE(cm.total_posts, 0), 0)) AS Engagement_Rate,
       COALESCE(pm.engagement_given, 0) AS Participation_Score,
       COALESCE(am.total_followers, 0) AS Total_Followers,
       -- Simplified Ambassador Score (Weighted Sum for ranking)
       ( (COALESCE(cm.engagement_received, 0) * 0.3) +  
         (COALESCE(pm.engagement_given, 0) * 0.2) +    
         (COALESCE(cm.total_posts, 0) * 0.1) )         
         AS Ambassador_Score
FROM users u
LEFT JOIN ContentMetrics cm ON u.id = cm.user_id
LEFT JOIN ParticipationMetrics pm ON u.id = pm.id
LEFT JOIN AudienceMetrics am ON u.id = am.user_id
WHERE COALESCE(cm.total_posts, 0) > 0  
ORDER BY Ambassador_Score DESC
LIMIT 10;

-- 9 How would you approach this problem, if the objective and subjective questions weren't given?
SELECT
    u.username,
    COUNT(p.id) AS total_posts_made,
    COUNT(l.user_id) AS total_likes_received,
    COUNT(c.id) AS total_comments_received
FROM
    users u
INNER JOIN
    photos p ON u.id = p.user_id
LEFT JOIN
    likes l ON p.id = l.photo_id
LEFT JOIN
    comments c ON p.id = c.photo_id
GROUP BY
    u.id, u.username
ORDER BY
    total_posts_made DESC, total_likes_received DESC
LIMIT 10;

-- 10.Assuming there's a "User_Interactions" table tracking user engagements, 
-- how can you update the "Engagement_Type" column to change all instances of "Like" to "Heart" to align with Instagram's terminology?
### 1. Create the Table
CREATE TABLE User_Interactions (
    user_id INT NOT NULL,
    photo_id INT NOT NULL,
    Engagement_Type VARCHAR(50) NOT NULL
);
### 2. Insert Sample Data
INSERT INTO User_Interactions (user_id, photo_id, Engagement_Type) VALUES
(1, 1, 'Like'),
(2, 5, 'Comment'),
(3, 10, 'Like'),
(4, 15, 'Share'),
(5, 20, 'Like'),
(1, 3, 'Like'),
(2, 7, 'Like'),
(3, 12, 'Comment'),
(4, 18, 'Like'),
(5, 22, 'Share');

### update table 
UPDATE
User_Interactions
SET
Engagement_Type = 'Heart'
WHERE
Engagement_Type = 'Like';

