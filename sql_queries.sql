/*  Проект: анализ данных для агенства недвижимости
    Автор: Шамсуллин Радмир Ильшатович
	Дата: 28.06.2025
*/

--Решаем ad hoc задачи

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);

--Задача 1. Время активности объявлений
--Вопрос 1.
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT
	CASE
		WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
		ELSE 'Ленинградская область'
	END AS region,
	c.city,
	MIN(a.days_exposition),
	MAX(a.days_exposition)
FROM real_estate.advertisement a 
JOIN real_estate.flats f ON a.id = f.id 
JOIN real_estate.city c ON f.city_id = c.city_id 
JOIN real_estate.type t ON f.type_id = t.type_id
WHERE f.id IN (SELECT * FROM filtered_id) AND a.days_exposition IS NOT NULL AND (c.city = 'Санкт-Петербург' OR t.type = 'город')
GROUP BY region, city
ORDER BY min, max

--Задача 1. Время активности объявлений
--Вопрос 2, 3.
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
category AS (
	SELECT
		a.id,
		a.days_exposition,
		c.city,
		CASE
			WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
			ELSE 'Ленинградская область'
		END AS region,
		CASE
			WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
			WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'до трех месяцев'
			WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
			ELSE 'более полугода'
		END AS activity_category,
		a.last_price / f.total_area AS price_sqmeter,
		f.total_area,
		f.rooms,
		f.balcony,
		f.floor,
		f.ceiling_height
	FROM real_estate.advertisement a 
	JOIN real_estate.flats f ON a.id = f.id 
	JOIN real_estate.city c ON f.city_id = c.city_id 
	JOIN real_estate.type t ON f.type_id = t.type_id
	WHERE a.days_exposition IS NOT NULL AND (c.city = 'Санкт-Петербург' OR t.type = 'город')
)
SELECT
	region,
	activity_category,
	COUNT(id) AS adv_qty,
	ROUND(AVG(price_sqmeter)::numeric, 2) AS avg_sqmeter_price,
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor
FROM category
WHERE id IN (SELECT * FROM filtered_id)
GROUP BY region, activity_category
ORDER BY region DESC;


--Задача 2. Сезонность объявлений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
 monthly_activity AS (
	SELECT
		DATE_PART('month', first_day_exposition) AS publication_month,
		COUNT(a.id) AS adv_published,
		CASE
			WHEN days_exposition IS NOT NULL THEN DATE_PART('month', first_day_exposition + days_exposition::integer)
			ELSE NULL
		END AS removal_month,
		COUNT(a.id) FILTER (WHERE days_exposition IS NOT NULL) AS adv_removed,
		AVG(a.last_price / NULLIF(f.total_area, 0)) FILTER (WHERE a.id IN (SELECT * FROM filtered_id)) AS avg_price_per_sqm,
		AVG(f.total_area) FILTER (WHERE a.id IN (SELECT * FROM filtered_id)) AS avg_total_area
	FROM real_estate.advertisement a 
	JOIN real_estate.flats f ON a.id = f.id
	JOIN real_estate.city c ON f.city_id = c.city_id
	JOIN real_estate.type t ON f.type_id = t.type_id
	WHERE c.city = 'Санкт-Петербург' OR t.type = 'город' AND (DATE_PART('year', first_day_exposition) >= 2015 AND DATE_PART('year', first_day_exposition) <= 2018) --Добавил фильтр на города и года
	GROUP BY publication_month, removal_month 
),
publish_stats AS (
	SELECT	
		publication_month,
		SUM(adv_published) AS adv_published,
		RANK() OVER (ORDER BY SUM(adv_published) DESC) AS publish_rank,
		AVG(avg_price_per_sqm) AS avg_price_per_sqm,
        AVG(avg_total_area) AS avg_square
	FROM monthly_activity
	GROUP BY publication_month
),
removed_stats AS (
	SELECT	
		removal_month,
		SUM(adv_removed) AS adv_removed,
		RANK() OVER (ORDER BY SUM(adv_removed) DESC) AS removed_rank
	FROM monthly_activity
	WHERE removal_month IS NOT NULL
	GROUP BY removal_month
)
-- Выведем объявления без выбросов:
SELECT
	CASE p.publication_month
		WHEN 1 THEN 'Январь'
	    WHEN 2 THEN 'Февраль'
	    WHEN 3 THEN 'Март'
	    WHEN 4 THEN 'Апрель'
	    WHEN 5 THEN 'Май'
	    WHEN 6 THEN 'Июнь'
	    WHEN 7 THEN 'Июль'
	    WHEN 8 THEN 'Август'
	    WHEN 9 THEN 'Сентябрь'
	    WHEN 10 THEN 'Октябрь'
	    WHEN 11 THEN 'Ноябрь'
	    WHEN 12 THEN 'Декабрь'
	END AS month_name,
	p.adv_published,
	p.publish_rank,
	r.adv_removed,
	r.removed_rank,
	ROUND(p.avg_price_per_sqm::numeric, 2) AS avg_price_per_sqm,
    ROUND(p.avg_square::numeric, 2) AS avg_square,
	 CASE 
        WHEN p.publish_rank <= 3 THEN 'ТОП-3 публикации'
        WHEN p.publish_rank >= 10 THEN 'Наименьшая публикация'
        ELSE 'Средняя активность'
    END AS publication_category,
    CASE 
        WHEN r.removed_rank <= 3 THEN 'ТОП-3 продаж'
        WHEN r.removed_rank >= 10 THEN 'Наименьшие продажи'
        ELSE 'Средняя активность'
    END AS removal_category,
    ABS(p.publish_rank - r.removed_rank) AS rank_difference
FROM publish_stats p
JOIN removed_stats r ON p.publication_month = r.removal_month

--Задача 3. Анализ рынка недвижимости Ленобласти
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_high,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_low
    FROM real_estate.flats     
),
-- Фильтруем квартиры по этим лимитам, чтобы убрать выбросы и аномалии
filtered_flats AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_high FROM limits)
              AND ceiling_height > (SELECT ceiling_height_limit_low FROM limits)) OR ceiling_height IS NULL)
),
filtered_advs AS (
    SELECT
        a.id,
        c.city,
        a.days_exposition,
        a.first_day_exposition,
        a.last_price,
        f.total_area,
        f.rooms,
        f.balcony
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    WHERE c.city <> 'Санкт-Петербург' AND c.city IS NOT NULL AND a.id IN (SELECT id FROM filtered_flats)
),
stats_by_city AS (
	SELECT
		city,
		COUNT(*) AS adv_qty,
        COUNT(*) FILTER (WHERE days_exposition IS NOT NULL) AS sold_adv_qty,
        ROUND(AVG(last_price / NULLIF(total_area, 0))::numeric, 2) AS avg_price_sqm,
        ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
        ROUND(AVG(days_exposition) FILTER (WHERE days_exposition IS NOT NULL)::numeric, 2) AS avg_days_exposition
    FROM filtered_advs
    GROUP BY city
)
SELECT 
	city,
	adv_qty,
	sold_adv_qty,
	ROUND(sold_adv_qty * 100.0 / adv_qty, 2) || '%'AS sold_percent,
	avg_price_sqm,
	avg_total_area,
	avg_days_exposition,
	NTILE(3) OVER (ORDER BY (sold_adv_qty * 100.0 / adv_qty) DESC) AS group
FROM stats_by_city
WHERE adv_qty >= 50 -- фильтрация для выявления общих трендов, сохраняет достаточный объём данных
ORDER BY sold_percent DESC 