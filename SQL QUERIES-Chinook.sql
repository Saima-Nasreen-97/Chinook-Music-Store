
USE CHINOOK;

-- Q-1 Does any table have missing values or duplicates? If yes, how would you handle it?
-- Handling Duplicates
SELECT track_id,
       COUNT(*) AS COUNT
FROM track
GROUP BY track_id
HAVING COUNT(*) >1;

-- Handling Nulls
SELECT *
FROM playlist
WHERE playlist_id IS NULL
or name IS NULL;
SELECT *
FROM artist
WHERE artist_id IS NULL
or name IS NULL;


-- Q-2 Find the top-selling tracks and top artist in the USA and identify their most famous genres.
WITH TopTracks AS (
                             SELECT t.track_id,
                                          t.name AS track_name, 
                                          g.name AS genre_name, 
                                          SUM(il.quantity) AS total_units_sold
                            FROM invoice_line il
                            JOIN invoice i 
                                ON il.invoice_id = i.invoice_id
                         JOIN track t 
                              ON il.track_id = t.track_id
                         JOIN genre g 
                             ON t.genre_id = g.genre_id
                          WHERE i.billing_country = 'USA'
                          GROUP BY t.track_id, t.name, g.name
                          ORDER BY total_units_sold DESC
                           LIMIT 5
),
TopArtist AS (
                     SELECT ar.artist_id, 
                                  ar.name AS artist_name,
                                  SUM(il.quantity) AS total_units_sold
                    FROM invoice_line il
                      JOIN invoice i 
                          ON il.invoice_id = i.invoice_id
                      JOIN track t 
                          ON il.track_id = t.track_id
                      JOIN album al 
                          ON t.album_id = al.album_id
                      JOIN artist ar 
                          ON al.artist_id = ar.artist_id
                      WHERE i.billing_country = 'USA'
                      GROUP BY ar.artist_id, ar.name
                      ORDER BY total_units_sold DESC
                       LIMIT 1
),
TopArtistGenre AS (
                            SELECT DISTINCT ar.artist_id,
                                          g.name AS genre_name
                            FROM track t
                             JOIN album al 
                                 ON t.album_id = al.album_id
                             JOIN artist ar 
                                 ON al.artist_id = ar.artist_id
                             JOIN genre g 
                                 ON t.genre_id = g.genre_id
                              WHERE ar.artist_id = (SELECT artist_id FROM TopArtist)
)
                              SELECT 'Top Tracks' AS category, 
                                            track_name AS name, 
                                            genre_name, 
                                            total_units_sold 
                              FROM TopTracks
                             UNION ALL
                             SELECT 'Top Artist', 
                                           artist_name, 
                                           genre_name, 
                                           total_units_sold 
                             FROM TopArtistGenre
                             JOIN TopArtist USING (artist_id);

-- Q-3 What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?
SELECT country, COUNT(customer_id) AS total_customers
FROM customer
GROUP BY country
ORDER BY total_customers DESC;

-- Q-4 Calculate the total revenue and number of invoices for each country, state, and city?

SELECT     billing_country AS country, 
           billing_state AS state,
           billing_city AS city, 
          COUNT(invoice_id) AS total_invoices,
          SUM(total) AS total_revenue
FROM invoice
GROUP BY billing_country, billing_state, billing_city
ORDER BY total_revenue DESC;

-- Q-5 Find the top 5 customers by total revenue in each country?

WITH CustomerRevenue AS (
                                    SELECT c.customer_id,
                                               c.first_name,
                                              c.last_name,
                                              i.billing_country AS country,
                                             SUM(i.total) AS total_revenue,
                                             DENSE_RANK() OVER (PARTITION BY i.billing_country 
                                             ORDER BY SUM(i.total) DESC) AS rnk
                                 FROM customer c
                                 JOIN invoice i 
                                    ON c.customer_id = i.customer_id
                                GROUP BY c.customer_id,
                                                  c.first_name,
                                                  c.last_name,
                                                  i.billing_country
)
                                    SELECT customer_id, 
                                                  first_name,
                                                 last_name,
                                                  country,
                                                  total_revenue
                                  FROM CustomerRevenue
                                  WHERE rnk <= 5
                                   ORDER BY country DESC,total_revenue DESC;

