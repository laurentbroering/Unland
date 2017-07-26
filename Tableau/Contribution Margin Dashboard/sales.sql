with
		initial_dates as (
		select ((date_trunc('month', now())) - interval '1 month' * s.a)::timestamp without time zone as start_month
		from generate_series (0,(extract(years from now())::int * 12 + extract(month from now())::int)-(extract(years from '2016-01-01'::date)::int * 12 + extract(month from '2016-01-01'::date)::int),1) as s(a)
	)

	, date_intervals as (
		select start_month start_interval, (start_month + interval '1 month' - interval '1 second') end_interval
		from initial_dates
	)

	, adj_payments as (
		select
			payments.id
		, payments.order_id
		, orders.plan_id
		, orders.direct_channel
		, partners.id partner_id
		, orders.subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' subscribed_at -- Data de subscribed da order com ajuste do fuso horário
		, orders.canceled_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' canceled_at -- Data de cancelamento da order com ajuste do fuso horário
		, payments.created_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' created_at -- Data de criação do pagamento com ajuste do fuso horário
		
		-- Marca se a venda foi cancelada dentro dos primeiros 7 ou 15 dias (canal direto)
		, case
			when direct_channel
			then subscribed_at + interval '15 days' > canceled_at and subscribed_at <= canceled_at
			else subscribed_at + interval '8 days' > canceled_at and subscribed_at <= canceled_at end withdrawn_sale

		-- Calcula o valor da venda (anual ou mensal)
		, case
			when plan_id in (8,10) then store_orders.total_price / 12.00
			when direct_channel then orders.preco
			else store_orders.total_price end as value

		-- Cálculo do revenue share da Pitzi
		, case
			when plan_id in (8, 9, 10, 14, 16) then 1
			when plan_id not in (40,61) then 1 - coalesce(revenue_shares.value / 100.00, 0.00)
			else (case
				when partners.id in (15, 27, 46, 77, 159, 163, 363) then 0.20 -- Revenue share de RFQ da Digital Telecom (15), Imagem Telecom (27), Rocha Telecom (46), DSM Telecom (77), MC Telecom (159), Alegria Telecom (163), Magnata (363)
				when partners.id in (164, 383, 395) then 0.15 -- Revenue share de RFQ da Sete Lan (164), LG RJ (FR2S) (383) e Celular Station RJ - (VIVO) (395)
				when partners.id in (177) then 0.23 -- Comissões Facell (177)
				else 0
			end) * (1 - 0.0738) -- Subtrai IOF de planos RFQ
			end pitzi_share

		-- Cálculo do revenue share do partner
		, case
			when plan_id in (8, 9, 10, 14, 16) then 0
			when plan_id not in (40,61) then coalesce(revenue_shares.value / 100.00, 0.00)
			else (case
				when partners.id in (15, 27, 46, 77, 159, 163, 363) then 0.35 -- Revenue share de RFQ da Digital Telecom (15), Imagem Telecom (27), Rocha Telecom (46), DSM Telecom (77), MC Telecom (159), Alegria Telecom (163), Magnata (363)
				when partners.id in (164, 383, 395) then 0.40 -- Revenue share de RFQ da Sete Lan (164), LG RJ (FR2S) (383) e Celular Station RJ - (VIVO) (395)
				when partners.id in (177) then 0.35 -- Comissões Facell (177)
				else 0
			end) * (1 - 0.0738) -- Subtrai IOF de planos RFQ
			end partner_share

		-- Cálculo do revenue share da seguradora
		, case
			when plan_id not in (40,61) then 0
			else (case
				when partners.id in (15, 27, 46, 77, 159, 163, 363) then 0.45 -- Revenue share de RFQ da Digital Telecom (15), Imagem Telecom (27), Rocha Telecom (46), DSM Telecom (77), MC Telecom (159), Alegria Telecom (163), Magnata (363)
				when partners.id in (164, 383, 395) then 0.45 -- Revenue share de RFQ da Sete Lan (164), LG RJ (FR2S) (383) e Celular Station RJ - (VIVO) (395)
				when partners.id in (177) then 0.42 -- Comissões Facell (177)
				else 0
			end) * (1 - 0.0738) -- Subtrai IOF de planos RFQ
			end insurer_share

		from payments
		left join orders on orders.id = payments.order_id
		left join store_orders on store_orders.order_id = orders.id
		left join stores on stores.id = store_orders.store_id
		left join partners on stores.partner_id = partners.id
		left join revenue_shares on partners.id = revenue_shares.partner_id
			and (orders.subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo') >=
			(coalesce(revenue_shares.begin_at :: timestamp, orders.subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo'))
			and (orders.subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo') <
			(coalesce(revenue_shares.finish_at :: timestamp + interval '1 day' - interval '1 second', orders.subscribed_at :: timestamp at time zone 'UTC' at time zone 'America/Sao_Paulo' + interval '1 second'))
		where payments.reason in ('subscription'))

	, payments_by_period as (
		select
			start_interval
		, end_interval
		, id
		, plan_id
		, direct_channel
		, subscribed_at
		, canceled_at
		, order_id
		, created_at
		, partner_id
		, pitzi_share
		, partner_share
		, insurer_share
		, coalesce(withdrawn_sale,false) withdrawn_sale
		, value

		, case when plan_id not in (40, 61) then value else 0 end plan_value
		, case when plan_id in (40, 61) then value else 0 end admin_value

		, value * pitzi_share pitzi_plan_value
		, value * partner_share partner_plan_value
		, value * insurer_share insurer_plan_value

		from adj_payments
		cross join date_intervals
		group by start_interval, end_interval,
			id, plan_id, direct_channel, subscribed_at, canceled_at, order_id, created_at, partner_id, pitzi_share, partner_share, insurer_share, withdrawn_sale, value, plan_value, admin_value, pitzi_plan_value, partner_plan_value, insurer_plan_value
		having (min(least(created_at)) < end_interval and min(least(created_at)) >= start_interval)
	)

	select
			start_interval::date
		, end_interval::date
		, order_id
		
		, avg(pitzi_share) pitzi_share
		, avg(partner_share) partner_share
		, avg(insurer_share) insurer_share

		, count(id) sale_count -- Número de planos vendidos
			, sum(case when plan_value > 0 then 1 else 0 end) plan_count -- Número de planos de proteção vendidos
			, sum(case when admin_value > 0 then 1 else 0 end) rfq_count -- Número de planos de RFQ vendidos
		, - sum(case when withdrawn_sale then 1 else 0 end) withdrawn_sale_count

		, sum(value) total_sale -- Total de vendas
			, sum(plan_value) plan_sale -- Total de vendas de planos de proteção
				, sum(plan_value) * avg(pitzi_share) pitzi_plan_sale -- Share de vendas de planos de proteção da Pitzi
				, sum(plan_value) * avg(partner_share) partner_plan_sale -- Share de vendas de planos de proteção do parceiro
			, sum(admin_value) rfq_sale -- Total de vendas de planos de RFQ (inclui IOF)
				, sum(admin_value) * 0.0738 iof_rfq_sale -- IOF sobre planos de RFQ
				, sum(admin_value) * avg(pitzi_share) pitzi_rfq_sale -- Share de vendas de planos de RFQ da Pitzi (sem IOF)
				, sum(admin_value) * avg(partner_share) partner_rfq_sale -- Share de vendas de planos de RFQ do parceiro (sem IOF)
				, sum(admin_value) * avg(insurer_share) insurer_rfq_sale -- Share de vendas de planos de RFQ da seguradora (sem IOF)

		, - sum(plan_value) * 9.25 / 100.00 as plan_sale_pis_cofins -- PIS/COFINS sobre planos de proteção
			, - sum(plan_value) * avg(pitzi_share) * 9.25 / 100.00 as pitzi_plan_sale_pis_cofins -- PIS/COFINS sobre planos de proteção pagos pela Pitzi
			, - sum(plan_value) * avg(partner_share) * 9.25 / 100.00 as partner_plan_sale_pis_cofins -- PIS/COFINS sobre planos de proteção pagos pelo parceiro

		, - sum(admin_value) * (1 - 0.0738) * 9.25 / 100.00 as rfq_sale_pis_cofins -- PIS/COFINS sobre planos de RFQ
			, - sum(admin_value) * avg(pitzi_share) * 9.25 / 100.00 as pitzi_rfq_sale_pis_cofins -- PIS/COFINS sobre planos de RFQ pagos pela Pitzi
			, - sum(admin_value) * avg(partner_share) * 9.25 / 100.00 as partner_rfq_sale_pis_cofins -- PIS/COFINS sobre planos de RFQ pagos pelo parceiro
			, - sum(admin_value) * avg(insurer_share) * 9.25 / 100.00 as insurer_rfq_sale_pis_cofins -- PIS/COFINS sobre planos de RFQ pagos pela seguradora

		, - sum(admin_value) * (1 - 0.0738) * 5.00 / 100.00 as rfq_sale_iss -- ISS sobre planos de RFQ
			, - sum(admin_value) * avg(pitzi_share) * 5.00 / 100.00 as pitzi_rfq_sale_iss -- ISS sobre planos de RFQ pagos pela Pitzi
			, - sum(admin_value) * avg(partner_share) * 5.00 / 100.00 as partner_rfq_sale_iss -- ISS sobre planos de RFQ pagos pelo parceiro
			, - sum(admin_value) * avg(insurer_share) * 5.00 / 100.00 as insurer_rfq_sale_iss -- ISS sobre planos de RFQ pagos pela seguradora

		from payments_by_period
		group by start_interval, end_interval, order_id