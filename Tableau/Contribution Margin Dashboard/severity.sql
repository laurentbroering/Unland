with
        initial_dates as (
            SELECT ((date_trunc('month', now())) - interval '1 month' * s.a)::timestamp without time zone AS start_month
            FROM generate_series (0,(extract(years from now())::int * 12 + extract(month from now())::int)-(extract(years from '2016-01-01'::date)::int * 12 + extract(month from '2016-01-01'::date)::int),1) AS s(a)
    	)
        , date_intervals as (
            select start_month start_interval, (start_month + interval '1 month' - interval '1 second') end_interval
            from initial_dates
        )
      , SR_repaired_inhouse as (
          select
              service_requests.id
            , service_requests.issue_id
          from
              service_requests 
          inner join
              repairs on (service_requests.id = repairs.service_request_id)
          where
              repairs.repair_shop_id = 28
          group by
              service_requests.id, service_requests.issue_id
      )
        , SR_by_period as (
                select
                start_interval
                , end_interval
                , order_id
                , issue_id
                , (sr.id)
                , ((sr.swapped_at) :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' < end_interval
                and (sr.swapped_at) :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' >= start_interval) swapped
            from
                date_intervals
                cross join service_requests sr
            group by start_interval, end_interval, swapped, sr.id, order_id, sr.issue_id
        )
        , orders_with_SR as (
        select 
        start_interval
                , end_interval
                , order_id
                , id
                , issue_id
            from SR_by_period
            where swapped
            group by start_interval, end_interval, order_id, id, issue_id
            )
            
select
     start_interval::date
   , end_interval::date
   , order_id

-- repair cost
   , sum(-repair_cost) repair_cost
   , sum(case when orders_with_SR.issue_id = 1 then - repair_cost else 0 end) repair_cost_tela
   , sum(case when orders_with_SR.issue_id = 2 then - repair_cost else 0 end) repair_cost_agua
   , sum(case when orders_with_SR.issue_id = 3 then - repair_cost else 0 end) repair_cost_slm
   , sum(case when orders_with_SR.issue_id = 4 then - repair_cost else 0 end) repair_cost_rf

-- swap cost
   , sum(invoice_in_value - invoice_out_value) swap_cost
   , sum(case when orders_with_SR.issue_id = 1 then invoice_in_value - invoice_out_value else 0 end) swap_cost_tela
   , sum(case when orders_with_SR.issue_id = 2 then invoice_in_value - invoice_out_value else 0 end) swap_cost_agua
   , sum(case when orders_with_SR.issue_id = 3 then invoice_in_value - invoice_out_value else 0 end) swap_cost_slm
   , sum(case when orders_with_SR.issue_id = 4 then invoice_in_value - invoice_out_value else 0 end) swap_cost_rf

-- inbound logistic cost
   , sum(- coalesce(from_customer_value,35)) inbound_logistic_cost
   , sum(case when orders_with_SR.issue_id = 1 then - coalesce(from_customer_value,35) else 0 end) inbound_logistic_cost_tela
   , sum(case when orders_with_SR.issue_id = 2 then - coalesce(from_customer_value,35) else 0 end) inbound_logistic_cost_agua
   , sum(case when orders_with_SR.issue_id = 3 then - coalesce(from_customer_value,35) else 0 end) inbound_logistic_cost_slm
   , sum(case when orders_with_SR.issue_id = 4 then - coalesce(from_customer_value,35) else 0 end) inbound_logistic_cost_rf

-- outbound logistic cost
   , sum(- coalesce(from_pitzi_value,35)) outbound_logistic_cost
   , sum(case when orders_with_SR.issue_id = 1 then - coalesce(from_pitzi_value,35) else 0 end) outbound_logistic_cost_tela
   , sum(case when orders_with_SR.issue_id = 2 then - coalesce(from_pitzi_value,35) else 0 end) outbound_logistic_cost_agua
   , sum(case when orders_with_SR.issue_id = 3 then - coalesce(from_pitzi_value,35) else 0 end) outbound_logistic_cost_slm
   , sum(case when orders_with_SR.issue_id = 4 then - coalesce(from_pitzi_value,35) else 0 end) outbound_logistic_cost_rf

-- severity tax credit
   , sum(repair_cost + invoice_out_value - invoice_in_value) * 9.25 / 100.00 severity_tax_credit
   , sum(case when orders_with_SR.issue_id = 1 then (repair_cost + invoice_out_value - invoice_in_value) * 9.25 / 100.00 else 0 end) severity_tax_credit_tela
   , sum(case when orders_with_SR.issue_id = 2 then (repair_cost + invoice_out_value - invoice_in_value) * 9.25 / 100.00 else 0 end) severity_tax_credit_agua
   , sum(case when orders_with_SR.issue_id = 3 then (repair_cost + invoice_out_value - invoice_in_value) * 9.25 / 100.00 else 0 end) severity_tax_credit_slm
   , sum(case when orders_with_SR.issue_id = 4 then (repair_cost + invoice_out_value - invoice_in_value) * 9.25 / 100.00 else 0 end) severity_tax_credit_rf

--  swaps count
   , count(orders_with_SR.id) swapped_sr
   , sum(case when orders_with_SR.issue_id = 1 then 1 else 0 end) swapped_sr_tela
   , sum(case when orders_with_SR.issue_id = 2 then 1 else 0 end) swapped_sr_agua
   , sum(case when orders_with_SR.issue_id = 3 then 1 else 0 end) swapped_sr_slm
   , sum(case when orders_with_SR.issue_id = 4 then 1 else 0 end) swapped_sr_rf

-- inhouse sr count
   , count(SR_repaired_inhouse.id) inhouse_sr
   , sum(case when SR_repaired_inhouse.issue_id = 1 then 1 else 0 end) inhouse_sr_tela
   , sum(case when SR_repaired_inhouse.issue_id = 2 then 1 else 0 end) inhouse_sr_agua
   , sum(case when SR_repaired_inhouse.issue_id = 3 then 1 else 0 end) inhouse_sr_slm
   , sum(case when SR_repaired_inhouse.issue_id = 4 then 1 else 0 end) inhouse_sr_rf

from
  orders_with_SR
left join 
  rel_service_request_costs on (orders_with_SR.id = rel_service_request_costs.service_request_id)
left join
  SR_repaired_inhouse on (orders_with_SR.id = SR_repaired_inhouse.id)
left join service_request_postings on (orders_with_SR.id = service_request_postings.service_request_id)
group by start_interval, end_interval, order_id