-- -- Q-6 Identify the top-selling track for each customer?
WITH CustomerTrackSales AS (
                                        SELECT i.Customer_Id,
                                                    il.Track_Id,t.Name AS track_name,
                                                    SUM(il.Quantity) AS total_quantity_sold
                                        FROM Invoice_Line il
                                        JOIN Invoice i 
                                            ON il.Invoice_Id = i.Invoice_Id
                                        JOIN Customer c 
                                            ON i.Customer_Id = c.Customer_Id
                                        JOIN Track t
                                            ON il.Track_Id = t.Track_Id
                                         GROUP BY i.Customer_Id,il.Track_Id, t.Name
),
 RankedTracks AS (
                                SELECT Customer_Id,
                                              track_name,
                                              total_quantity_sold,
                                             ROW_NUMBER() OVER (PARTITION BY Customer_Id 
                                                 ORDER BY total_quantity_sold DESC) AS row_num
                                FROM CustomerTrackSales
)
                               SELECT Customer_Id,
                                            track_name, 
                                            total_quantity_sold
                               FROM RankedTracks
                             WHERE row_num = 1
                             ORDER BY customer_id ASC;

-- Q-7 Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?

SELECT       c.customer_id,
             concat(c.first_name, ' ', c.last_name) as customer_name,
             count(i.invoice_id) as total_purchases,
             ROUND(avg(i.total), 2) as average_order_value,
             ROUND(sum(i.total), 2) as total_spent
 FROM customer c
 JOIN invoice I 
    ON  c.customer_id = i.customer_id
 GROUP BY c.customer_id, customer_name
 ORDER BY total_spent DESC;
 
 -- Q-8 What is the customer churn rate?
 WITH customer_activity as (
                                        SELECT 
                                                    c.customer_id,
                                                    max(i.invoice_date) as last_purchase_date
                                         FROM customer c
                                         JOIN invoice i on c.customer_id = i.customer_id
                                         GROUP BY c.customer_id
),
churn_cutoff as (
                                         SELECT date_sub(max(invoice_date), interval 6 month) 
                                                                                                       as cutoff_date
                                         FROM invoice
),
status_counts as (
                     SELECT 
                            CASE 
                               WHEN ca.last_purchase_date < cc.cutoff_date THEN 'churned'
                                ELSE 'active'
                                END AS customer_status,
                                count(*) as customer_count
                    FROM customer_activity ca
                    CROSS JOIN churn_cutoff cc
                    GROUP BY customer_status
),
totals as (
                     SELECT sum(customer_count) as total_customers
                     FROM status_counts
)
                     SELECT 
                                  sc.customer_status,
                                  sc.customer_count,
                                  ROUND(sc.customer_count / t.total_customers * 100, 2) 
                                                                          as churn_rate_percent
                  FROM status_counts sc
                  CROSS JOIN totals t ;
                  
-- Q-9 Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists?
---                        -- Percentage of Total Sales by each Genre in the USA -- 
WITH GenreSales AS (
                               SELECT g.genre_id,g.name AS genre_name,
                                          SUM(il.unit_price * il.quantity) AS total_sales
                                FROM invoice i
                                JOIN invoice_line il
                                    ON i.invoice_id = il.invoice_id
                                JOIN track t 
                                    ON il.track_id = t.track_id
                                JOIN genre g
                                    ON t.genre_id = g.genre_id
                                JOIN customer c
                                    ON i.customer_id = c.customer_id
                                WHERE c.country = 'USA'
                                GROUP BY g.genre_id, g.name
),
TotalSales AS (
                             SELECT SUM(total_sales) AS overall_sales 
                              FROM GenreSales
)
                              SELECT gs.genre_name,
                                          gs.total_sales,
                                          ROUND((gs.total_sales / ts.overall_sales) * 100,2) AS  sales_percentage
                              FROM GenreSales gs
                              CROSS JOIN TotalSales ts
                              ORDER BY gs.total_sales DESC;
--- 		          -- Query to find best-selling artist in USA --
WITH ArtistSales AS (
                         SELECT ar.artist_id,
                                      ar.name AS artist_name,
                                      SUM(il.unit_price * il.quantity) AS total_sales
                       FROM invoice i
                       JOIN invoice_line il 
                           ON i.invoice_id = il.invoice_id
                       JOIN track t
                          ON il.track_id = t.track_id
                      JOIN album al
                          ON t.album_id = al.album_id
                      JOIN artist ar 
                          ON al.artist_id = ar.artist_id
                      JOIN customer c
                          ON i.customer_id = c.customer_id
                      WHERE c.country = 'USA'
                      GROUP BY ar.artist_id, ar.name
)
                     SELECT artist_name, 
                                 total_sales
                     FROM ArtistSales
                     ORDER BY total_sales DESC
                     LIMIT 5;

			
