-- Count of sent, opened, and visited email messages by date and country
WITH email_metrics AS (
    SELECT
        DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS date,
        sp.country,
        COUNT(distinct es.id_message) AS sent_msg,
        COUNT( distinct eo.id_message) AS open_msg,
        COUNT(distinct ev.id_message) AS visit_msg
    FROM `data-analytics-mate.DA.email_sent` es
    LEFT JOIN `data-analytics-mate.DA.email_open` eo ON es.id_message = eo.id_message
    LEFT JOIN `data-analytics-mate.DA.email_visit` ev ON es.id_message = ev.id_message
    LEFT JOIN `data-analytics-mate.DA.account_session` acs ON es.id_account = acs.account_id
    JOIN `data-analytics-mate.DA.session` s ON acs.ga_session_id = s.ga_session_id
    JOIN `data-analytics-mate.DA.session_params` sp ON sp.ga_session_id = s.ga_session_id
    GROUP BY 1, 2
),

- Retrieve account metrics: count, send interval, verification, unsubscription
account_metrics AS (
    SELECT
        s.date,
        sp.country,
        a.send_interval,
        a.is_verified,
        a.is_unsubscribed,
        COUNT(distinct acs.account_id) AS account_cnt
    FROM `data-analytics-mate.DA.account` a
    JOIN `data-analytics-mate.DA.account_session` acs ON a.id = acs.account_id
    JOIN `data-analytics-mate.DA.session` s ON acs.ga_session_id = s.ga_session_id
    JOIN `data-analytics-mate.DA.session_params` sp ON acs.ga_session_id = sp.ga_session_id
    GROUP BY 1, 2, 3, 4, 5
),

-- Combine account and email event metrics using UNION ALL
total_country_counts AS (
    -- Account metrics
        SELECT
            date,
            country,
            send_interval,
            is_verified,
            is_unsubscribed,
            account_cnt,
            null AS sent_msg,
            null AS open_msg,
            null AS visit_msg
        FROM account_metrics
       
        UNION ALL

       -- Email event data
        SELECT
            date,
            country,
            null AS send_interval,
            null AS is_verified,
            null AS is_unsubscribed,
            null AS account_cnt,
            sent_msg,
            open_msg,
            visit_msg
        FROM email_metrics),

-- Add total account and email counts per country to the combined metrics
total_cnt AS
(SELECT *,
    SUM(account_cnt) OVER (partition by country) AS total_country_account_cnt,
    SUM(sent_msg) OVER (partition by country) AS total_country_sent_cnt
FROM total_country_counts),

-- Add ranking based on the previously calculated totals per country
rank_total AS
(SELECT *,
        DENSE_RANK() OVER (ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt,
        DENSE_RANK() OVER (ORDER BY total_country_sent_cnt DESC) AS rank_total_country_sent_cnt
FROM total_cnt)
-- Return the final result filtered by top 10 countries by account or email count
SELECT *
FROM rank_total
WHERE rank_total_country_account_cnt <= 10 OR rank_total_country_sent_cnt <= 10
order by  rank_total_country_sent_cnt, rank_total_country_sent_cnt
