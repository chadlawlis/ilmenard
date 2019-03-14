var L; // define Leaflet variable L
var $; // define jQuery variable $
var cartoUser = 'chadlawlis'; // define CARTO user name
var sqlSilos = 'select owner, max_volume_bushels, min_volume_bushels, diameter, wide_bin_diameter, the_geom from silos'; // define CARTO SQL API query for silos
var sqlParcels = 'select owner, max_volume_bushels, min_volume_bushels, silo_count, the_geom from parcels'; // define CARTO SQL API query for parcels

// Instantiate Leaflet map
function createMap () {
  // Mapbox tile layer
  // Removing attribution here and adding in custom control below
  var satellite = L.tileLayer('https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}', {
    // attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="https://www.mapbox.com/">Mapbox</a>',
    maxZoom: 18,
    id: 'mapbox.satellite',
    accessToken: 'pk.eyJ1IjoiY2hhZGxhd2xpcyIsImEiOiJlaERjUmxzIn0.P6X84vnEfttg0TZ7RihW1g'
  });

  // CARTO tile layer
  // Removing attribution here and adding in custom control below
  var positron = L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
    // attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
    subdomains: 'abcd',
    maxZoom: 18
  });

  // Create the map
  var map = L.map('map', {
    attributionControl: false, // add custom attribution control below
    center: [40.03, -89.80], // lat, lon (hash URL displays /#zoom/lat/lon)
    layers: positron,
    minZoom: 11,
    zoom: 11,
    zoomControl: false // replaced with leaflet.zoomhome plugin zoom control below
  });

  // Add hash via leaflet-hash plugin
  // https://github.com/mlevans/leaflet-hash
  var hash = new L.Hash(map);

  var attribution = L.control.attribution({
    position: 'bottomright',
    prefix: false
  });

  // Add attribution control with custom attribution
  attribution.addAttribution('<a href="https://chadlawlis.com">Chad Lawlis</a> | <a href="https://leaflet.com">Leaflet</a> | Parcel data &copy; <a href="https://menardcountyil.com/departments/zoning-gis/">Menard County, IL</a>, Silo data &copy; <a href="https://www.indigoag.com/">Indigo</a>, Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>, Base &copy; <a href="https://carto.com/attributions">CARTO</a>, Imagery &copy; <a href="https://mapbox.com/">Mapbox</a>');
  attribution.addTo(map);

  // Add home button with zoom controls via zoomhome plugin
  // https://github.com/torfsen/leaflet.zoomhome
  var zoomHome = L.Control.zoomHome();
  zoomHome.addTo(map);

  // Create empty layerGroup object assigned to silos, to enable use in layers control below
  var silos = new L.LayerGroup();
  getSilos(silos);

  // Tilesets for layer control
  var tilesets = {
    'Base': positron,
    'Satellite': satellite
  };

  // Overlay for layer control
  var overlay = {
    // 'Points': uhfPoints,
    'Grain bins': silos
  };

  // Create layer control and add to map
  L.control.layers(tilesets, overlay, {position: 'topleft'}).addTo(map);

  // Get parcels data via getData() function
  getData(map);

  // Get silos data via CARTO SQL API
  // Assign style
  // and add to silos layerGroup created above
  function getSilos (silos) {
    $.ajax('https://' + cartoUser + '.carto.com/api/v2/sql?format=GeoJSON&q=' + sqlSilos, {
      dataType: 'json',
      success: function (response) {
        var polygonStyle = {
          color: '#ffcc00',
          fillColor: '#ffcc00',
          fillOpacity: 0.8,
          opacity: 0.8,
          weight: 1
        };
        L.geoJSON(response, {
          onEachFeature: siloPopup,
          style: polygonStyle
        }).addTo(silos);
      }
    });
  }

  // Bind popup to silo features when clicked
  function siloPopup (feature, layer) {
    var props = feature.properties;
    var popupContent = '';
    if (props) {
      popupContent += '<p>' + props.owner + '</p><p><b>Est. max. volume: <span style="color: #ef5641;">' + Number(props.max_volume_bushels).toLocaleString('en') + '</span></b> bushels</p><p><b>Est. min. volume:</b> ' + Number(props.min_volume_bushels).toLocaleString('en') + ' bushels</p><p><b>Est. wide bin diameter:</b> ' + props.wide_bin_diameter + '<p><b>Diameter:</b> ' + props.diameter + '</p>';
      layer.bindPopup(popupContent);
    }
  }

  // Create control to display parcel info on hover
  var info = L.control();

  // Create <div class="info"> for info control
  info.onAdd = function (map) {
    this._div = L.DomUtil.create('div', 'info');
    // Add content
    this.update();
    return this._div;
  };

  // props = feature.properties
  info.update = function (props) {
    this._div.innerHTML = '<h4>Est. Max. On-Farm Storage Capacity</h4>' + (props ? props.owner + '<br><span style="color: #ef5641; font-weight: bold;">' + Number(props.max_volume_bushels).toLocaleString('en') + '</span> bushels*<br>' + Number(props.min_volume_bushels).toLocaleString('en') + ' bushels (min.)*<br>' + 'Grain bins: <span style="color: #ffcc00; font-weight: bold;">' + props.silo_count + '</span><br><i><small>*assumes wide corrugation bins at max. / min. height for diameter</small></i>' : 'Menard County, IL<br><span style="color: #ef5641; font-weight: bold;">Hover</span> over a parcel<br>Overlay <span style="color: #ffcc00; font-weight: bold;">grain bins</span> from layer control');
  };

  info.addTo(map);

  // Assign parcel color based on Natural Breaks (Jenks) break points using five class sequential color schema
  // via http://colorbrewer2.org/#type=sequential&scheme=Blues&n=5
  function getColor (d) {
    return d > 268210 ? '#08519c' : d > 170860 ? '#3182bd' : d > 91285 ? '#6baed6' : d > 51193 ? '#bdd7e7' : '#eff3ff';
  }

  // Assign style properties for parcels
  function style (feature) {
    return {
      color: '#333d47',
      fillColor: getColor(feature.properties.max_volume_bushels),
      fillOpacity: 0.7,
      opacity: 0.4,
      weight: 1
    };
  }

  // Assign parcel style and info control content on mouseover
  function highlightFeature (e) {
    var layer = e.target;
    info.update(layer.feature.properties);

    layer.setStyle({
      color: '#ef5641',
      fillOpacity: 0.7,
      opacity: 0.8,
      weight: 3
    });

    // // COMMENT OUT! Use if not including silos, otherwise parcels will cover silos when silos enabled
    // if (!L.Browser.ie && !L.Browser.opera && !L.Browser.edge) {
    //   layer.bringToFront();
    // }
  }

  var geojson;

  // Reset parcel style and info control content on mouseout
  function resetHighlight (e) {
    geojson.resetStyle(e.target);
    info.update();
  }

  // Zoom to parcel on click
  function zoomToFeature (e) {
    map.fitBounds(e.target.getBounds());
  }

  // Assign interactivity on each parcel feature
  function onEachFeature (feature, layer) {
    layer.on({
      mouseover: highlightFeature,
      mouseout: resetHighlight,
      click: zoomToFeature
    });
  }

  // Get parcels data via CARTO SQL API
  // Assign interactivity and stylesheet
  // and add to map
  function getData (map) {
    $.ajax('https://' + cartoUser + '.carto.com/api/v2/sql?format=GeoJSON&q=' + sqlParcels, {
      dataType: 'json',
      success: function (response) {
        geojson = L.geoJSON(response, {
          onEachFeature: onEachFeature,
          style: style
        }).addTo(map);
      }
    });
  }

  // Create legend control
  var legend = L.control({position: 'bottomright'});

  // Populate legend
  legend.onAdd = function (map) {
    // Create <div class="info legend"> for legend control
    var div = L.DomUtil.create('div', 'info legend');
    // Instantiate array with volume break points
    var grades = [9126, 51193, 91285, 170860, 268210];

    // Loop through volume intervals and generate label with a colored square for each
    for (var i = 0; i < grades.length; i++) {
      div.innerHTML += '<i style="background:' + getColor(grades[i] + 1) + '"></i> ' + Number(grades[i]).toLocaleString('en') + (grades[i + 1] ? ' &ndash; ' + Number(grades[i + 1]).toLocaleString('en') + '<br>' : ' +');
    }
    return div;
  };

  legend.addTo(map);
}

$(document).ready(createMap);
