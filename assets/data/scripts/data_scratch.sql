-- ############## --
-- # DATA QA/QC # --
-- ############## --


-- a scratchpad for data processing and review, to inform data aggregation logic


----------------------
-- PARCEL UNIQUE ID --
----------------------


-- two attributes available: parcelnumb, parcel_num

-- review parcel_num first:
select parcel_num, count(*) as count from parcels_ilmenard group by parcel_num having count(*) > 1 order by count(*) desc, parcel_num;
-- 113 NULL, 4 instances of 2 records sharing the same value (parcel_num)

-- review parcelnumb to compare:
select parcelnumb, count(*) as count from parcels_ilmenard group by parcelnumb having count(*) > 1 order by count(*) desc, parcelnumb;
-- 0 NULL, 83 'U/I', same 4 instances of 2 records sharing the same value (parcelnumb)

-- further review the difference between 113 NULL parcel_num while only 83 'U/I' parcelnumb:
select parcel_num, parcelnumb from parcels_ilmenard where parcel_num is null and parcelnumb is not null and parcelnumb <> 'U/I';
-- 30 records where parcel_num is NULL but parcelnumb appears valid

-- parcelnumb appears to be the parcel number attribute to use, over parcel_num

-- review the 4 instances of 2 records sharing the same parcelnumb value
with x as
(select parcel_num, count(*) as count from parcels_ilmenard group by parcel_num having count(*) > 1)
select parcels_ilmenard.parcel_num, parcelnumb, ogc_fid, gross_acre, farm_acres, farm_land, tax_code, owner1_id, owner, owner2_id, owner2_nam, owner3_id, owner3_nam, legal, address, site_csz, township_n, township
from parcels_ilmenard, x
where parcels_ilmenard.parcel_num = x.parcel_num
order by parcel_num;
-- these appear to be intended to be multipolygons (2 polygons per parcelnumb), but each polygon is split into its own record
-- each record's ogc_fid is unique, while all other attributes appear to be the same

-- since parcel data will be aggregated (via ST_Union) by owner, no need for major concern re: establishing a valid parcel number value for each parcel, for now


--------------------------
-- AGRICULTURAL PARCELS --
--------------------------
-- "... important to ... restrict your analysis to agricultural parcels."


-- need to restrict analysis to agricultural parcels, and therefore need to determine the appropriate logic (i.e., identify attribute(s) to indicate agricultural use)

-- two attributes immediately come to mind: farm_acres, farm_land
-- farm_acres is numeric, while farm_land is a string, suggesting farm_land may be related to zoning or tax code

-- other farm-related attributes may also be relevant: non_farm_l, farm_build, non_farm_b
-- other tax-related attributes may also be relevant: tax_code, tax_status, legal
-- including these for comparison in query below

-- compare potential attributes
-- query where farm_acres is null or 0 and farm_land is not null and not '0' (potentially indicating land zoned for farming but not yet developed)
select parcelnumb, gross_acre, farm_acres, farm_land, non_farm_l, farm_build, non_farm_b, tax_code, tax_status, legal, owner1_id, owner, owner2_id, owner2_nam, owner3_id, owner3_nam, address, site_csz, township_n, township
from parcels_ilmenard
where farm_land is not null and farm_land <> '0' and (farm_acres is null or farm_acres = 0);
-- only 2 records where farm_acres is null or 0 and farm_land is not null and not '0'
-- ultimately, silos do not overlap these 2 parcels so no need for major concern

-- reverse the query, where farm_land is null or '0' and farm_acres is not null and not 0
select parcelnumb, gross_acre, farm_acres, farm_land, non_farm_l, farm_build, non_farm_b, tax_code, tax_status, legal, owner1_id, owner, owner2_id, owner2_nam, owner3_id, owner3_nam, address, site_csz, township_n, township
from parcels_ilmenard
where farm_acres is not null and farm_acres <> 0 and (farm_land is null or farm_land = '0');

select count(*)
from parcels_ilmenard
where farm_acres is not null and farm_acres <> 0 and (farm_land is null or farm_land = '0');
-- 21 records where farm_land is null or '0' and farm_acres is not null and not 0
-- seems to indicate that farm_acres may be the better indicator of agricultural land use

