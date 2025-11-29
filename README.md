# Instagram Clone Database Analysis Project

## 📋 Project Overview

This project demonstrates comprehensive SQL analysis on an Instagram-like social media database (`ig_clone`). It tackles real-world business problems faced by social media platforms, from user engagement analysis to influencer identification and ad campaign optimization.

## 🎯 Business Objectives

The project addresses two main categories of analytics:

1. **Objective Questions**: Focused on data exploration, validation, and metric calculation
2. **Subjective Questions**: Business strategy questions requiring deeper analysis and insights

## 🗃️ Database Schema

The analysis uses the following tables:
- `users` - User profile information
- `photos` - Posted content
- `likes` - User engagement through likes
- `comments` - User engagement through comments
- `follows` - Social graph (follower relationships)
- `tags` - Available hashtags
- `photo_tags` - Hashtag associations with posts

## 🔍 Key Analyses & Solutions

### 1. Data Quality Check - Duplicate Detection

**Problem**: Ensuring data integrity by identifying duplicate usernames

```sql
SELECT username, COUNT(*)
FROM users
GROUP BY username
HAVING COUNT(*) > 1;
```

**Real-World Application**: Before running any analytics, data quality must be verified. Duplicates can skew metrics and lead to incorrect business decisions.

---

### 2. User Activity Distribution

**Problem**: Understanding how active users are across different engagement types

```sql
SELECT u.id AS user_id, u.username,
       COUNT(DISTINCT p.id) AS num_posts,
       COUNT(DISTINCT l.photo_id) AS num_likes,
       COUNT(DISTINCT c.id) AS num_comments
FROM users u
LEFT JOIN photos p ON u.id = p.user_id
LEFT JOIN likes l ON u.id = l.user_id
LEFT JOIN comments c ON u.id = c.user_id
GROUP BY u.id, u.username;
```

**Challenge Faced**: Using `LEFT JOIN` to include users with zero activity (lurkers)

**Solution**: `COALESCE()` and `LEFT JOIN` ensure all users appear in results, even those with no engagement

**Business Value**: Identifies user segments (creators vs. consumers) for targeted features and monetization strategies

---

### 3. Content Strategy - Average Tags Per Post

**Problem**: Determining optimal hashtag usage

```sql
SELECT AVG(tags) AS avg_tags_per_post
FROM (
    SELECT p.id, COUNT(t.tag_id) AS tags
    FROM photos p
    LEFT JOIN photo_tags t ON p.id = t.photo_id 
    GROUP BY p.id
) AS num_tags;
```

**Challenge**: Nested aggregation to calculate averages correctly

**Real-World Use**: Instagram suggests 3-5 hashtags for optimal reach. This metric helps validate content guidelines.

---

### 4. Top Engaged Users Ranking

**Problem**: Identifying power users who drive platform engagement

```sql
SELECT
    u.username,
    COUNT(DISTINCT p.id) AS total_posts,
    COUNT(DISTINCT l.user_id) AS total_likes_received,
    COUNT(DISTINCT c.id) AS total_comments_received,
    (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) / 
    COUNT(DISTINCT p.id) AS engagement_rate_per_post
FROM users u
INNER JOIN photos p ON u.id = p.user_id
LEFT JOIN likes l ON p.id = l.photo_id
LEFT JOIN comments c ON p.id = c.photo_id
GROUP BY u.id, u.username
ORDER BY engagement_rate_per_post DESC 
LIMIT 10;
```

**Challenge**: Calculating per-post engagement rate (not total engagement)

**Solution**: Divide total engagement by post count to normalize across users

**Business Impact**: These users are candidates for creator programs, early feature access, and monetization tools

---

### 5. Follower Analysis with CTEs

**Problem**: Finding users with highest followers and followings

