with
        initial_dates as (
            SELECT ((date_trunc('month', now())) - interval '1 month' * s.a)::timestamp without time zone AS start_month
            FROM generate_series (0,(extract(years from now())::int * 12 + extract(month from now())::int)-(extract(years from '2016-01-01'::date)::int * 12 + extract(month from '2016-01-01'::date)::int),1) AS s(a)
        )
        , date_intervals as (
            select start_month start_interval, (start_month + interval '1 month' - interval '1 second') end_interval
            from initial_dates
        )
        , repair_fee_payments_by_period as (
                select
                start_interval
                , end_interval
                , p.order_id
                , p.value
                , p.id
                , p.psp_reference
            from
                date_intervals
                cross join payments p
                left join service_requests sr on p.psp_reference = sr.payment_reference
            where p.reason = 'repair_fee'
            group by start_interval, end_interval, p.order_id, p.value, p.id
            having (min(least(sr.swapped_at)) :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' < end_interval
                and min(least(sr.swapped_at)) :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' >= start_interval)
        )
        , phone_price as (
                select
                order_id
                , total_price / 0.33 price
                from store_orders
        )
        select 
           start_interval::date
            , end_interval::date
            , repair_fee_payments_by_period.order_id

-- fee rev
            , sum(case 
                    when o.plan_id in (40, 61) and value > 0 then case
                        when sr.issue_id = 4 then phone.price * 0.70
                        else phone.price * 0.55 end
                    else value end) fee_rev
            , sum(case when sr.issue_id <> 1 then 0 else case 
                    when o.plan_id in (40, 61) and value > 0 then phone.price * 0.55
                    else value end end) fee_rev_tela
            , sum(case when sr.issue_id <> 2 then 0 else case 
                    when o.plan_id in (40, 61) and value > 0 then phone.price * 0.55
                    else value end end) fee_rev_agua
            , sum(case when sr.issue_id <> 3 then 0 else case 
                    when o.plan_id in (40, 61) and value > 0 then phone.price * 0.55
                    else value end end) fee_rev_slm
            , sum(case when sr.issue_id <> 4 then 0 else case 
                    when o.plan_id in (40, 61) and value > 0 then phone.price * 0.70
                    else value end end) fee_rev_rf

-- paid by insurer
            , sum(case 
                    when o.plan_id in (40, 61) and value > 0 then case
                        when sr.issue_id = 4 then phone.price * 0.70
                        else phone.price * 0.55 end - value
                    else 0 end) insurer_fee_cost

            , sum(case when sr.issue_id <> 4 and value > 0 then case 
        				when o.plan_id in (40, 61) then phone.price * 0.55 - value
                        else 0 end 
                    else 0 end) q_insurer_fee_cost

            , sum(case when sr.issue_id = 4 and value > 0 then case 
        				when o.plan_id in (40, 61) then phone.price * 0.70 - value
                        else 0 end 
                    else 0 end) rf_insurer_fee_cost

-- fee rev tax (PIS/COFINS e provisão p/ ICMS nos casos de RQF)
            , - sum(case 
                    when o.plan_id in (40, 61) and value > 0 then case
                        when sr.issue_id = 4 then phone.price * 0.70
                        else phone.price * 0.55 end * (9.25 + 3.00) / 100.00
                    else value * 9.25 / 100.00 end) fee_tax
            , - sum(case when sr.issue_id <> 1 then 0 else case 
                    when o.plan_id in (40, 61) and value > 0 then (phone.price * 0.55) * (9.25 + 3.00) / 100.00
                    else value * 9.25 / 100.00 end end) fee_tax_tela
            , - sum(case when sr.issue_id <> 2 then 0 else case 
                    when o.plan_id in (40, 61) and value > 0 then (phone.price * 0.55) * (9.25 + 3.00) / 100.00
                    else value * 9.25 / 100.00 end end) fee_tax_agua
            , - sum(case when sr.issue_id <> 3 then 0 else case 
                    when o.plan_id in (40, 61) and value > 0 then (phone.price * 0.55) * (9.25 + 3.00) / 100.00
                    else value * 9.25 / 100.00 end end) fee_tax_slm
            , - sum(case when sr.issue_id <> 4 then 0 else case 
                    when o.plan_id in (40, 61) and value > 0 then (phone.price * 0.70) * (9.25 + 3.00) / 100.00
                    else value * 9.25 / 100.00 end end) fee_tax_rf

        from repair_fee_payments_by_period
        left join service_requests sr on repair_fee_payments_by_period.psp_reference = sr.payment_reference
        left join orders o on repair_fee_payments_by_period.order_id = o.id
        left join phone_price phone on o.id = phone.order_id
        group by start_interval, end_interval, repair_fee_payments_by_period.order_id