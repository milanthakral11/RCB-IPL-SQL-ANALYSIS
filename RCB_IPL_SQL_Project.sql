USE ipl;

-- =================================================
-- Objective Question 1
-- List the different types of columns in ball_by_ball
-- =================================================

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ball_by_ball'
AND TABLE_SCHEMA = 'ipl';


-- =================================================
-- Objective Question 2
-- Total runs scored by RCB in the first IPL season (including extras)
-- =================================================

SELECT
    t.Team_Name AS Team,
    s.Season_Year,
    SUM(b.Runs_Scored + IFNULL(e.Extra_Runs, 0)) AS Total_Runs
FROM Ball_by_Ball b
JOIN Matches m 
    ON b.Match_Id = m.Match_Id
JOIN Team t 
    ON b.Team_Batting = t.Team_Id
JOIN Season s 
    ON m.Season_Id = s.Season_Id
LEFT JOIN Extra_Runs e 
    ON b.Match_Id = e.Match_Id
   AND b.Over_Id = e.Over_Id
   AND b.Ball_Id = e.Ball_Id
   AND b.Innings_No = e.Innings_No
WHERE t.Team_Name LIKE '%Bangalore%'   -- filters RCB
  AND s.Season_Year = 2008             -- 1st IPL season
GROUP BY t.Team_Name, s.Season_Year;




-- =================================================
-- Objective Question 3
-- Number of players older than 25 during the 2014 season
-- =================================================

SELECT COUNT(*) AS Players_Above_25
FROM Player
WHERE TIMESTAMPDIFF(YEAR, DOB, '2014-04-01') > 25;



-- =================================================
-- Objective Question 4
-- Number of matches won by RCB in the 2013 season
-- =================================================

SELECT
    t.Team_Name AS Team,
    s.Season_Year,
    COUNT(*) AS Matches_Won
FROM Matches m
JOIN Team t
    ON m.Match_Winner = t.Team_Id
JOIN Season s
    ON m.Season_Id = s.Season_Id
WHERE t.Team_Name LIKE '%Bangalore%'
  AND s.Season_Year = 2013
GROUP BY t.Team_Name, s.Season_Year;



-- =================================================
-- Objective Question 5
-- Top 10 players by strike rate in the last 4 seasons
-- =================================================

SELECT
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) * 100.0 / COUNT(b.Ball_Id), 2) AS Strike_Rate
FROM Ball_by_Ball b
JOIN Matches m
    ON b.Match_Id = m.Match_Id
JOIN Season s
    ON m.Season_Id = s.Season_Id
JOIN Player p
    ON b.Striker = p.Player_Id
JOIN (
        SELECT Season_Year
        FROM Season
        ORDER BY Season_Year DESC
        LIMIT 4
     ) latest_seasons
    ON s.Season_Year = latest_seasons.Season_Year
GROUP BY p.Player_Name
HAVING COUNT(b.Ball_Id) > 20
ORDER BY Strike_Rate DESC
LIMIT 10;




-- =================================================
-- Objective Question 6
-- Average runs scored by each batsman across all seasons
-- =================================================

SELECT
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS Avg_Runs_Per_Match
FROM Ball_by_Ball b
JOIN Player p
    ON b.Striker = p.Player_Id
GROUP BY p.Player_Name
ORDER BY Avg_Runs_Per_Match DESC;



-- =================================================
-- Objective Question 7
-- Average wickets taken by each bowler across all seasons
-- =================================================

SELECT
    bowler.Player_Name,
    ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT w.Match_Id), 2) AS Avg_Wickets_Per_Match
FROM Wicket_Taken w
JOIN Ball_by_Ball b
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
JOIN Player bowler
    ON b.Bowler = bowler.Player_Id
WHERE w.Kind_Out IS NOT NULL
GROUP BY bowler.Player_Id, bowler.Player_Name
ORDER BY Avg_Wickets_Per_Match DESC;



-- =================================================
-- Objective Question 8
-- Players with above-average batting and bowling performance (All-rounders)
-- =================================================