-- Q-10 Find customers who have purchased tracks from at least 3 different genres?
WITH CustomerGenreCount AS (
                                        SELECT c.customer_id,
                       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
                              COUNT(DISTINCT g.genre_id) AS genre_count
                                        FROM customer c
                                        JOIN invoice i 
                                            ON c.customer_id = i.customer_id
                                       JOIN invoice_line il 
                                           ON i.invoice_id = il.invoice_id
                                      JOIN track t 
                                           ON il.track_id = t.track_id
                                      JOIN genre g
                                           ON t.genre_id = g.genre_id
                                      GROUP BY c.customer_id, customer_name
)
                                    SELECT customer_id,
                                                 customer_name,
                                                 genre_count
                                  FROM CustomerGenreCount
                                  WHERE genre_count >= 3
                                  ORDER BY genre_count DESC, customer_id;
			
-- Q-11 Rank genres based on their sales performance in the USA?
WITH GenreSales AS (
                            SELECT g.name AS genre, 
                                       SUM(il.unit_price * il.quantity) AS total_sales
                           FROM invoice i
                          JOIN invoice_line il 
                             ON i.invoice_id = il.invoice_id
                          JOIN track t 
                             ON il.track_id = t.track_id
                          JOIN genre g
                            ON t.genre_id = g.genre_id
                        WHERE i.billing_country = 'USA'
                        GROUP BY g.name
)
                        SELECT genre, total_sales,
                                    RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
                        FROM GenreSales
                       ORDER BY total_sales DESC;
-- Q-12 Identify customers who have not made a purchase in the last 3 months?
WITH LastPurchase AS (
    SELECT customer_id,
           MAX(invoice_date) AS last_purchase_date
    FROM invoice
    GROUP BY customer_id
)
SELECT c.customer_id, 
       CONCAT(c.first_name, " ", c.last_name) AS customer_name, 
       lp.last_purchase_date
FROM customer c
LEFT JOIN LastPurchase lp 
    ON c.customer_id = lp.customer_id
WHERE lp.last_purchase_date < DATE_SUB(
    (SELECT MAX(invoice_date) FROM invoice), 
    INTERVAL 3 MONTH
)
ORDER BY customer_id ASC;

--                   --- SUBJECTIVE QUESTIONS ---

-- Q-1 Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis?
SELECT g.name AS genre_name,
                      a.title AS album_name,
                     SUM(il.unit_price * il.quantity) AS total_sales
           FROM invoice i
           JOIN invoice_line il 
               ON i.invoice_id = il.invoice_id
          JOIN track t 
              ON il.track_id = t.track_id
          JOIN album a 
               ON t.album_id = a.album_id
          JOIN genre g
              ON t.genre_id = g.genre_id
          WHERE i.billing_country = 'USA'
          GROUP BY g.name, a.title
          ORDER BY total_sales DESC
          LIMIT 3;

-- Q-2 Determine the top-selling genres in countries other than the USA and identify any commonalities or differences?

WITH Genre_Sales AS (
                                      SELECT c.country, 
                                                    g.name AS genre_name, 
                                                    SUM(il.unit_price * il.quantity) AS total_sales
                                      FROM invoice_line il
                                      JOIN track t 
                                           ON il.track_id = t.track_id
                                       JOIN genre g 
                                            ON t.genre_id = g.genre_id
                                       JOIN invoice i 
                                            ON il.invoice_id = i.invoice_id
                                      JOIN customer c 
                                            ON i.customer_id = c.customer_id
                                      WHERE c.country != 'USA'
                                      GROUP BY c.country, g.name
),
Ranked_Genres AS (
                                 SELECT country,
                                              genre_name, 
                                              total_sales,
                                              DENSE_RANK() OVER (PARTITION BY country 
                                               ORDER BY total_sales DESC) AS genre_rank
                                FROM Genre_Sales
)
                                SELECT country, 
                                              genre_name,
                                            total_sales
                            FROM Ranked_Genres
                            WHERE genre_rank = 1
                            ORDER BY total_sales DESC;

