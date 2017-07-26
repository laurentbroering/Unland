SELECT
  
  partners.id
  ,partners.name
  ,account_manager_id
  ,retail
  ,partner_sizes.size
  ,partner_groups.name group_name
  
FROM partners
left join partner_groups on partners.partner_group_id = partner_groups.id
left join partner_sizes on partners.partner_size_id = partner_sizes.id