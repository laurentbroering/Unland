with
        initial_dates as (
            SELECT ((date_trunc('month', now())) - interval '1 month' * s.a)::timestamp without time zone AS start_month
            FROM generate_series (0,(extract(years from now())::int * 12 + extract(month from now())::int)-(extract(years from '2016-01-01'::date)::int * 12 + extract(month from '2016-01-01'::date)::int),1) AS s(a)
    	)
        , date_intervals as (
            select start_month start_interval, (start_month + interval '1 month' - interval '1 second') end_interval
            from initial_dates
        )
    , select_orders as (
        select
            start_interval
            , end_interval
            , orders.id o_id
            , (min(least(orders.subscribed_at, service_requests.arrived_at))  :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' <= end_interval  AND 
                (coalesce(max(greatest(coalesce(orders.canceled_at, now()), coalesce(coalesce(service_requests.closed_at, service_requests.tracked_at),service_requests.arrived_at))), now())  :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' >= start_interval)) active
        from orders
        cross join date_intervals
        left join service_requests on (orders.id = service_requests.order_id)
        group by start_interval, end_interval, o_id
    )
    , selected_device_swaps as(
        select
            orders.id o_id
            , device_swaps.created_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' c_at
            , device_swaps.id dswap_id
        from
            orders
        LEFT JOIN service_requests ON orders.id = service_requests.order_id
        INNER JOIN device_swaps ON device_swaps.service_request_id = service_requests.id
    )
    , orders_with_product as (
        select
            start_interval
            , end_interval
            , select_orders.o_id
            , case
                when
                    (MIN(c_at) < end_interval 
                    AND MIN(c_at) >= start_interval)
                    then MIN(dswap_id)
                when
                    (MIN(c_at) < end_interval)
                    then MAX(dswap_id)
                else
                    MIN(dswap_id)
                end as dswap_id
        from
            select_orders
        left join selected_device_swaps on select_orders.o_id = selected_device_swaps.o_id
        where active
        group by start_interval, end_interval, select_orders.o_id
    )
    
select
    start_interval::date
    , end_interval::date
    , o_id
    , CASE
        WHEN 
            device_swaps.created_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' > start_interval 
            AND device_swaps.created_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' < end_interval
            THEN old_product.id
        when device_swaps.created_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' > start_interval 
            THEN old_product.id
        WHEN device_swaps.created_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' < start_interval 
            THEN new_product.id
        ELSE orders.produto_id
        END as product_id
        
from orders_with_product
LEFT JOIN orders ON orders_with_product.o_id = orders.id
left JOIN device_swaps ON orders_with_product.dswap_id = device_swaps.id

LEFT JOIN devices as old_device on device_swaps.old_device_id = old_device.id
LEFT JOIN produtos as old_product on old_device.product_id = old_product.id
    
LEFT JOIN devices as new_device on device_swaps.new_device_id = new_device.id
LEFT JOIN produtos as new_product on new_device.product_id = new_product.id