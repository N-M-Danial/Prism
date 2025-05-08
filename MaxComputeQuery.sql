select t2.address as address, 
t2.equipment_id as eq_id,
t2.camera_id as camera_id,
t1.date_q as day,
concat(
            case when t1.hour_q == 0 then 12 
            when t1.hour_q > 12 then floor(t1.hour_q-12) 
            else t1.hour_q end, 
            case when t1.hour_q >= 12 then ':00 PM' else ':00 AM' end) as hour_s,
        -- CAST(t1.min_q/5 as BIGINT)+1 as min_q2,
t1.agg_zone as lane,
t1.vehicle_type as vehicle_type,
CAST(SUM(t1.volume) as BIGINT) as combined_avg_volume,
SUM(NULLIF(t1.cam_avg_speed*t1.volume, 0))/SUM(case when t1.cam_avg_speed >= 0 then t1.volume else 0 end) as combined_AI_average_speed,
--(case when sum(case when t1.cam_avg_speed >= 0 then t1.cam_avg_speed else 0 end) == 0 then NULL 
--else (case when t1.vehicle_type == 'ALL' then round((SUM(case when t1.cam_avg_speed >= 0 then t1.volume else 0 end) 
--/ AVG(NULLIF(t1.cam_avg_speed, 0))), 2) else NULL end) end) as AI_LOS_density,
t1.direction as direction
from
(
(
select camera_id,
TO_CHAR(DATETIME(time), 'yyyy-mm-dd') as date_q,
TO_CHAR(DATETIME(time), 'HH') as hour_q,
CAST(minute(time) / 5 as BIGINT) as min_q,
zone as agg_zone,
SUM(agg_count) as volume,
vehicle_type,
avg(case when avg_speed >= 0 then avg_speed else NULL end) as cam_avg_speed,
destination as direction
from dws_tfc_state_volume_speed_tp
where pt >= '{start_date}' and pt <= '{end_date}' -----------> amend here
and vehicle_type = 'ALL' and camera_id in ('{cam_id}') -----------> amend here
-- and zone like '%t2b%'
-- and hour(time) >= 0 and hour(time) <= 12
group by camera_id,date_q,hour_q,min_q,vehicle_type,agg_zone,destination
UNION 
select camera_id,
TO_CHAR(DATETIME(time), 'yyyy-mm-dd') as date_q,
TO_CHAR(DATETIME(time), 'HH') as hour_q,
CAST(minute(time) / 5 as BIGINT) as min_q,
zone as agg_zone,
SUM(agg_count) as volume,
vehicle_type,
avg(case when avg_speed >= 0 then avg_speed else NULL end) as cam_avg_speed,
destination as direction
from dws_tfc_state_volume_speed_tp
where pt >= '{start_date}' and pt <= '{end_date}' -----------> amend here
and vehicle_type <> 'ALL' and camera_id in ('{cam_id}') -----------> amend here 
-- and zone like '%t2b%'
-- and hour(time) >= 0 and hour(time) <= 12
group by camera_id,date_q,hour_q,min_q,vehicle_type,agg_zone,destination
) t1
left join
(select address,equipment_id,camera_id,pt from dim_camera_states) t2 
on t1.camera_id = t2.camera_id and t2.pt = '{end_date}' -----------> amend here (yesterday's date)
)
group by address,eq_id,t2.camera_id,day,hour_s,lane,vehicle_type,direction
    order by address,eq_id,t2.camera_id,day,hour_s,lane,vehicle_type,direction
-- group by eq_id,day,hour_s,min_q2,lane,vehicle_type,direction
;
