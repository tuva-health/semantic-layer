{% macro load_semantic_layer_seed(object_name) %}
  {{ return(the_tuva_project.load_package_seed(
      'semantic-layer',
      semantic_layer.get_semantic_layer_package_version(),
      object_name,
      true,
      true,
      true
  )) }}
{% endmacro %}
