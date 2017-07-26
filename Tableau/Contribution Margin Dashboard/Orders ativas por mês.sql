with
        initial_dates as (
            SELECT ((date_trunc('month', now())) - interval '1 month' * s.a)::timestamp without time zone AS start_month
            FROM generate_series (0,(extract(years from now())::int * 12 + extract(month from now())::int)-(extract(years from '2016-01-01'::date)::int * 12 + extract(month from '2016-01-01'::date)::int),1) AS s(a)
    	)
        , date_intervals as (
            select start_month start_interval, (start_month + interval '1 month' - interval '1 second') end_interval
            from initial_dates
        )
      , paid_orders as (
            select
                orders.id order_id
                , least(orders.subscribed_at, service_requests.arrived_at)  :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' order_subscribed_at
                , greatest(coalesce(orders.canceled_at, now()), 
                            coalesce(coalesce(service_requests.closed_at, 
                                service_requests.tracked_at),
                                    service_requests.arrived_at))  :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' order_canceled_at
            from orders
            left join service_requests on (orders.id = service_requests.order_id)
            where orders.payment_confirmed
            group by orders.id, order_subscribed_at, order_canceled_at
      )
      , orders_with_active_flag as (
          select
              start_interval
              , end_interval
              , order_id
              , (min(order_subscribed_at) <= end_interval  AND 
                (coalesce(max(order_canceled_at), now()) >= start_interval)) active

          from
              date_intervals
              cross join paid_orders
          group by start_interval, end_interval, order_id
      )
      , active_orders as (
          select 
             start_interval::date
              , end_interval::date
              , order_id
          from orders_with_active_flag
          where active
      )
      
  select
      active_orders.*
  from active_orders