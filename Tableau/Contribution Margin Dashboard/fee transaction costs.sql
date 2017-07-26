select
      payments.order_id as order_id
    , date_trunc('month',payments.created_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo') :: date as creation_month
    , - sum(case
        when payment_method = 'boletobancario_santander' then 2.90
        when payments.installments = 1 then 1.87 / 100 * payments.value + 0.27
        when payments.installments <= 3 then 2.21 / 100 * payments.value + 0.27
        when payments.installments <= 6 then 2.32 / 100 * payments.value + 0.27
        when payments.installments > 6 then 2.55 / 100 * payments.value + 0.27
        else 2.55 / 100 * payments.value + 0.27
        end) as fee_transaction_cost
    , - sum(case when issue_id = 1 then (case
        when payment_method = 'boletobancario_santander' then 2.90
        when payments.installments = 1 then 1.87 / 100 * payments.value + 0.27
        when payments.installments <= 3 then 2.21 / 100 * payments.value + 0.27
        when payments.installments <= 6 then 2.32 / 100 * payments.value + 0.27
        when payments.installments > 6 then 2.55 / 100 * payments.value + 0.27
        else 2.55 / 100 * payments.value + 0.27
        end) else 0 end) as fee_transaction_cost_tela
    , - sum(case when issue_id = 2 then (case
        when payment_method = 'boletobancario_santander' then 2.90
        when payments.installments = 1 then 1.87 / 100 * payments.value + 0.27
        when payments.installments <= 3 then 2.21 / 100 * payments.value + 0.27
        when payments.installments <= 6 then 2.32 / 100 * payments.value + 0.27
        when payments.installments > 6 then 2.55 / 100 * payments.value + 0.27
        else 2.55 / 100 * payments.value + 0.27
        end) else 0 end) as fee_transaction_cost_agua
    , - sum(case when issue_id = 3 then (case
        when payment_method = 'boletobancario_santander' then 2.90
        when payments.installments = 1 then 1.87 / 100 * payments.value + 0.27
        when payments.installments <= 3 then 2.21 / 100 * payments.value + 0.27
        when payments.installments <= 6 then 2.32 / 100 * payments.value + 0.27
        when payments.installments > 6 then 2.55 / 100 * payments.value + 0.27
        else 2.55 / 100 * payments.value + 0.27
        end) else 0 end) as fee_transaction_cost_slm
    , - sum(case when issue_id = 4 then (case
        when payment_method = 'boletobancario_santander' then 2.90
        when payments.installments = 1 then 1.87 / 100 * payments.value + 0.27
        when payments.installments <= 3 then 2.21 / 100 * payments.value + 0.27
        when payments.installments <= 6 then 2.32 / 100 * payments.value + 0.27
        when payments.installments > 6 then 2.55 / 100 * payments.value + 0.27
        else 2.55 / 100 * payments.value + 0.27
        end) else 0 end) as fee_transaction_cost_rf
    
from payments
left join trackings on payments.psp_reference = trackings.psp_reference
left join service_requests on payments.psp_reference = service_requests.payment_reference
where payments.reason like '%repair_fee%'
group by payments.order_id, creation_month