WITH player_runs AS (
    SELECT
        Striker AS Player_Id,
        ROUND(SUM(Runs_Scored) / COUNT(DISTINCT Match_Id), 2) AS Avg_Runs_Per_Match
    FROM Ball_by_Ball
    GROUP BY Striker
),

player_wickets AS (
    SELECT
        b.Bowler AS Player_Id,
        ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT w.Match_Id), 2) AS Avg_Wickets_Per_Match
    FROM Wicket_Taken w
    JOIN Ball_by_Ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
       AND w.Innings_No = b.Innings_No
    WHERE w.Kind_Out IS NOT NULL
    GROUP BY b.Bowler
),

overall_avg AS (
    SELECT
        (SELECT AVG(Avg_Runs_Per_Match) FROM player_runs) AS Overall_Run_Avg,
        (SELECT AVG(Avg_Wickets_Per_Match) FROM player_wickets) AS Overall_Wicket_Avg
)

SELECT
    p.Player_Name,
    r.Avg_Runs_Per_Match,
    w.Avg_Wickets_Per_Match
FROM player_runs r
JOIN player_wickets w
    ON r.Player_Id = w.Player_Id
JOIN Player p
    ON p.Player_Id = r.Player_Id
JOIN overall_avg oa
WHERE r.Avg_Runs_Per_Match > oa.Overall_Run_Avg
  AND w.Avg_Wickets_Per_Match > oa.Overall_Wicket_Avg
ORDER BY
    r.Avg_Runs_Per_Match DESC,
    w.Avg_Wickets_Per_Match DESC;
    
    
    
-- =================================================
-- Objective Question 9
-- Create rcb_record table showing RCB wins and losses at each venue
-- =================================================

CREATE TABLE rcb_record (
    Venue_Name VARCHAR(255),
    Matches_Played INT,
    Wins INT,
    Losses INT
);

INSERT INTO rcb_record (Venue_Name, Matches_Played, Wins, Losses)
SELECT
    v.Venue_Name,
    COUNT(m.Match_Id) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = rcb.Team_Id THEN 1 ELSE 0 END) AS Wins,
    SUM(
        CASE
            WHEN (m.Team_1 = rcb.Team_Id OR m.Team_2 = rcb.Team_Id)
             AND m.Match_Winner <> rcb.Team_Id
            THEN 1
            ELSE 0
        END
    ) AS Losses
FROM Matches m
JOIN Venue v
    ON m.Venue_Id = v.Venue_Id
JOIN Team rcb
    ON rcb.Team_Name LIKE '%Bangalore%'
WHERE (m.Team_1 = rcb.Team_Id OR m.Team_2 = rcb.Team_Id)
GROUP BY v.Venue_Name;



-- =================================================
-- Objective Question 10
-- Impact of bowling style on wickets taken
-- =================================================

SELECT
    bs.Bowling_skill AS Bowling_Style,
    COUNT(w.Player_Out) AS Total_Wickets
FROM Wicket_Taken w
JOIN Ball_by_Ball b
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
JOIN Player p
    ON b.Bowler = p.Player_Id
JOIN Bowling_Style bs
    ON p.Bowling_skill = bs.Bowling_Id
WHERE w.Kind_Out IS NOT NULL
GROUP BY bs.Bowling_skill
ORDER BY Total_Wickets DESC;



-- =================================================
-- Objective Question 11
-- Compare team performance with previous season based on runs and wickets
-- =================================================

WITH team_runs AS (
    SELECT
        s.Season_Year,
        b.Team_Batting AS Team_Id,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM Ball_by_Ball b
    JOIN Matches m
        ON b.Match_Id = m.Match_Id
    JOIN Season s
        ON m.Season_Id = s.Season_Id
    GROUP BY s.Season_Year, b.Team_Batting
),