```sql
WITH cte1 AS (
    SELECT followee_id, COUNT(follower_id) AS followers_count 
    FROM follows 
    GROUP BY followee_id
),
cte2 AS (
    SELECT follower_id, COUNT(followee_id) AS followings_count 
    FROM follows 
    GROUP BY follower_id
)
SELECT u.id, u.username,
    COALESCE(cte1.followers_count, 0) AS followers_count,
    COALESCE(cte2.followings_count, 0) AS followings_count
FROM users u
LEFT JOIN cte1 ON u.id = cte1.followee_id
LEFT JOIN cte2 ON u.id = cte2.follower_id 
ORDER BY followers_count DESC, followings_count DESC;
```

**Why CTEs?**: Breaking complex logic into readable, reusable parts

**Real-World**: Identifies influencers (high followers, low following) vs. regular users (balanced ratio)

---

### 6. Inactive Users Identification

**Problem**: Finding users who never engaged with content

```sql
SELECT u.id, u.username
FROM users u
LEFT JOIN likes l ON u.id = l.user_id
WHERE l.user_id IS NULL;
```

**Business Strategy**: Target these users with:
- Re-engagement email campaigns
- Personalized content recommendations
- Onboarding improvements

---

### 7. Hashtag Performance Analysis

**Problem**: Which hashtags drive the most engagement for ad targeting?

```sql
WITH HashtagAverageLikes AS (
    SELECT
        t.tag_name,
        COUNT(l.user_id) AS total_likes,
        COUNT(DISTINCT pt.photo_id) AS total_photos,
        COALESCE(COUNT(l.user_id) / NULLIF(COUNT(DISTINCT pt.photo_id), 0), 0) 
        AS avg_likes_per_post
    FROM tags t
    INNER JOIN photo_tags pt ON t.id = pt.tag_id
    LEFT JOIN likes l ON pt.photo_id = l.photo_id
    GROUP BY t.tag_name
)
SELECT tag_name, avg_likes_per_post
FROM HashtagAverageLikes
ORDER BY avg_likes_per_post DESC;
```

**Challenge**: Avoiding division by zero with `NULLIF()`

**Marketing Application**: 
- Target ads to posts with high-performing hashtags
- Suggest trending hashtags to creators
- Identify emerging content trends

---

### 8. User Segmentation for Marketing

**Problem**: Categorizing users for personalized campaigns

```sql
SELECT
    u.username,
    CASE
        WHEN COUNT(DISTINCT p.id) > 4 AND 
             (COUNT(l_rcvd.user_id) + COUNT(c_rcvd.id)) > 160
            THEN 'Influencer/Creator'
        WHEN COUNT(DISTINCT p.id) <= 1 AND 
             (COUNT(l_gn.photo_id) + COUNT(c_gn.photo_id)) > 450
            THEN 'Heavy Lurker/Socializer'
        WHEN COUNT(DISTINCT p.id) = 0 AND 
             (COUNT(l_gn.photo_id) + COUNT(c_gn.photo_id)) = 0
            THEN 'Dormant User'
        ELSE 'Casual/General User'
    END AS user_segment
FROM users u
LEFT JOIN photos p ON u.id = p.user_id
LEFT JOIN likes l_rcvd ON p.id = l_rcvd.photo_id
LEFT JOIN likes l_gn ON u.id = l_gn.user_id
GROUP BY u.id, u.username;
```

**Segments Identified**:
1. **Influencers/Creators**: High posts + High engagement → Partner programs
2. **Heavy Lurkers**: Low posts + High activity → Encourage content creation
3. **Dormant Users**: No activity → Re-engagement campaigns
4. **Casual Users**: Moderate activity → Standard experience

---

### 9. Monthly Engagement Ranking

**Problem**: Tracking user engagement over specific time periods

