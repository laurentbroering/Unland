select
      payments.order_id as order_id
    , date_trunc('month',payments.created_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' ) :: date as creation_month
    , - sum(case
            when partner_kinds.description = 'Venda externa' then 0
            else case 
                when trackings.payment_method = 'boletobancario_santander' or payments.psp_reference like '%boleto%' then 2.90
                else 0.27 + case
                    when payments.installments = 1 then 1.87 / 100.0 * payments.value
                    when payments.installments <= 3 then 2.21 / 100.0 * payments.value
                    when payments.installments <= 6 then 2.32 / 100.0 * payments.value
                    when payments.installments > 6 then 2.55 / 100.0 * payments.value
                    else 2.55 / 100.0 * payments.value
                    end / case when payments.reason = 'subscription' then 12 else 1 end
                end
            end) as plan_transaction_cost
from payments
left join trackings on payments.psp_reference = trackings.psp_reference
left join store_orders on payments.order_id = store_orders.order_id
left join stores on store_orders.store_id = stores.id
left join partners on stores.partner_id = partners.id
left join partner_kinds on partners.partner_kind_id = partner_kinds.id
where payments.reason not like '%repair_fee%'
group by payments.order_id, creation_month