team_wickets AS (
    SELECT
        s.Season_Year,
        b.Team_Bowling AS Team_Id,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM Wicket_Taken w
    JOIN Ball_by_Ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
       AND w.Innings_No = b.Innings_No
    JOIN Matches m
        ON b.Match_Id = m.Match_Id
    JOIN Season s
        ON m.Season_Id = s.Season_Id
    WHERE w.Kind_Out IS NOT NULL
    GROUP BY s.Season_Year, b.Team_Bowling
),

team_performance AS (
    SELECT
        r.Season_Year,
        t.Team_Name,
        r.Total_Runs,
        COALESCE(w.Total_Wickets, 0) AS Total_Wickets
    FROM team_runs r
    JOIN Team t
        ON r.Team_Id = t.Team_Id
    LEFT JOIN team_wickets w
        ON r.Team_Id = w.Team_Id
       AND r.Season_Year = w.Season_Year
)

SELECT
    curr.Team_Name,
    curr.Season_Year,
    curr.Total_Runs,
    curr.Total_Wickets,
    prev.Total_Runs AS Prev_Runs,
    prev.Total_Wickets AS Prev_Wickets,
    CASE
        WHEN curr.Total_Runs > prev.Total_Runs
         AND curr.Total_Wickets > prev.Total_Wickets THEN 'Improved'
        WHEN curr.Total_Runs = prev.Total_Runs
         AND curr.Total_Wickets = prev.Total_Wickets THEN 'Same'
        ELSE 'Declined'
    END AS Performance_Status
FROM team_performance curr
LEFT JOIN team_performance prev
    ON curr.Team_Name = prev.Team_Name
   AND curr.Season_Year = prev.Season_Year + 1
ORDER BY curr.Team_Name, curr.Season_Year;



-- =================================================
-- Objective Question 12
-- Derived KPIs for Team Strategy
-- =================================================


-- KPI 1: Batting Strike Rate (Top 10 Players)
SELECT
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) * 100.0 / COUNT(b.Ball_Id), 2) AS Strike_Rate
FROM Ball_by_Ball b
JOIN Player p
    ON b.Striker = p.Player_Id
GROUP BY p.Player_Name
ORDER BY Strike_Rate DESC
LIMIT 10;


-- KPI 2: Bowling Economy Rate (Top 10 Bowlers)
SELECT
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) / (COUNT(b.Ball_Id) / 6), 2) AS Economy_Rate
FROM Ball_by_Ball b
JOIN Player p
    ON b.Bowler = p.Player_Id
GROUP BY p.Player_Name
HAVING COUNT(b.Ball_Id) > 30
ORDER BY Economy_Rate ASC
LIMIT 10;


-- KPI 3: Win Percentage by Venue (RCB)
SELECT
    v.Venue_Name,
    COUNT(m.Match_Id) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100.0
        / COUNT(m.Match_Id),
        2
    ) AS Win_Percentage
FROM Matches m
JOIN Venue v
    ON m.Venue_Id = v.Venue_Id
JOIN Team t
    ON t.Team_Name LIKE '%Bangalore%'
WHERE (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id)
GROUP BY v.Venue_Name
ORDER BY Win_Percentage DESC;


-- KPI 4: Average Runs per Wicket (Batting Efficiency)
SELECT
    t.Team_Name,
    ROUND(SUM(b.Runs_Scored) / COUNT(w.Player_Out), 2) AS Avg_Runs_Per_Wicket
FROM Ball_by_Ball b
JOIN Matches m
    ON b.Match_Id = m.Match_Id
JOIN Team t
    ON b.Team_Batting = t.Team_Id
LEFT JOIN Wicket_Taken w
    ON b.Match_Id = w.Match_Id
   AND b.Innings_No = w.Innings_No
   AND w.Kind_Out IS NOT NULL
GROUP BY t.Team_Name
ORDER BY Avg_Runs_Per_Wicket DESC;