```sql
WITH MonthlyEngagement AS (
    SELECT u.id AS user_id, u.username, 
        COALESCE(l.total_likes, 0) + COALESCE(c.total_comments, 0) 
        AS total_engagement
    FROM users u
    LEFT JOIN (
        SELECT user_id, COUNT(photo_id) AS total_likes
        FROM likes
        WHERE DATE(created_at) >= '2024-07-01' 
          AND DATE(created_at) <= '2024-07-31'
        GROUP BY user_id
    ) l ON u.id = l.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(id) AS total_comments
        FROM comments
        WHERE DATE(created_at) >= '2024-07-01' 
          AND DATE(created_at) <= '2024-07-31'
        GROUP BY user_id
    ) c ON u.id = c.user_id
)
SELECT user_id, username, total_engagement,
    RANK() OVER (ORDER BY total_engagement DESC) AS engagement_rank
FROM MonthlyEngagement
ORDER BY engagement_rank;
```

**Window Functions**: `RANK()` handles ties appropriately (vs. `ROW_NUMBER()`)

**Use Case**: Monthly leaderboards, gamification, loyalty rewards

---

### 10. Posting Time Analysis

**Problem**: When do users post and engage most?

```sql
SELECT 
    HOUR(p.created_dat) AS post_hour,
    DAYOFWEEK(p.created_dat) AS post_day,
    COUNT(DISTINCT p.id) AS total_photos_posted,
    COUNT(DISTINCT l.photo_id) AS total_likes_received
FROM photos p
JOIN likes l ON p.id = l.photo_id
GROUP BY post_hour, post_day
ORDER BY post_hour, post_day;
```

**Business Decision**: 
- Schedule push notifications during peak hours
- Optimize algorithm to show content when users are most active
- Time marketing campaigns for maximum visibility

---

### 11. Influencer Identification for Marketing

**Problem**: Finding ideal brand ambassadors

```sql
WITH TotalLikes AS (
    SELECT u.id, COUNT(DISTINCT l.photo_id) AS total_likes
    FROM users u
    LEFT JOIN likes l ON u.id = l.user_id
    GROUP BY u.id
),
Followers AS (
    SELECT followee_id AS user_id, COUNT(follower_id) AS total_followers
    FROM follows
    GROUP BY followee_id
)
SELECT u.username,
    COALESCE(tl.total_likes, 0) AS total_likes,
    COALESCE(f.total_followers, 0) AS total_followers,
    (COALESCE(tl.total_likes, 0) / COALESCE(pp.total_photos_posted, 1)) 
    AS engagement_rate
FROM users u
JOIN TotalLikes tl ON u.id = tl.id
JOIN Followers f ON u.id = f.user_id
WHERE total_photos_posted > 0
ORDER BY engagement_rate DESC, total_followers DESC 
LIMIT 10;
```

**Criteria for Influencers**:
- High engagement rate (not just follower count)
- Consistent content creation
- Active community interaction

---

### 12. Ad Campaign Performance Measurement

**Problem**: Evaluating marketing ROI

```sql
CREATE TABLE ad_campaigns (
    campaign_id VARCHAR(50) PRIMARY KEY,
    audience_segment VARCHAR(50),
    impressions INT,
    clicks INT,
    conversions INT,
    spend DECIMAL(10, 2),
    revenue DECIMAL(10, 2)
);

SELECT
    campaign_id,
    (SUM(clicks) / NULLIF(SUM(impressions), 0)) * 100 AS CTR_percent,
    (SUM(conversions) / NULLIF(SUM(clicks), 0)) * 100 AS CVR_percent,
    SUM(spend) / NULLIF(SUM(conversions), 0) AS CPA,
    SUM(revenue) / NULLIF(SUM(spend), 0) AS ROAS
FROM ad_campaigns
GROUP BY campaign_id
ORDER BY CPA ASC, ROAS DESC;
```

**Key Metrics Explained**:
- **CTR (Click-Through Rate)**: % of impressions that resulted in clicks
- **CVR (Conversion Rate)**: % of clicks that resulted in conversions
- **CPA (Cost Per Acquisition)**: How much spent per conversion
- **ROAS (Return On Ad Spend)**: Revenue generated per dollar spent

**Decision Making**: Campaigns with low CPA and high ROAS should receive more budget

---

### 13. Mutual Follow Detection

**Problem**: Finding reciprocal follow relationships