-- quick look at tax_code and tax_status to see if of any help:
select count(distinct tax_code) from parcels_ilmenard where farm_acres is not null and farm_acres <> 0;
-- 76 tax codes where farm_acres is not null and <> 0
select count(distinct tax_status) from parcels_ilmenard where farm_acres is not null and farm_acres <> 0;
-- 2 tax statuses where farm_acres is not null and <> 0
select distinct tax_status from parcels_ilmenard where farm_acres is not null and farm_acres <> 0;
-- tax statuses: 'T' or 'E'

-- found the zoning/GIS website for Menard County, IL: http://menardcountyil.com/departments/zoning-gis/
-- and did some digging around zoning/tax codes: http://menardcountyil.org/files/7515/2950/7624/Ordinance_Modified_06.12.18.pdf
-- along with the parcel map viewer: http://mencoilgis.maps.arcgis.com/apps/webappviewer/index.html?id=bc642e2233714b198e073bd1adf934f5
-- and its metadata: http://mencoilgis.maps.arcgis.com/home/item.html?id=bc642e2233714b198e073bd1adf934f5
-- but unable to glean significant information re: determining agricultural land use beyond the attributes already identified

-- next, considered possible logic around establishing a threshold for a parcel's farm_acres as a percentage of gross_acres
-- for example, if farm_acres represent less than 50% of a parcel's gross_acres then parcel should not be considered agricultural use
with x as
(select parcel_num from parcels_ilmenard where farm_acres > 0 and (farm_acres/gross_acre) < 0.5)
select parcels_ilmenard.parcel_num, parcelnumb, ogc_fid, gross_acre, farm_acres, farm_land, tax_code, owner1_id, owner, owner2_id, owner2_nam, owner3_id, owner3_nam, legal, address, site_csz, township_n, township
from parcels_ilmenard, x
where parcels_ilmenard.parcel_num = x.parcel_num
order by parcel_num;
-- only 2 records (parcelnumb '17-08-100-008' and '17-21-100-003') where farm_acres is > 0 and less than 50% of gross_acres
-- like above, silos do not overlap these 2 parcels so no need for major concern
-- logically speaking, presence of farm_acres is likely to indicate parcel agricultural use anyway

-- after comparing farm_acres and farm_land and lacking any specificity re: zoning/tax codes:
-- moving forward with using "farm_acres > 0" as indication of agricultural parcel


----------------------
-- PARCEL OWNERSHIP --
----------------------
-- "Also note some farms consist of many different parcels of land. It will be important to combine by a single owner ..."


-- need to combine parcels by a single owner, to represent that owner's farm land (and ultimately its maximum on-farm storage capacity) as a whole
-- therefore need to determine the appropriate logic (i.e., identify attribute(s) establishing ownership)

-- parcel data tracks three owners using six attributes: owner, owner1_id, owner2_nam, owner2_id, owner3_nam, owner3_id

-- the selection of owner attribute appears to be ambiguous
-- Menard County's AGOL parcel viewer does little to clarify which owner attribute to use when
-- the viewer tends to show the "owner" attribute as the parcel owner the majority of the time, but owner2_nam and owner3_nam do take precedence occassionally