-- KPI 5: Boundary Percentage (Aggression Index)
SELECT
    p.Player_Name,
    SUM(CASE WHEN b.Runs_Scored = 4 THEN 1 ELSE 0 END) AS Fours,
    SUM(CASE WHEN b.Runs_Scored = 6 THEN 1 ELSE 0 END) AS Sixes,
    SUM(b.Runs_Scored) AS Total_Runs,
    ROUND(
        (
            SUM(CASE WHEN b.Runs_Scored = 4 THEN 4 ELSE 0 END) +
            SUM(CASE WHEN b.Runs_Scored = 6 THEN 6 ELSE 0 END)
        ) / SUM(b.Runs_Scored) * 100,
        2
    ) AS Boundary_Percentage
FROM Ball_by_Ball b
JOIN Player p
    ON b.Striker = p.Player_Id
GROUP BY p.Player_Name
HAVING SUM(b.Runs_Scored) > 100
ORDER BY Boundary_Percentage DESC
LIMIT 10;



-- =================================================
-- Objective Question 13
-- Average wickets taken by each bowler at each venue
-- Rank bowlers by average wickets within each venue
-- =================================================

SELECT
    p.Player_Name AS Bowler,
    v.Venue_Name,
    ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Wickets_Per_Match,
    DENSE_RANK() OVER (
        PARTITION BY v.Venue_Name
        ORDER BY COUNT(w.Player_Out) / COUNT(DISTINCT m.Match_Id) DESC
    ) AS Rank_By_Venue
FROM Wicket_Taken w
JOIN Ball_by_Ball b
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
JOIN Matches m
    ON b.Match_Id = m.Match_Id
JOIN Venue v
    ON m.Venue_Id = v.Venue_Id
JOIN Player p
    ON b.Bowler = p.Player_Id
WHERE w.Kind_Out IS NOT NULL
GROUP BY p.Player_Name, v.Venue_Name
ORDER BY v.Venue_Name, Avg_Wickets_Per_Match DESC;



-- =================================================
-- Objective Question 14
-- Players who have consistently performed well in past seasons
-- =================================================

SELECT
    p.Player_Name AS Bowler,
    ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Wickets_Per_Match,
    DENSE_RANK() OVER (
        ORDER BY COUNT(w.Player_Out) / COUNT(DISTINCT m.Match_Id) DESC
    ) AS Overall_Rank
FROM Wicket_Taken w
JOIN Ball_by_Ball b
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
JOIN Matches m
    ON b.Match_Id = m.Match_Id
JOIN Player p
    ON b.Bowler = p.Player_Id
WHERE w.Kind_Out IS NOT NULL
GROUP BY p.Player_Name
HAVING COUNT(DISTINCT m.Match_Id) > 10
ORDER BY Avg_Wickets_Per_Match DESC
LIMIT 5;



-- =================================================
-- Objective Question 15
-- Identify players whose performance is better suited to specific venues
-- =================================================

SELECT 
    p.Player_Name,
    v.Venue_Name,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Runs_Per_Match
FROM Ball_by_Ball b
JOIN Matches m
    ON b.Match_Id = m.Match_Id
JOIN Venue v
    ON m.Venue_Id = v.Venue_Id
JOIN Player p
    ON b.Striker = p.Player_Id
GROUP BY p.Player_Name, v.Venue_Name
HAVING COUNT(DISTINCT m.Match_Id) >= 3   -- minimum matches to avoid bias
ORDER BY Avg_Runs_Per_Match DESC;



-- =================================================
-- Subjective Question 1
-- Impact of toss decision on match outcome
-- =================================================

SELECT
    t.Toss_Name AS Toss_Decision,
    COUNT(*) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END) AS Wins_After_Toss,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END)
        / COUNT(*) * 100,
        2
    ) AS Win_Percentage
FROM Matches m
JOIN Toss_Decision t
    ON m.Toss_Decide = t.Toss_Id
GROUP BY t.Toss_Name;

-- =================================================
-- Subjective Question 2
-- Consistent batting performance (average runs per match)
-- =================================================


SELECT
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS Avg_Runs_Per_Match
FROM Ball_by_Ball b
JOIN Player p
    ON b.Striker = p.Player_Id
GROUP BY p.Player_Name
HAVING COUNT(DISTINCT b.Match_Id) > 20
ORDER BY Avg_Runs_Per_Match DESC;


