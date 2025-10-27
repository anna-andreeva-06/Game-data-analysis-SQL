/* Проект «Тайны Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Андреева Анна Алексеевна
 * Дата: 29.09.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным: 
SELECT 
    COUNT(*) AS total_players,              -- Подсчет общего количества уникальных игроков
    SUM(CASE WHEN payer IN (0, 1) THEN payer ELSE 0 END) AS paying_players,  -- Сумма валидных значений payer (1 — платящий)
    ROUND((SUM(CASE WHEN payer IN (0, 1) THEN payer ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS paying_percentage -- Доля платящих пользователей в процентах
FROM (
    SELECT id, 
           CASE WHEN payer IN (0, 1) THEN payer ELSE 0 END AS payer
    FROM fantasy.users
    GROUP BY id, payer
    HAVING COUNT(*) = 1  -- Фильтрация только уникальных записей по id
) AS unique_validated_users;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа: 
SELECT 
    r.race,                                 -- Раса
    SUM(CASE WHEN u.payer IN (0, 1) THEN u.payer ELSE 0 END) AS paying_players,  -- Количество платящих игроков для данной расы
    COUNT(*) AS total_players_by_race,      -- Общее количество игроков данной расы
    ROUND((SUM(CASE WHEN u.payer IN (0, 1) THEN u.payer ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS paying_percentage -- Доля платящих пользователей в разрезе расы в процентах
FROM (
    SELECT id, race_id, 
           CASE WHEN payer IN (0, 1) THEN payer ELSE 0 END AS payer
    FROM fantasy.users
    GROUP BY id, race_id, payer
    HAVING COUNT(*) = 1  -- Фильтрация только уникальных записей по id
) AS u
JOIN fantasy.race AS r ON u.race_id = r.race_id            
GROUP BY r.race                        
ORDER BY paying_percentage DESC;        -- Сортировка по убыванию доли платящих



-- Задача 2. Исследование внутриигровых покупок

-- 2.1. Статистические показатели по полю amount:
-- Сравнение всех покупок и покупок без нулевых значений. 
SELECT 
    'All Purchases' AS category,    -- Все покупки
    COUNT(amount) AS total_amount,  -- Общее количество покупок
    SUM(amount) AS total_sum,       -- Суммарная стоимость всех покупок
    MIN(amount) AS min_amount,      -- Минимальная стоимость покупки
    MAX(amount) AS max_amount,      -- Максимальная стоимость покупки
    AVG(amount) AS avg_amount,      -- Среднее значение стоимости покупки
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ROUND(amount::NUMERIC, 2)) AS median_amount,  -- Медиана стоимости покупки
    STDDEV(amount) AS stddev_amount  -- Стандартное отклонение стоимости покупки
FROM fantasy.events
UNION
SELECT 
    'No zero purchases' AS category, -- без нулевых покупок
    COUNT(amount) AS total_amount,  -- Общее количество покупок
    SUM(amount) AS total_sum,       -- Суммарная стоимость всех покупок
    MIN(amount) AS min_amount,      -- Минимальная стоимость покупки
    MAX(amount) AS max_amount,      -- Максимальная стоимость покупки
    AVG(amount) AS avg_amount,      -- Среднее значение стоимости покупки
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ROUND(amount::NUMERIC, 2)) AS median_amount,  -- Медиана стоимости покупки
    STDDEV(amount) AS stddev_amount  -- Стандартное отклонение стоимости покупки
FROM fantasy.events
WHERE amount > 0;


-- 2.2: Аномальные нулевые покупки:
SELECT 
    SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END) AS zero_cost_count,  -- Абсолютное количество покупок с amount = 0
    ROUND((SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS zero_cost_percentage  -- Доля таких покупок от общего числа в процентах
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
WITH filtered_events AS (
    SELECT * 
    FROM fantasy.events 
    WHERE amount > 0  -- Фильтрация покупок с положительной стоимостью
),
totals AS (
    SELECT 
        COUNT(*) AS total_sales,  -- Общее количество продаж (после фильтрации)
        COUNT(DISTINCT id) AS total_unique_buyers  -- Общее количество уникальных покупателей
    FROM filtered_events
)
SELECT 
    fe.item_code,
    i.game_items AS item_name,  
    COUNT(*) AS sales_count,  -- Rоличество продаж предмета
    ROUND((COUNT(*)::NUMERIC / t.total_sales) * 100, 2) AS sales_share_percentage,  -- Доля продаж предмета от всех продаж в процентах
    COUNT(DISTINCT fe.id) AS unique_buyers,  -- Количество уникальных игроков, купивших предмет хотя бы раз
    ROUND((COUNT(DISTINCT fe.id)::NUMERIC / t.total_unique_buyers) * 100, 2) AS buyer_share_percentage  -- Доля таких игроков от общего числа покупателей в процентах
FROM filtered_events AS fe  
JOIN fantasy.items AS i ON fe.item_code = i.item_code  
CROSS JOIN totals AS t  
GROUP BY fe.item_code, i.game_items, t.total_sales, t.total_unique_buyers  
ORDER BY buyer_share_percentage DESC;  




-- Часть 2. Решение ad hoc-задач
-- Задача: Зависимость активности игроков от расы персонажа

-- Общее количество зарегистрированных игроков по расе
WITH total_users_by_race AS (
    SELECT 
        u.race_id,
        r.race AS race_name,  
        COUNT(u.id) AS total_players  -- Общее количество игроков этой расы
    FROM fantasy.users AS u
    JOIN fantasy.race AS r ON u.race_id = r.race_id  
    GROUP BY u.race_id, r.race  
),
-- Количество игроков, совершивших покупки (amount > 0), и доля платящих среди них по расе
buyers_by_race AS (
    SELECT 
        u.race_id,
        r.race AS race_name, 
        COUNT(DISTINCT u.id) AS buyers_count,  -- Количество уникальных игроков, совершивших покупки
        ROUND((COUNT(DISTINCT u.id)::NUMERIC / tur.total_players) * 100, 2) AS buyers_percentage,  -- Доля покупателей от общего количества игроков расы
        ROUND((COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END)::NUMERIC / COUNT(DISTINCT u.id)) * 100, 2) AS paying_buyers_percentage  -- Доля платящих (payer=1) среди покупателей
    FROM fantasy.users AS u
    JOIN fantasy.race AS r ON u.race_id = r.race_id  
    JOIN fantasy.events AS e ON u.id = e.id  
    JOIN total_users_by_race AS tur ON u.race_id = tur.race_id  
    WHERE e.amount > 0  -- Фильтрация покупок с положительной стоимостью
    GROUP BY u.race_id, r.race, tur.total_players
),

-- Активность по покупкам на уровне игроков 
user_purchases AS (
    SELECT 
        r.race AS race_name,  
        u.id AS user_id,  -- ID игрока для группировки
        COUNT(e.transaction_id) AS num_purchases,  -- Количество покупок на игрока
        AVG(e.amount) AS avg_purchase_cost,  -- Средняя стоимость одной покупки на игрока
        SUM(e.amount) AS total_spent  -- Суммарная стоимость всех покупок на игрока
    FROM fantasy.users AS u
    JOIN fantasy.race AS r ON u.race_id = r.race_id  
    JOIN fantasy.events AS e ON u.id = e.id  
    WHERE e.amount > 0  
    GROUP BY r.race, u.id  
),

-- Агрегация метрик активности по расе (средние по игрокам, совершившим покупки)
avg_purchases_by_race AS (
    SELECT 
        race_name,  
        ROUND(AVG(num_purchases)::NUMERIC, 3) AS avg_num_purchases,  -- Среднее количество покупок на покупателя
        ROUND((SUM(total_spent)::NUMERIC / SUM(num_purchases)), 3) AS avg_cost_per_purchase,  -- Средняя стоимость одной покупки на покупателя
        ROUND(AVG(total_spent)::NUMERIC, 3) AS avg_total_spent  -- Средняя суммарная стоимость на покупателя
    FROM user_purchases
    GROUP BY race_name 
)
-- Итоговый запрос: Объединение всех метрик
SELECT 
    tur.race_name,  -- Раса персонажа
    tur.total_players,  -- Общее количество зарегистрированных игроков
    br.buyers_count,  -- Количество игроков, совершивших покупки
    br.buyers_percentage,  -- Доля таких игроков от общего количества
    br.paying_buyers_percentage,  -- Доля платящих среди покупателей
    apr.avg_num_purchases,  -- Среднее количество покупок на покупателя
    apr.avg_cost_per_purchase,  -- Средняя стоимость одной покупки
    apr.avg_total_spent  -- Средняя суммарная стоимость на покупателя
FROM total_users_by_race AS tur
LEFT JOIN buyers_by_race AS br ON tur.race_id = br.race_id  -- LEFT JOIN для включения рас без покупок
LEFT JOIN avg_purchases_by_race AS apr ON tur.race_name = apr.race_name  
ORDER BY tur.race_name;