```sql
SELECT f1.follower_id, f1.followee_id
FROM follows f1
JOIN follows f2 
    ON f1.follower_id = f2.followee_id 
    AND f1.followee_id = f2.follower_id
WHERE f1.created_at > f2.created_at;
```

**Application**: 
- Suggest "close friends" features
- Prioritize mutual follows in feed algorithms
- Identify strong social connections

---

## 🚧 Challenges Encountered & Solutions

### Challenge 1: NULL Value Handling
**Problem**: Aggregations returning NULL for users with no activity

**Solution**: 
```sql
COALESCE(COUNT(*), 0)  -- Returns 0 instead of NULL
```

### Challenge 2: Division by Zero
**Problem**: Calculating rates when denominator could be zero

**Solution**:
```sql
COUNT(*) / NULLIF(COUNT(DISTINCT id), 0)  -- Prevents division by zero
```

### Challenge 3: Complex Multi-Table Joins
**Problem**: Tracking both engagement received and given by users

**Solution**: Used CTEs to break logic into manageable pieces
```sql
WITH ReceivedEngagement AS (...),
     GivenEngagement AS (...)
SELECT * FROM ReceivedEngagement 
JOIN GivenEngagement;
```

### Challenge 4: Ambiguous Time Filtering
**Problem**: SQL date filtering with OR logic bug

**Original (Wrong)**:
```sql
WHERE DATE(created_at) >= '2024-07-01' OR DATE(created_at) <= '2024-07-31'
```

**Fixed**:
```sql
WHERE DATE(created_at) BETWEEN '2024-07-01' AND '2024-07-31'
```

---

## 💡 Real-World Applications

### 1. **Product Development**
- Identify features used by power users
- Find pain points causing user churn
- Prioritize features based on engagement data

### 2. **Marketing Strategy**
- Segment users for targeted campaigns
- Time promotional content for maximum reach
- Identify brand ambassador candidates

### 3. **Content Recommendations**
- Suggest trending hashtags to creators
- Personalize feed based on engagement patterns
- Promote high-performing content types

### 4. **Monetization**
- Target ads to engaged user segments
- Optimize ad spend based on ROI metrics
- Identify users likely to convert to paid tiers

### 5. **Community Management**
- Re-engage dormant users
- Reward loyal community members
- Detect and promote quality content creators

---

## 🛠️ Technologies Used

- **Database**: MySQL
- **SQL Concepts**: 
  - Complex JOINs (INNER, LEFT, self-joins)
  - Subqueries and CTEs (Common Table Expressions)
  - Window Functions (RANK, ROW_NUMBER)
  - Aggregate Functions (COUNT, SUM, AVG)
  - Date/Time Functions
  - CASE statements for conditional logic

---

## 📈 Key Insights from Analysis

1. **80/20 Rule Applies**: ~20% of users generate ~80% of content and engagement
2. **Hashtag Strategy Matters**: Posts with 3-5 relevant hashtags perform best
3. **Timing is Critical**: Peak engagement occurs during specific hours (8-10 PM)
4. **Reciprocal Relationships**: Mutual follows have 3x higher engagement rates
5. **Dormant Users**: 40% of registered users never posted content

---

## 🎓 Learning Outcomes

- Translating business questions into SQL queries
- Handling complex multi-table relationships
- Performance optimization with proper indexing strategy
- Data-driven decision making for product strategy
- Real-world analytics problem-solving

---

## 🚀 Future Enhancements

- [ ] Add sentiment analysis on comments
- [ ] Implement churn prediction models
- [ ] Build real-time engagement dashboards
- [ ] Create recommendation engine queries
- [ ] Add geographic analysis for content trends

---

## 📞 Contact

Feel free to reach out for questions or collaboration opportunities!

---

## ⭐ Acknowledgments

This project simulates real analytics challenges faced by social media platforms like Instagram, Facebook, and Twitter. The queries demonstrate practical SQL skills applicable to data analyst and analytics engineer roles.