-- All-round contribution (batting + bowling)

SELECT
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS Avg_Runs,
    ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT w.Match_Id), 2) AS Avg_Wickets
FROM Player p
LEFT JOIN Ball_by_Ball b
    ON p.Player_Id = b.Striker
LEFT JOIN Wicket_Taken w
    ON p.Player_Id = w.Player_Out
GROUP BY p.Player_Name
ORDER BY Avg_Runs DESC, Avg_Wickets DESC;


-- =================================================
-- Subjective Question 3
-- Consistency of performance: Average runs per match
-- =================================================

SELECT
p.Player_Name,
ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS Avg_Runs_Per_Match
FROM Ball_by_Ball b
JOIN Player p
ON b.Striker = p.Player_Id
GROUP BY p.Player_Name
HAVING COUNT(DISTINCT b.Match_Id) > 20
ORDER BY Avg_Runs_Per_Match DESC;


-- Bowling effectiveness: Average wickets per match


SELECT
    p.Player_Name,
    ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Wickets_Per_Match
FROM Wicket_Taken w
JOIN Ball_by_Ball b
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
JOIN Matches m
    ON b.Match_Id = m.Match_Id
JOIN Player p
    ON b.Bowler = p.Player_Id
WHERE w.Kind_Out IS NOT NULL
GROUP BY p.Player_Name
HAVING COUNT(DISTINCT m.Match_Id) > 15
ORDER BY Avg_Wickets_Per_Match DESC;




-- =================================================
-- Subjective Question 4
-- Identification of Versatile All-Round Players Based on Batting and Bowling Performance
-- =================================================

 -- Batting contribution
 SELECT
p.Player_Name,
AVG(b.Runs_Scored) AS Avg_Runs
FROM ball_by_ball b
JOIN player p ON b.Striker = p.Player_Id
GROUP BY p.Player_Name;

 -- Bowling Contribution
 SELECT
p.Player_Name,
COUNT(w.Player_Out) / COUNT(DISTINCT w.Match_Id) AS Avg_Wickets
FROM wicket_taken w
JOIN ball_by_ball b
ON w.Match_Id = b.Match_Id
AND w.Over_Id = b.Over_Id
AND w.Ball_Id = b.Ball_Id
AND w.Innings_No = b.Innings_No
JOIN player p
ON b.Bowler = p.Player_Id
GROUP BY p.Player_Name;


-- =================================================
-- Subjective Question 5
-- =================================================


SELECT
p.Player_Name,
COUNT(pm.Match_Id) AS Matches_Played,
SUM(CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END) AS Matches_Won,
ROUND(
SUM(CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END) * 100.0
/ COUNT(pm.Match_Id),
2
) AS Team_Win_Percentage
FROM Player_Match pm
JOIN Player p
ON pm.Player_Id = p.Player_Id
JOIN Matches m
ON pm.Match_Id = m.Match_Id
WHERE p.Player_Name IN (
'RG Sharma',
'MS Dhoni',
'AB de Villiers',
'V Kohli'
)
GROUP BY p.Player_Name
ORDER BY Team_Win_Percentage DESC;


-- =================================================
-- Subjective Question 6
-- RCB bowling effectiveness: Average wickets per match
-- =================================================

SELECT
    p.Player_Name,
    ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Wickets_Per_Match
FROM Wicket_Taken w
JOIN Ball_by_Ball b
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
JOIN Matches m
    ON b.Match_Id = m.Match_Id
JOIN Player p
    ON b.Bowler = p.Player_Id
JOIN Team t
    ON p.Team_Id = t.Team_Id
WHERE t.Team_Name LIKE '%Bangalore%'
GROUP BY p.Player_Name
ORDER BY Avg_Wickets_Per_Match DESC;


-- Middle-order batting consistency for RCB


SELECT
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS Avg_Runs_Per_Match
FROM Ball_by_Ball b
JOIN Player p
    ON b.Striker = p.Player_Id
