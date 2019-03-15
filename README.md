# ilmenard

```bash
.
+-- assets
|   +-- css
|   |   +-- style.css
|   +-- data
|   |   +-- loaded
|   |   +-- scripts
|   |   |   +-- createdb.sh
|   |   |   +-- data_prod.sql
|   |   |   +-- data_scratch.sql
|   |   |   +-- load_and_move.sh
|   |   |   +-- postgres_carto_overwrite.sh
|   |   |   +-- postgres_carto_sync.sh
|   |   |   +-- truncate_carto.sh
|   |   |   +-- unzip_and_review.sh
|   |   +-- parcels.ilmenard.zip
|   |   +-- silos.ilmenard.zip
|   +-- img
|   |   +-- favicon-sat.ico
|   +-- js
|   |   +-- app.js
|   +-- lib
|   |   +-- leaflet
|   |   |   +-- ...
|   |   +-- leaflet-hash-master
|   |   |   +-- ...
|   |   +-- leaflet.zoomhome-master
|   |   |   +-- ...
|   |   +-- jquery-3.3.1.js
+-- index.html
+-- README.md
```

## Data

1. Download `parcels_ilmenard.zip` and `silos_ilmenard.zip` to `./assets/data/`
2. In terminal, navigate to `./assets/data/scripts/`
3. Create Postgres database `ilmenard` with PostGIS extension and open in psql terminal via:
  - `$ sh create.db sh` (no parameters required)
4. Open new terminal tab/window in `./assets/data/scripts`
5. Unzip and review (ogrinfo) the data via:
  - `$ sh unzip_and_review.sh` (no parameters required)
  - Review and compare SRS, extent, geometry type, feature count, etc.
6. Load each `.shp` file to tables of the same name in the `ilmenard` database and thereafter move all loaded files (`.zip`, `.shp`, and all associated files) to `./assets/data/loaded/` directory via:
  - `$ sh load_and_move.sh` (no parameters required)
7. Return to psql terminal to review loaded data and construct queries for use in map
  - `data_scratch.sql` walks through review process, including:
    - assessing parcel unique id's
    - determining logic with which to identify agricultural parcels
    - determining logic with which to establish parcel ownership
    - confirming silo diameters of 4-20 meters
    - establishing silo total storage volume logic
    - establishing query logic for silo and parcel layers for display on map
  - `data_prod.sql` walks through indexing and query construction for use in map, including:
    - indexing `parcels_ilmenard`
    - aggregate materialized view `silos` for use in map
    - aggregate materialized view `parcels` for use in map
8. Return to terminal in `./assets/data/scripts` directory to sync `silos` and `parcels` materialized views to CARTO via:
  - `$ sh postgres_carto_sync.sh silos silos`
  - `$ sh postgres_carto_sync.sh parcels parcels`
      - parameters, in order: Postgres relation to sync to CARTO, CARTO table to sync with
      - note: ogr2ogr automatically runs in `-append` mode; use `postgres_carto_overwrite.sh` to run in `-overwrite` mode or use `truncate_carto.sh` to truncate before synching
      - note: CARTO API Key removed from uploaded scripts here for privacy
9. Refresh materialized views to incorporate new silos added to `silos_ilmenard` and/or updated parcel attributes in `parcels_ilmenard` via:
  - `REFRESH MATERIALIZED VIEW silos`
  - `REFRESH MATERIALIZED VIEW parcels`

## Map

Built with Leaflet, using five classifications (Jenks natural breaks) for estimated maximum on-farm storage capacity. Silos are filtered to those overlapping parcels with agricultural land use with a diameter of 4-20 meters. Maximum and minimum volume estimated (in bushels) using closest [wide corrugation bin](https://www.brockmfg.com/uploads/pdf/BR_2286_201702_Brock_Non_Stiffened_Storage_Capacities_Fact_Sheet_EM.pdf) diameter and associated maximum and minimum bin heights. Parcels are filtered to agricultural land use and aggregated by primary owner, summing the number of overlapping silos (i.e., grain bins) and estimated max. / min. volumes of those silos.
