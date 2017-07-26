SELECT
  
  store_orders.id
  ,order_id
  ,installments
  ,total_price
  ,payment_method
  ,seller_identifier
  ,store_id
  ,seller_id
  ,plan_type
  ,device_value_paid
  ,device_value_without_discount
  ,bought_type
  ,price_label
  ,sales_kind_id
  ,description
  ,app_verification_status
  
FROM store_orders
left join sales_kinds on sales_kinds.id = store_orders.sales_kind_id