-- Q-3 Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies?
WITH CustomerCategory AS (
                                        SELECT customer_id,
                                                    MIN(invoice_date) AS first_purchase_date,
                                                   MAX(invoice_date) AS last_purchase_date,
                                        CASE
                                         WHEN 
                                    MIN(invoice_date) >= DATE_SUB((SELECT MAX(invoice_date) FROM invoice), INTERVAL 6 MONTH)
                                         THEN 'New Customer'
                                                   ELSE 'Long-Term Customer'
                                                            END AS customer_type
                                      FROM invoice
                                      GROUP BY customer_id
),
PurchaseStats AS (
                            SELECT i.customer_id, 
                                        COUNT(i.invoice_id) AS total_purchases,
                                        SUM(i.total) AS total_spent, AVG(i.total) AS avg_order_value,
                                        COUNT(il.track_id) / COUNT(i.invoice_id) AS avg_basket_size
                            FROM invoice i
                            JOIN invoice_line il 
                                ON i.invoice_id = il.invoice_id
                            GROUP BY i.customer_id
)
                          SELECT cc.customer_type, 
                                      ROUND(AVG(ps.total_purchases), 2) AS avg_purchases,
                                      ROUND(AVG(ps.total_spent), 2) AS avg_spent,
                                      ROUND(AVG(ps.avg_order_value), 2) AS avg_order_value,
                                      ROUND(AVG(ps.avg_basket_size), 2) AS avg_basket_size
                          FROM CustomerCategory cc
                          JOIN PurchaseStats ps 
                             ON cc.customer_id = ps.customer_id
                          GROUP BY cc.customer_type;
                          
-- Q-4 Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? How can this information guide product recommendations and cross-selling initiatives?
-- Find frequently purchased genre pairs
WITH GenrePairs AS (
                          SELECT t1.genre_id AS genre_1,
                                       t2.genre_id AS genre_2,
                                       COUNT(*) AS frequency
                           FROM invoice_line il1
                           JOIN invoice_line il2
                               ON il1.invoice_id = il2.invoice_id
                            AND il1.track_id <> il2.track_id
                        JOIN track t1 
                             ON il1.track_id = t1.track_id
                        JOIN track t2 
                            ON il2.track_id = t2.track_id
                        WHERE t1.genre_id < t2.genre_id   -- Avoids duplicate pairs
                        GROUP BY t1.genre_id, t2.genre_id
),
-- Find frequently purchased artist pairs (Corrected)
ArtistPairs AS (
                  SELECT al1.artist_id AS artist_1,
                               al2.artist_id AS artist_2,
                               COUNT(*) AS frequency
                  FROM invoice_line il1
                  JOIN invoice_line il2
                      ON il1.invoice_id = il2.invoice_id
                      AND il1.track_id <> il2.track_id
                  JOIN track t1 
                     ON il1.track_id = t1.track_id
                  JOIN track t2 
                     ON il2.track_id = t2.track_id
                  JOIN album al1 
                      ON t1.album_id = al1.album_id
                  JOIN album al2 
                      ON t2.album_id = al2.album_id
                  WHERE al1.artist_id < al2.artist_id -- Avoid duplicate pairs
                  GROUP BY al1.artist_id, al2.artist_id
),
-- Find frequently purchased album pairs
AlbumPairs AS (
                      SELECT t1.album_id AS album_1,
                                   t2.album_id AS album_2,
                                   COUNT(*) AS frequency
                      FROM invoice_line il1
                      JOIN invoice_line il2
                          ON il1.invoice_id = il2.invoice_id
                          AND il1.track_id <> il2.track_id
                      JOIN track t1 
                          ON il1.track_id = t1.track_id
                      JOIN track t2 
                           ON il2.track_id = t2.track_id
                      WHERE t1.album_id < t2.album_id
                      GROUP BY t1.album_id, t2.album_id
)
-- Final selection combining results
SELECT * FROM (
-- Top Genre Pairs
                    SELECT 'Genre' AS category, 
                                  g1.name AS item_1,
                                 g2.name AS item_2, 
                                  gp.frequency
                    FROM GenrePairs gp
                    JOIN genre g1 
                        ON gp.genre_1 = g1.genre_id
                     JOIN genre g2 
                         ON gp.genre_2 = g2.genre_id
                     ORDER BY gp.frequency DESC
                      LIMIT 5
) AS GenreResults
                      UNION ALL
 SELECT * FROM (
-- Top Artist Pairs
                       SELECT 'Artist' AS category,
                                     a1.name AS item_1,
                                     a2.name AS item_2,
                                     ap.frequency
                       FROM ArtistPairs ap
                       JOIN artist a1 
                           ON ap.artist_1 = a1.artist_id
                       JOIN artist a2 
                           ON ap.artist_2 = a2.artist_id
                       ORDER BY ap.frequency DESC
                        LIMIT 5
) AS ArtistResults
                      UNION ALL
