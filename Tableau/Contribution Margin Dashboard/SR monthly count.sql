with
        initial_dates as (
            SELECT ((date_trunc('month', now())) - interval '1 month' * s.a)::timestamp without time zone AS start_month
            FROM generate_series (0,(extract(years from now())::int * 12 + extract(month from now())::int)-(extract(years from '2016-01-01'::date)::int * 12 + extract(month from '2016-01-01'::date)::int),1) AS s(a)
    	)
        , date_intervals as (
            select start_month start_interval, (start_month + interval '1 month' - interval '1 second') end_interval
            from initial_dates
        )
    , SR_by_period as (
              select
              start_interval
              , end_interval
              , order_id
              , id
              , issue_id
              , (min(sr.arrived_at) :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' < end_interval
              AND min(sr.arrived_at) :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' >= start_interval) active
          from
              date_intervals
              cross join service_requests sr
          group by start_interval, end_interval, order_id, id
      )
      , orders_with_SR as (
          select 
             start_interval
              , end_interval
              , order_id
              , id
              , issue_id
          from SR_by_period
          where active
      )
  select
       start_interval::date
      , end_interval::date
      , order_id
      , coalesce(count(id),0) count
      , sum(coalesce(case when issue_id = 1 then 1 end,0)) arrived_count_tela
      , sum(coalesce(case when issue_id = 2 then 1 end,0)) arrived_count_agua
      , sum(coalesce(case when issue_id = 3 then 1 end,0)) arrived_count_slm
      , sum(coalesce(case when issue_id = 4 then 1 end,0)) arrived_count_rf
  from orders_with_SR
  group by start_interval, end_interval, order_id