SELECT

  orders.id
  ,orders.created_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' as created_at
  ,user_id
  ,preco
  ,produto_id
  ,canceled_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' as canceled_at
  ,plan_id
  ,subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' as subscribed_at
  ,cancellation_reason_id
  ,direct_channel
  ,skip_auto_renewal
  ,order_parent_id
  ,old_price
  ,disable_service_request_fee
  ,product_prices.device_price
  ,source
  ,app_verification_status
  
FROM orders
left join product_prices on orders.produto_id = product_prices.product_id
      and (orders.subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo') >=
      (coalesce(product_prices.created_at :: timestamp, orders.subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo'))
      and (orders.subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo') <
      (coalesce(product_prices.expired_at :: timestamp + interval '1 day' - interval '1 second', orders.subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' + interval '1 second'))