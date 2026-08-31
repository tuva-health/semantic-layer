{% macro load_semantic_layer_seed(object_name) %}
  {{ return(the_tuva_project.load_package_seed(
      'data-marts/semantic-layer',
      var('semantic_layer_data_asset_version'),
      object_name,
      true,
      true,
      true
  )) }}
{% endmacro %}
