USE cusbeaty_db;

-- SELECT hour 
-- FROM customer_beauty_data;
-- 首先处理空值
SELECT *
FROM customer_beauty_data
WHERE user_id is null 
or item_id is null 
or item_category is null 
or behavior_type is null 
or date is null 
or hour is null
or user_geohash is null;
-- 结果1可以看到，数据集无空值

-- 接下来处理重复值
SELECT
    user_id,
    item_id,
    date,
    hour,
    behavior_type,
    user_geohash
FROM
    customer_beauty_data
GROUP BY
    user_id,
    item_id,
    date,
    hour,
    behavior_type,
    user_geohash
HAVING
    COUNT(*) > 1;
-- 结果2可以看到重复记录有2000+，接下来将它们去重

-- 发现直接delete耗时太久了，这里建一个临时表存储去重记录再插回原表    
-- DROP TABLE temp_table;
CREATE TABLE temp_table AS 
SELECT DISTINCT * 
FROM customer_beauty_data;

TRUNCATE TABLE customer_beauty_data;

INSERT INTO customer_beauty_data 
SELECT * 
FROM temp_table;

DROP TABLE temp_table;

-- 日流量分析
CREATE TABLE ed_pv_uv(date CHAR(10),PV INT(9),UV INT(9),PVUV DECIMAL(10,3));


INSERT INTO ed_pv_uv
SELECT 
  date,
  COUNT(IF(behavior_type=1,1,NULL)) AS PV,
  COUNT(DISTINCT user_id) AS UV,
  ROUND(COUNT(IF(behavior_type=1,1,NULL))/COUNT(DISTINCT user_id),3) AS PVUV
FROM customer_beauty_data
GROUP BY date
ORDER BY date;

-- 小时级流量分析
CREATE TABLE hours_pv_uv (date char(10),pv_hours int(9),uv_hours int(9),pvuv_hours DECIMAL(10,3));

INSERT INTO hours_pv_uv
SELECT
    `hour`,
    count(IF(behavior_type=1,1,NULL)) pv_hours,
    count(DISTINCT user_id) uv_hours,
    round(count(IF(behavior_type=1,1,NULL)) / count(DISTINCT user_id),3) pvuv_hours
FROM
    customer_beauty_data
GROUP BY
    `hour`
ORDER BY
    `hour`;
    
-- 下面是购买次数

CREATE TABLE buy_times (user_id varchar(25),times int(10));

INSERT INTO buy_times
SELECT
    user_id,
    count(user_id) times
FROM
    customer_beauty_data
WHERE
    behavior_type=4
GROUP BY
    user_id,
    user_geohash
ORDER BY
    times desc;
    
    
-- 看复购率如下：


SELECT
    CONCAT(ROUND(COUNT(sub.user_id) / COUNT(*), 2) * 100, '%') AS ratio
FROM
(
    SELECT
        user_id
    FROM
        customer_beauty_data
    WHERE
        behavior_type = 4
    GROUP BY
        user_id,
        user_geohash
    HAVING
        COUNT(user_id) >= 2
) AS sub
RIGHT JOIN
    customer_beauty_data AS a ON a.user_id = sub.user_id
WHERE
    a.behavior_type = 4 

-- 接下来是用户留存
-- 次日留存
CREATE table df_retention_1
(
    date char(10),
    user_count int,
    retention_user_count int,
    retention_rate decimal(10,3)
);

insert into df_retention_1
select
    cbd1.date,
    count(distinct cbd1.user_id) as user_count,
    count(distinct cbd2.user_id) as retention_user_count,
    round(count(distinct cbd2.user_id)/count(distinct cbd1.user_id),3) as retention_rate
from
    (
        select
            distinct user_id,
            `date`
        from
            customer_beauty_data
    ) cbd1
left join
    (
        select
            distinct user_id,
            `date`
        from
            customer_beauty_data
    ) cbd2
on cbd1.user_id = cbd2.user_id
and cbd2.date = date_add(cbd1.date, interval 1 day)
group by
    cbd1.date
order by
    cbd1.date;
    
-- 然后是五日留存率
CREATE TABLE df_retention_5 (
    date VARCHAR(25),
    retention_5 FLOAT
);

INSERT INTO df_retention_5
SELECT
    cbd1.`date`,
    COUNT(cbd2.user_id) / COUNT(cbd1.user_id) AS retention_5
FROM
    (
        SELECT
            DISTINCT user_id,
            `date`
        FROM
            customer_beauty_data 
    ) cbd1
LEFT JOIN
    (
        SELECT
            DISTINCT user_id,
            `date`
        FROM
            customer_beauty_data 
    ) cbd2
ON cbd1.user_id = cbd2.user_id
AND cbd2.date = DATE_ADD(cbd1.date, INTERVAL 5 day)
GROUP BY
    cbd1.date
ORDER BY
    cbd1.date;
-- --我们以日期和时间分组，分别统计不同日期和不同时间下，进行浏览、收藏、加入购物车、购买这四种行为的人数各有多少
     
-- 先 是日期

CREATE TABLE df_users_count_date (date VARCHAR(25),pv_date int(10),fav_date int(10),cart_date int(10),buy_date int(10));

INSERT INTO df_users_count_date
SELECT
    date,
    count(if(behavior_type=1,1,null)) pv_date,
    count(if(behavior_type=2,1,null)) fav_date,
    count(if(behavior_type=3,1,null)) cart_date,
    count(if(behavior_type=4,1,null)) buy_date
FROM
    customer_beauty_data
GROUP BY
    date
ORDER BY
    date;
    
-- 再以小时级分组
CREATE TABLE df_users_count_hour (`hour` int(9),pv_hour int(10),fav_hour int(10),cart_hour int(10),buy_hour int(10));

