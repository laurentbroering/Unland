select
  
  store_orders.id
  ,order_id
  ,installments
  ,total_price
  ,payment_method
  ,seller_identifier
  ,store_orders.store_id
  ,seller_id
  ,sellers.name
  ,plan_type
  ,device_value_paid
  ,device_value_without_discount
  ,bought_type
  ,price_label
  ,sales_kind_id
  ,description
  
from store_orders
left join sales_kinds on sales_kinds.id = store_orders.sales_kind_id
left join sellers on sellers.id = store_orders.seller_id