WHERE b.Team_Batting = 2      -- RCB batting
GROUP BY p.Player_Name
HAVING COUNT(DISTINCT b.Match_Id) > 20
ORDER BY Avg_Runs_Per_Match DESC;


-- =================================================
-- Subjective Question 8
-- Impact of home-ground advantage on RCB performance
-- =================================================

SELECT
    CASE
        WHEN m.Venue_Id = 1 THEN 'Home'
        ELSE 'Away'
    END AS Match_Type,
    COUNT(*) AS Matches_Played,
    SUM(
        CASE
            WHEN m.Match_Winner = 2 THEN 1
            ELSE 0
        END
    ) AS Matches_Won,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS Win_Percentage
FROM Matches m
WHERE m.Team_1 = 2
   OR m.Team_2 = 2
GROUP BY Match_Type;



-- =================================================
-- Subjective Question 9
-- Visual and analytical analysis of RCB's past seasons performance
-- =================================================


-- Visual 1: Season-wise Performance Trend of RCB
SELECT
    s.Season_Year,
    COUNT(*) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS Matches_Won,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS Win_Percentage
FROM Matches m
JOIN Season s
    ON m.Season_Id = s.Season_Id
WHERE m.Team_1 = 2
   OR m.Team_2 = 2
GROUP BY s.Season_Year
ORDER BY s.Season_Year;


-- Visual 2: Home vs Away Dependency Analysis
SELECT
    CASE
        WHEN m.Venue_Id = 1 THEN 'Home'
        ELSE 'Away'
    END AS Match_Type,
    COUNT(*) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS Matches_Won,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS Win_Percentage
FROM Matches m
WHERE m.Team_1 = 2
   OR m.Team_2 = 2
GROUP BY Match_Type;


-- Visual 3: Batting Strength vs Bowling Effectiveness
SELECT
    s.Season_Year,
    SUM(bb.Runs_Scored) AS Total_Runs_Scored,
    COUNT(w.Match_Id) AS Total_Wickets_Taken
FROM Matches m
JOIN Season s
    ON m.Season_Id = s.Season_Id
JOIN Ball_by_Ball bb
    ON m.Match_Id = bb.Match_Id
LEFT JOIN Wicket_Taken w
    ON bb.Match_Id = w.Match_Id
   AND bb.Innings_No = w.Innings_No
   AND bb.Over_Id = w.Over_Id
   AND bb.Ball_Id = w.Ball_Id
WHERE bb.Team_Batting = 2
   OR bb.Team_Bowling = 2
GROUP BY s.Season_Year
ORDER BY s.Season_Year;


-- =================================================
-- Subjective Question 10
-- Number of matches per season
-- =================================================

SELECT
    s.Season_Year,
    COUNT(m.Match_Id) AS Matches_Played
FROM Matches m
JOIN Season s
    ON m.Season_Id = s.Season_Id
GROUP BY s.Season_Year
ORDER BY s.Season_Year;


-- Average runs per match across seasons


SELECT
    s.Season_Year,
    ROUND(AVG(team_runs.Total_Runs), 2) AS Avg_Runs_Per_Match
FROM Season s
JOIN Matches m
    ON s.Season_Id = m.Season_Id
JOIN (
    SELECT
        Match_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM Ball_by_Ball
    GROUP BY Match_Id
) team_runs
    ON m.Match_Id = team_runs.Match_Id
GROUP BY s.Season_Year
ORDER BY s.Season_Year;


-- Team-wise win percentage

SELECT
    t.Team_Name,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100.0
        / COUNT(m.Match_Id),
        2
    ) AS Win_Percentage
FROM Matches m
JOIN Team t
    ON t.Team_Id IN (m.Team_1, m.Team_2)
GROUP BY t.Team_Name
ORDER BY Win_Percentage DESC;


-- =================================================
-- Subjective Question 11
-- =================================================


UPDATE matches
SET Opponent_Team = 'Delhi_Daredevils'
WHERE Opponent_Team = 'Delhi_Capitals';