INSERT INTO df_users_count_hour
SELECT
    `hour`,
    count(if(behavior_type=1,1,null)) pv_hour,
    count(if(behavior_type=2,1,null)) fav_hour,
    count(if(behavior_type=3,1,null)) cart_hour,
    count(if(behavior_type=4,1,null)) buy_hour
FROM
    customer_beauty_data  
GROUP BY
    `hour`
ORDER BY
    `hour`;
    
-- 接下来是购买地区分布
CREATE TABLE df_customer_geohash_distribution (
    user_geohash VARCHAR(25),
    NUM int(9)
);

INSERT INTO df_customer_geohash_distribution
SELECT
    user_geohash,
    count(user_id) NUM
FROM
    customer_beauty_data
WHERE
    behavior_type = 4
GROUP BY
    user_geohash;
    
-- 接下来是热门商品和热门品类统计表格
-- 创建热门商品表（按购买量排序，取前10）
CREATE TABLE df_popular_item (
    item_id int(10),
    item_hot int(20)
);

INSERT INTO df_popular_item
SELECT
    item_id,
    count(item_id) item_hot
FROM
    customer_beauty_data
WHERE
    behavior_type = 4
GROUP BY
    item_id
ORDER BY
    item_hot desc,
    item_id
LIMIT 10;

-- 创建热门品类表（按购买量排序，取前10）
CREATE TABLE df_popular_category (item_category int(10),category_hot int(20));

INSERT INTO df_popular_category
SELECT
    item_category,
    count(item_category) category_hot
FROM
    customer_beauty_data
WHERE
    behavior_type = 4
GROUP BY
    item_category
ORDER BY
    category_hot desc
LIMIT 10;

-- 这里选取的是top10的商品和种类


-- 接下来是每个商品种类被浏览、收藏、架构、购买的次数，看看那种商品需求大。
CREATE TABLE df_category_count (
    item_category int(10),
    pv int(10),
    fav int(10),
    cart int(10),
    buy int(10));

INSERT INTO df_category_count
SELECT
    item_category,
    COUNT(IF(behavior_type=1,1,NULL)) pv,
    COUNT(IF(behavior_type=2,1,NULL)) fav,
    COUNT(IF(behavior_type=3,1,NULL)) cart,
    COUNT(IF(behavior_type=4,1,NULL)) buy
FROM
    customer_beauty_data 
GROUP BY
    item_category;
    


-- 漏斗分析，差点漏了
-- 存储两条链路的漏斗转化数据
CREATE TABLE funnel_analysis (
    funnel_type VARCHAR(50),  -- 漏斗类型：直接购买/加购收藏后购买
    browse_count INT,         -- 浏览用户数
    middle_count INT,         -- 中间步骤用户数（直接购买链路无中间步骤，记为0）
    buy_count INT,            -- 最终购买用户数
    middle_conversion DECIMAL(10,3),  -- 浏览到中间步骤转化率
    final_conversion DECIMAL(10,3)    -- 浏览到购买最终转化率
);

INSERT INTO funnel_analysis
-- 第一条链路：浏览-直接购买（无加购/收藏行为）
SELECT 
    '浏览-直接购买' AS funnel_type,
    COUNT(DISTINCT b.user_id) AS browse_count,
    0 AS middle_count,  -- 无中间步骤
    COUNT(DISTINCT p.user_id) AS buy_count,
    0 AS middle_conversion,  -- 无中间步骤转化
    ROUND(COUNT(DISTINCT p.user_id) / COUNT(DISTINCT b.user_id), 3) AS final_conversion
FROM 
    -- 筛选有浏览行为的用户
    (SELECT DISTINCT user_id FROM customer_beauty_data WHERE behavior_type = 1) b
LEFT JOIN 
    -- 筛选有购买行为且无加购/收藏行为的用户
    (SELECT DISTINCT user_id 
     FROM customer_beauty_data 
     WHERE behavior_type = 4
       AND user_id NOT IN (
           -- 排除有过加购或收藏行为的用户
           SELECT DISTINCT user_id 
           FROM customer_beauty_data 
           WHERE behavior_type IN (2, 3)
       )) p
ON b.user_id = p.user_id

UNION ALL

-- 第二条链路：浏览-收藏/加购-购买（有中间步骤）
SELECT 
    '浏览-收藏/加购-购买' AS funnel_type,
    COUNT(DISTINCT b.user_id) AS browse_count,
    COUNT(DISTINCT m.user_id) AS middle_count,  -- 加购/收藏用户数
    COUNT(DISTINCT p.user_id) AS buy_count,
    -- 浏览到加购/收藏的转化率
    ROUND(COUNT(DISTINCT m.user_id) / COUNT(DISTINCT b.user_id), 3) AS middle_conversion,
    -- 浏览到最终购买的转化率
    ROUND(COUNT(DISTINCT p.user_id) / COUNT(DISTINCT b.user_id), 3) AS final_conversion
FROM 
    -- 筛选有浏览行为的用户
    (SELECT DISTINCT user_id FROM customer_beauty_data WHERE behavior_type = 1) b
LEFT JOIN 
    -- 筛选有过加购或收藏行为的用户（中间步骤）
    (SELECT DISTINCT user_id 
     FROM customer_beauty_data 
     WHERE behavior_type IN (2, 3)) m
ON b.user_id = m.user_id
LEFT JOIN 
    -- 筛选有购买行为且有过加购/收藏行为的用户
    (SELECT DISTINCT user_id 
     FROM customer_beauty_data 
     WHERE behavior_type = 4
       AND user_id IN (
           SELECT DISTINCT user_id 
           FROM customer_beauty_data 
           WHERE behavior_type IN (2, 3)
       )) p
ON m.user_id = p.user_id;




-- 这是一道分割线
