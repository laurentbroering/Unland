SELECT
  
  stores.id
  ,name
  ,partner_id
  ,coalesce(address,'') address
  ,coalesce(number,'') number
  ,coalesce(neighborhood,'') neighborhood
  ,coalesce(city,'') city
  ,coalesce(state,'') state
  ,coalesce(zipcode,'') zipcode
  ,coalesce(region,'') region
  ,regional_manager_id
  
  
FROM stores