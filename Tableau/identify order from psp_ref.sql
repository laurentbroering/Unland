SELECT
      users.name as user_name
    , users.email
    , orders.source
    , marcas.marca_nome
    , produtos.modelo
    , sellers.name as seller_name
    , orders.canceled
    , service_requests.user_service_requests_count
    , service_requests.order_service_requests_count
    , payments.installments
    , orders.user_id
    , orders.user_cpf
    , orders.plan_id
    , plans.name as plan_name
    , stores.state
    , stores.city
    , payments.order_id
    , store_orders.seller_identifier
    , store_orders.seller_id
    , store_orders.imei
    , store_orders.plan_type
    , store_orders.bought_type
    , store_orders.sales_kind_id
    , sales_kinds.identifier
    , store_orders.invoice_number
    , users.phonenumber
    , users.address_street
    , users.address_zipcode
    , users.address_number
    , users.address_neighborhood
    , users.address_complement
    , users.address_city
    , users.address_state
    , users.orders_count
    , users.sign_in_count
    , users.cellphone_number
    
FROM payments

left join orders on payments.order_id = orders.id
left join users on orders.user_id = users.id
left join store_orders on store_orders.order_id = orders.id
left join stores on store_orders.store_id = stores.id
left join partners on stores.partner_id = partners.id 
left join sales_kinds on store_orders.sales_kind_id = sales_kinds.id
left join plans on orders.plan_id = plans.id
left join service_requests on orders.id = service_requests.order_id
left join produtos on orders.produto_id = produtos.id
left join marcas on produtos.marca_id = marcas.id
left join sellers on store_orders.seller_id = sellers.id