SELECT * FROM (
-- Top Album Pairs
                         SELECT 'Album' AS category,
                                       al1.title AS item_1,
                                       al2.title AS item_2,
                                       ap.frequency
                        FROM AlbumPairs ap
                        JOIN album al1 
                            ON ap.album_1 = al1.album_id
                        JOIN album al2 
                            ON ap.album_2 = al2.album_id
                        ORDER BY ap.frequency DESC
                         LIMIT 5
) AS AlbumResults;

-- Q-5 Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors?


-- Q-6 Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk?
WITH customer_purchase_summary AS (
     SELECT 
        c.customer_id,
        c.country,
        COUNT(DISTINCT i.invoice_id) AS total_purchases,
        ROUND(SUM(il.unit_price * il.quantity), 2) AS total_spent,
        MAX(i.invoice_date) AS last_purchase
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY c.customer_id, c.country
),

latest_date AS (
    SELECT MAX(invoice_date) AS latest_invoice_date FROM invoice
)
SELECT 
    cps.customer_id,
    cps.country,
    cps.total_purchases,
    cps.total_spent,
    CASE 
        WHEN DATEDIFF(ld.latest_invoice_date, cps.last_purchase) > 180 THEN 'churned'
        ELSE 'active'
    END AS churn_status
FROM customer_purchase_summary cps
JOIN latest_date ld
ORDER BY churn_status DESC, total_spent DESC;

-- Q-7 Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments? This could inform targeted marketing and loyalty program strategies. 
-- Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?

WITH customer_summary AS (
    SELECT 
        c.customer_id,
        c.country,
        MIN(i.invoice_date) AS first_purchase,
        MAX(i.invoice_date) AS last_purchase,
        COUNT(DISTINCT i.invoice_id) AS total_purchases,
        ROUND(SUM(il.unit_price * il.quantity), 2) AS total_spent
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY c.customer_id, c.country
),

tenure_calc AS (
    SELECT 
        cs.*,
        TIMESTAMPDIFF(MONTH, cs.first_purchase, cs.last_purchase) AS tenure_months,
        ROUND(cs.total_spent / cs.total_purchases, 2) AS avg_order_value,
        ROUND(cs.total_purchases / NULLIF(TIMESTAMPDIFF(MONTH, cs.first_purchase, cs.last_purchase), 0), 2) AS purchase_frequency
    FROM customer_summary cs
),

ltv_calc AS (
    SELECT 
        *,
        ROUND(avg_order_value * purchase_frequency * tenure_months, 2) AS estimated_ltv
    FROM tenure_calc
),

latest_invoice AS (
    SELECT MAX(invoice_date) AS latest_date FROM invoice
),

final AS (
    SELECT 
        l.*,
        CASE 
            WHEN DATEDIFF(li.latest_date, l.last_purchase) > 180 THEN 'churned'
            ELSE 'active'
        END AS churn_status
    FROM ltv_calc l
    JOIN latest_invoice li
)

SELECT 
    customer_id,
    country,
    first_purchase,
    last_purchase,
    total_purchases,
    total_spent,
    tenure_months,
    avg_order_value,
    purchase_frequency,
    estimated_ltv,
    churn_status
FROM final
ORDER BY estimated_ltv DESC;

-- Q-10 How can you alter the "Albums" table to add a new column named "Release Year" of type INTEGER to store the release year of each album?
ALTER TABLE Album
ADD COLUMN ReleaseYear INTEGER;
DESC Album;

-- Q-11 Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. They want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer. 
-- Write an SQL query to provide this information?

WITH customer_totals AS (
    SELECT 
        i.customer_id,
        SUM(i.total) AS total_amount,
        SUM(il.quantity) AS total_tracks
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY i.customer_id
)
SELECT 
    c.country,
    COUNT(DISTINCT c.customer_id) AS number_of_customers,
    ROUND(AVG(ct.total_amount), 2) AS avg_amount_spent_per_customer,
    ROUND(AVG(ct.total_tracks), 2) AS avg_tracks_purchased_per_customer
FROM customer c
LEFT JOIN customer_totals ct ON c.customer_id = ct.customer_id
GROUP BY c.country
ORDER BY number_of_customers DESC;