-- ideally would use a unique id to aggregate, not a string
-- review validity of owner1_id unique id to owner string:
with x as
(select distinct owner, owner1_id from parcels_ilmenard)
select owner, count(*)
from x
group by owner
having count(*) > 1
order by count(*) desc;
-- returns 913 records (owners with multiple owner1_id's)
-- while a handful of owners having the same name could make sense, warranting a number of duplicate "owner" values with the same owner1_id, this likely does not
-- this leads me to believe that owner1_id is not a valid unique id for use in aggregation by owner

-- compare counts for owner vs. owner2_nam vs. owner3_nam attributes:
select count(*) from parcels_ilmenard where owner is not null; --11,839
select count(*) from parcels_ilmenard where owner2_nam is not null; --628
select count(*) from parcels_ilmenard where owner3_nam is not null; --74

-- query parcels with values for all three owner names and review in AGOL parcel viewer:
select parcelnumb, owner1_id, owner, owner2_id, owner2_nam, owner3_id, owner3_nam from parcels_ilmenard where owner is not null and owner2_nam is not null and owner3_nam is not null limit 10;
-- first parcel, '07-09-400-001', displays "owner" as owner even though owner2_nam and owner3_nam are populated

-- reviewing more records in the AGOL parcel viewer in which owner and owner2_nam and/or owner3_nam are populated yields no further clarification re: attribution selection logic
-- lacking any further claritiy re: owner attribute selection logic:
-- moving forward with "owner" as attribute on which to aggregate parcels by ownership

-- (note: ideally would create pick-list table of unique owner names, to assign each a valid unique id, and use FK to unique id when assigning ownership in parcels table)


------------------------------------------
-- FILTER SILOS TO AGRICULTURAL PARCELS --
------------------------------------------
-- "Some other buildings (such as municipal waste treatment facilities) may also fit the same description; however, parcel data can be used to filter out these unwanted buildings"


-- count silos contained within agricultural parcels (using farm_acres > 0 logic to identify agricultural parcels)
-- use centroid to avoid parcel overlap, which would return "False" when using "ST_Contains"
-- count returned: 564
with p as
(select owner, st_union(geom) as geom from parcels_ilmenard where farm_acres > 0 group by owner)
select count(*)
from silos_ilmenard s, p
where st_contains(p.geom, st_centroid(s.geom)) = 'True';

-- count silos that fall outside of agricultural parcels
-- use centroid to avoid potentially intersecting inside and outside agricultural parcels
-- count returned: 53
-- 564 + 53 = 617 (which is silos record total)
-- note: grouping by "state" instead of "owner" here to identify silos that fall outside of *any* agricultural parcels (requires grouping on a common attribute across all records)
-- if grouped by owner, every agricultural parcel by owner that a silo falls outside of would count once towards the "count(*)" total, resulting in count of 1014401
with p as
(select state, st_union(geom) as geom from parcels_ilmenard where farm_acres > 0 group by state)
select count(*)
from silos_ilmenard s, p
where st_contains(p.geom, st_centroid(s.geom)) = 'False';

-- no need to confirm against intersects (ST_Intersects) given all silos records (617) accounted for via contains (ST_Contains)


-------------------------------------
-- FILTER SILOS TO 4-20 M DIAMETER --
-------------------------------------
-- "Grain bins are generally circular buildings from 4-20 meters in diameter"


-- query min and max diameter to identify potentially false positive buildings (buildings with a diameter too small or large to be a silo)
select round(min(diameter), 1), round(max(diameter), 1) from silos_ilmenard;
-- returns min of 4.5, max of 23.1

-- query total record count of silos over 20 meters in diameter
select count(*) from silos_ilmenard where diameter > 20;
-- returns record count of 2

-- query whether these silos fall inside or outside of agricultural land
with p as
(select state, st_union(geom) as geom from parcels_ilmenard where farm_acres > 0 group by state)
select s.diameter, st_contains(p.geom, st_centroid(s.geom))
from silos_ilmenard s, p
where s.diameter > 20;
-- both "ST_Contains" values return "f" ("False"), meaning they are not contained within agricultural land and will be excluded in spatial join and therefore are of no major concern

-- query min and max diameter of silos that fall inside agricultural land
-- to inform total storage volume estimates
with p as
(select state, st_union(geom) as geom from parcels_ilmenard where farm_acres > 0 group by state)
select round(min(s.diameter), 1), round(max(s.diameter), 1)
from silos_ilmenard s, p
where st_contains(p.geom, st_centroid(s.geom)) = 'True';
-- returns min of 4.5, max of 14.7


--------------------------------
-- TOTAL STORAGE VOLUME LOGIC --
--------------------------------
-- "will need to estimate total volume that can be stored in each building. (The bins can vary in height based on diameter, example here.)
-- (see link to PDF below for link from "here" above)
-- "The obvious choice would be to find the building heights to determine an exact capacity, but without this information we can still provide a ranged estimate."
-- "Finding the exact storage volume is not the objective here ..."


-- assuming all silos are "wide corrugation bins" here
-- https://www.brockmfg.com/uploads/pdf/BR_2286_201702_Brock_Non_Stiffened_Storage_Capacities_Fact_Sheet_EM.pdf

-- wide corrugation bin diameters:
-- 4.6, 5.5, 6.4, 7.3, 8.2, 9.1, 10.1, 11.0, 12.8, 14.6
-- break points for rounding are therefore:
-- >= 4 <= 5
-- > 5 <= 5.9
-- > 5.9 <= 6.8
-- > 6.8 <= 7.7
-- > 7.7 <= 8.6
-- > 8.6 <= 9.6
-- > 9.6 <= 10.5
-- > 10.5 <= 11.9
-- > 11.9 <= 13.7
-- > 13.7 <= 20.0

-- see PDF above for maximum capacity, in bushels, for shortest and tallest bin with given diameter
-- maximum capacity of tallest bin with given diameter = max_volume_bushels
-- maximum capacity of shortest bin with given diameter = min_volume_bushels
-- using "bushels" as a unit of measure because it is generic, not grain-dependent (corn vs. wheat), and provides a suitable first glance of volume

-- FOR THE FUTURE, consider including:
-- field for bin type (wide corrguation bins vs. narrow corrugation bins vs. hopper-bottom holding bins, etc)
	 -- which would dictate volume calculations
	 -- foreign key to pick-list table with bin type domain
-- field for bin height (meters)
-- field(s) for volume, calculated from bin type + diameter + height (using CASE expression)
	 -- potentially 1 for bushels, 1 for corn, 1 for wheat, etc
	 -- bin type-dependent

-- initial query of silo data with wide bin diameter and associated volume attributes, for review/confirmation
select
	gid,
	round(diameter, 1) as diameter,
	case
		when 4.0 <= round(diameter, 1) and round(diameter, 1) <= 5.0 then 4.6
		when 5.0 <= round(diameter, 1) and round(diameter, 1) <= 5.9 then 5.5
		when 5.9 <= round(diameter, 1) and round(diameter, 1) <= 6.8 then 6.4
		when 6.8 <= round(diameter, 1) and round(diameter, 1) <= 7.7 then 7.3
		when 7.7 <= round(diameter, 1) and round(diameter, 1) <= 8.6 then 8.2
		when 8.6 <= round(diameter, 1) and round(diameter, 1) <= 9.6 then 9.1
		when 9.6 <= round(diameter, 1) and round(diameter, 1) <= 10.5 then 10.1
		when 10.5 <= round(diameter, 1) and round(diameter, 1) <= 11.9 then 11.0
		when 11.9 <= round(diameter, 1) and round(diameter, 1) <= 13.7 then 12.8
		when 13.7 <= round(diameter, 1) and round(diameter, 1) <= 20.0 then 14.6
	end as wide_bin_diameter,
	case
		when 4.0 <= round(diameter, 1) and round(diameter, 1) <= 5.0 then 4563
		when 5.0 <= round(diameter, 1) and round(diameter, 1) <= 5.9 then 7416
		when 5.9 <= round(diameter, 1) and round(diameter, 1) <= 6.8 then 10174
		when 6.8 <= round(diameter, 1) and round(diameter, 1) <= 7.7 then 13392
		when 7.7 <= round(diameter, 1) and round(diameter, 1) <= 8.6 then 18847
		when 8.6 <= round(diameter, 1) and round(diameter, 1) <= 9.6 then 23429
		when 9.6 <= round(diameter, 1) and round(diameter, 1) <= 10.5 then 28543
		when 10.5 <= round(diameter, 1) and round(diameter, 1) <= 11.9 then 34199
		when 11.9 <= round(diameter, 1) and round(diameter, 1) <= 13.7 then 47174
		when 13.7 <= round(diameter, 1) and round(diameter, 1) <= 20.0 then 62429
	end as max_volume_bushels,
	case
		when 4.0 <= round(diameter, 1) and round(diameter, 1) <= 5.0 then 1841
		when 5.0 <= round(diameter, 1) and round(diameter, 1) <= 5.9 then 2709
		when 5.9 <= round(diameter, 1) and round(diameter, 1) <= 6.8 then 3765
		when 6.8 <= round(diameter, 1) and round(diameter, 1) <= 7.7 then 5020
		when 7.7 <= round(diameter, 1) and round(diameter, 1) <= 8.6 then 6482
		when 8.6 <= round(diameter, 1) and round(diameter, 1) <= 9.6 then 10342
		when 9.6 <= round(diameter, 1) and round(diameter, 1) <= 10.5 then 12706
		when 10.5 <= round(diameter, 1) and round(diameter, 1) <= 11.9 then 15349
		when 11.9 <= round(diameter, 1) and round(diameter, 1) <= 13.7 then 21512
		when 13.7 <= round(diameter, 1) and round(diameter, 1) <= 20.0 then 28907
	end as min_volume_bushels
from silos_ilmenard;


-------------------
-- SILOS FOR MAP --
-------------------


-- establish query to be used to generate materialized view for silos overlay on map
-- select silos with associated parcel owner that are contained within agricultural parcels
-- including wide bin diameter and associated volume attributes for popups
with p as
(select owner, st_union(geom) as geom from parcels_ilmenard where farm_acres > 0 group by owner)
select
	s.gid,
	round(diameter, 1) as diameter,
	case
		when 4.0 <= round(diameter, 1) and round(diameter, 1) <= 5.0 then 4.6
		when 5.0 <= round(diameter, 1) and round(diameter, 1) <= 5.9 then 5.5
		when 5.9 <= round(diameter, 1) and round(diameter, 1) <= 6.8 then 6.4
		when 6.8 <= round(diameter, 1) and round(diameter, 1) <= 7.7 then 7.3
		when 7.7 <= round(diameter, 1) and round(diameter, 1) <= 8.6 then 8.2
		when 8.6 <= round(diameter, 1) and round(diameter, 1) <= 9.6 then 9.1
		when 9.6 <= round(diameter, 1) and round(diameter, 1) <= 10.5 then 10.1
		when 10.5 <= round(diameter, 1) and round(diameter, 1) <= 11.9 then 11.0
		when 11.9 <= round(diameter, 1) and round(diameter, 1) <= 13.7 then 12.8
		when 13.7 <= round(diameter, 1) and round(diameter, 1) <= 20.0 then 14.6
	end as wide_bin_diameter,
	case
		when 4.0 <= round(diameter, 1) and round(diameter, 1) <= 5.0 then 4563
		when 5.0 <= round(diameter, 1) and round(diameter, 1) <= 5.9 then 7416
		when 5.9 <= round(diameter, 1) and round(diameter, 1) <= 6.8 then 10174
		when 6.8 <= round(diameter, 1) and round(diameter, 1) <= 7.7 then 13392
		when 7.7 <= round(diameter, 1) and round(diameter, 1) <= 8.6 then 18847
		when 8.6 <= round(diameter, 1) and round(diameter, 1) <= 9.6 then 23429
		when 9.6 <= round(diameter, 1) and round(diameter, 1) <= 10.5 then 28543
		when 10.5 <= round(diameter, 1) and round(diameter, 1) <= 11.9 then 34199
		when 11.9 <= round(diameter, 1) and round(diameter, 1) <= 13.7 then 47174
		when 13.7 <= round(diameter, 1) and round(diameter, 1) <= 20.0 then 62429
	end as max_volume_bushels,
	case
		when 4.0 <= round(diameter, 1) and round(diameter, 1) <= 5.0 then 1841
		when 5.0 <= round(diameter, 1) and round(diameter, 1) <= 5.9 then 2709
		when 5.9 <= round(diameter, 1) and round(diameter, 1) <= 6.8 then 3765
		when 6.8 <= round(diameter, 1) and round(diameter, 1) <= 7.7 then 5020
		when 7.7 <= round(diameter, 1) and round(diameter, 1) <= 8.6 then 6482
		when 8.6 <= round(diameter, 1) and round(diameter, 1) <= 9.6 then 10342
		when 9.6 <= round(diameter, 1) and round(diameter, 1) <= 10.5 then 12706
		when 10.5 <= round(diameter, 1) and round(diameter, 1) <= 11.9 then 15349
		when 11.9 <= round(diameter, 1) and round(diameter, 1) <= 13.7 then 21512
		when 13.7 <= round(diameter, 1) and round(diameter, 1) <= 20.0 then 28907
	end as min_volume_bushels,
	owner,
	s.geom
from silos_ilmenard s, p
where st_contains(p.geom, st_centroid(s.geom)) = 'True';

-- simplified version, without wide bin diameter or associated volume attributes, if needed:
with p as
(select owner, st_union(geom) as geom from parcels_ilmenard where farm_acres > 0 group by owner)
select s.gid, round(s.diameter, 1) as diameter, p.owner, s.geom
from silos_ilmenard s, p
where st_contains(p.geom, st_centroid(s.geom)) = 'True';


---------------------
-- PARCELS FOR MAP --
---------------------


-- establish query to be used to generate materialized view for parcels on map
-- select agricultural parcels aggregated by owner, including:
-- string of parcel numbers composing the aggregate farm land,
-- count of silos on farm land,
-- maximum and minimum on-farm storage capacity, based on wide corrugation bin dimensions
with s as (
	select
		gid,
		round(diameter, 1) as diameter,
		case
			when 4.0 <= round(diameter, 1) and round(diameter, 1) <= 5.0 then 4.6
			when 5.0 <= round(diameter, 1) and round(diameter, 1) <= 5.9 then 5.5
			when 5.9 <= round(diameter, 1) and round(diameter, 1) <= 6.8 then 6.4
			when 6.8 <= round(diameter, 1) and round(diameter, 1) <= 7.7 then 7.3
			when 7.7 <= round(diameter, 1) and round(diameter, 1) <= 8.6 then 8.2
			when 8.6 <= round(diameter, 1) and round(diameter, 1) <= 9.6 then 9.1
			when 9.6 <= round(diameter, 1) and round(diameter, 1) <= 10.5 then 10.1
			when 10.5 <= round(diameter, 1) and round(diameter, 1) <= 11.9 then 11.0
			when 11.9 <= round(diameter, 1) and round(diameter, 1) <= 13.7 then 12.8
			when 13.7 <= round(diameter, 1) and round(diameter, 1) <= 20.0 then 14.6
		end as wide_bin_diameter,
		case
			when 4.0 <= round(diameter, 1) and round(diameter, 1) <= 5.0 then 4563
			when 5.0 <= round(diameter, 1) and round(diameter, 1) <= 5.9 then 7416
			when 5.9 <= round(diameter, 1) and round(diameter, 1) <= 6.8 then 10174
			when 6.8 <= round(diameter, 1) and round(diameter, 1) <= 7.7 then 13392
			when 7.7 <= round(diameter, 1) and round(diameter, 1) <= 8.6 then 18847
			when 8.6 <= round(diameter, 1) and round(diameter, 1) <= 9.6 then 23429
			when 9.6 <= round(diameter, 1) and round(diameter, 1) <= 10.5 then 28543
			when 10.5 <= round(diameter, 1) and round(diameter, 1) <= 11.9 then 34199
			when 11.9 <= round(diameter, 1) and round(diameter, 1) <= 13.7 then 47174
			when 13.7 <= round(diameter, 1) and round(diameter, 1) <= 20.0 then 62429
		end as max_volume_bushels,
		case
			when 4.0 <= round(diameter, 1) and round(diameter, 1) <= 5.0 then 1841
			when 5.0 <= round(diameter, 1) and round(diameter, 1) <= 5.9 then 2709
			when 5.9 <= round(diameter, 1) and round(diameter, 1) <= 6.8 then 3765
			when 6.8 <= round(diameter, 1) and round(diameter, 1) <= 7.7 then 5020
			when 7.7 <= round(diameter, 1) and round(diameter, 1) <= 8.6 then 6482
			when 8.6 <= round(diameter, 1) and round(diameter, 1) <= 9.6 then 10342
			when 9.6 <= round(diameter, 1) and round(diameter, 1) <= 10.5 then 12706
			when 10.5 <= round(diameter, 1) and round(diameter, 1) <= 11.9 then 15349
			when 11.9 <= round(diameter, 1) and round(diameter, 1) <= 13.7 then 21512
			when 13.7 <= round(diameter, 1) and round(diameter, 1) <= 20.0 then 28907
		end as min_volume_bushels,
		geom
	from silos_ilmenard
), p as (
		select
			owner,
			string_agg(parcelnumb, ', ') as parcel_numbers,
			st_union(geom) as geom
		from parcels_ilmenard
		where farm_acres > 0
		group by owner
)
select
	owner,
	parcel_numbers,
	count(*) as silo_count,
	sum(max_volume_bushels) as max_volume_bushels,
	sum(min_volume_bushels) as min_volume_bushels,
	p.geom
from s, p
where st_contains(p.geom, st_centroid(s.geom)) = 'True'
group by owner, parcel_numbers, p.geom;
